import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/municipality_locator.dart';
import '../../core/validators.dart';
import '../models/account.dart';
import '../models/municipality.dart';
import '../models/report.dart';
import '../municipal_validation.dart';
import '../permission_policy.dart';
import '../repositories/auth_repository.dart';
import '../repositories/municipality_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/user_repository.dart';
import 'photo_storage.dart';
import 'seed.dart';

class LocalBackend
    implements
        AuthRepository,
        UserRepository,
        ReportRepository,
        MunicipalityRepository {
  LocalBackend._(
    this._preferences,
    this._data,
    this._latency,
    this._photoDirectory,
  );

  static const _key = 'reportini.local.v1';
  final SharedPreferences _preferences;
  final Duration _latency;
  final String? _photoDirectory;
  Map<String, dynamic> _data;
  final _changes = StreamController<void>.broadcast();
  static const _policy = PermissionPolicy();
  Future<void> _pendingWrite = Future.value();

  static Future<LocalBackend> open({
    SharedPreferences? preferences,
    String? photoDirectory,
    Duration latency = const Duration(milliseconds: 300),
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    final now = DateTime.now();
    final data = stored != null
        ? _decode(stored)
        : <String, dynamic>{
            'session': null,
            'municipalities': {
              for (final municipality in demoMunicipalities)
                municipality.id: municipality.toJson(),
            },
            'accounts': {
              for (final account in demoAccounts(now))
                account.id: {...account.toJson(), ..._credential(demoPassword)},
            },
            'reports': <String, dynamic>{},
          };
    final backend = LocalBackend._(prefs, data, latency, photoDirectory);
    // Unversioned snapshots already contain the original demo reports.
    final version = data['seedVersion'] as int? ?? (stored == null ? 0 : 1);
    if (version < seedVersion) {
      final reports = backend._table(data, 'reports');
      for (final report in demoReports(
        now,
        afterVersion: version,
        municipalities: backend._municipalities(data),
      )) {
        reports.putIfAbsent(report.id, report.toJson);
      }
      data['seedVersion'] = seedVersion;
      await backend._save(data);
    }
    return backend;
  }

  static Map<String, dynamic> _decode(String value) =>
      jsonDecode(value) as Map<String, dynamic>;

  static String _hash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  static Map<String, String> _credential(String password) {
    final random = Random.secure();
    final salt = base64Encode(List.generate(24, (_) => random.nextInt(256)));
    return {'salt': salt, 'passwordHash': _hash(salt, password)};
  }

  Future<void> _save(Map<String, dynamic> data) async {
    if (!await _preferences.setString(_key, jsonEncode(data))) {
      throw const RepositoryException(
        'Impossible d’enregistrer les données sur cet appareil.',
      );
    }
    _data = data;
    _changes.add(null);
  }

  Future<T> _write<T>(Future<T> Function(Map<String, dynamic>) action) {
    final write = _pendingWrite.then((_) async {
      await Future<void>.delayed(_latency);
      return action(_decode(jsonEncode(_data)));
    });
    _pendingWrite = write.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return write;
  }

  Map<String, dynamic> _table(Map<String, dynamic> data, String key) =>
      data[key] as Map<String, dynamic>;

  Account _account(Map<String, dynamic> data, String id) => Account.fromJson(
    id,
    _table(data, 'accounts')[id] as Map<String, dynamic>,
  );

  String? _accountIdByEmail(Map<String, dynamic> data, String email) {
    for (final entry in _table(data, 'accounts').entries) {
      if ((entry.value as Map)['email'] == email.trim().toLowerCase()) {
        return entry.key;
      }
    }
    return null;
  }

  @override
  Future<Account?> restoreSession() async {
    final actor = _actor(_data);
    return actor?.enabled == true ? actor : null;
  }

  @override
  Future<Account> signIn(String email, String password) => _write((data) async {
    final id = _accountIdByEmail(data, email);
    final user = _table(data, 'accounts')[id] as Map?;
    if (id == null ||
        user == null ||
        _hash(user['salt'] as String, password) != user['passwordHash']) {
      throw const RepositoryException(
        'Adresse e-mail ou mot de passe incorrect.',
      );
    }
    final account = _account(data, id);
    if (!account.enabled) {
      throw const RepositoryException('Ce compte est désactivé.');
    }
    data['session'] = id;
    await _save(data);
    return account;
  });

  @override
  Future<void> register(String name, String email, String password) =>
      _write((data) async {
        if (_accountIdByEmail(data, email) != null) {
          throw const RepositoryException(
            'Un compte utilise déjà cette adresse e-mail.',
          );
        }
        final error =
            requiredText(name, 'Saisissez votre nom complet.') ??
            validateEmail(email) ??
            validatePassword(password);
        if (error != null) throw RepositoryException(error);
        final account = Account(
          id: const Uuid().v4(),
          name: name.trim(),
          email: email.trim().toLowerCase(),
          role: AccountRole.citizen,
          createdAt: DateTime.now(),
        );
        _table(data, 'accounts')[account.id] = {
          ...account.toJson(),
          ..._credential(password),
        };
        await _save(data);
      });

  @override
  Future<void> signOut() => _write((data) async {
    data['session'] = null;
    await _save(data);
  });

  @override
  Future<Account> updateName(String id, String name) => _write((data) async {
    _policy.require(_policy.canEditName(_actor(data), id));
    final error = requiredText(name, 'Saisissez votre nom complet.');
    if (error != null) throw RepositoryException(error);
    (_table(data, 'accounts')[id] as Map)['name'] = name.trim();
    await _save(data);
    return _account(data, id);
  });

  Account? _actor(Map<String, dynamic> data) {
    final id = data['session'] as String?;
    return id == null ? null : _account(data, id);
  }

  @override
  Stream<Account?> watchOwnAccount(String id) =>
      _observe(() => _actor(_data)?.id == id ? _account(_data, id) : null);

  void _requireAdmin(Map<String, dynamic> data) =>
      _policy.require(_policy.canManage(_actor(data)));

  @override
  Stream<List<Account>> watchAgents() {
    final adminId = _actor(_data)?.id;
    return _observe(() {
      _policy.require(_actor(_data)?.id == adminId);
      _requireAdmin(_data);
      return [
        for (final id in _table(_data, 'accounts').keys)
          if (_account(_data, id) case final agent
              when agent.role == AccountRole.agent)
            agent,
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
  }

  @override
  Future<Account> createAgent(
    String name,
    String email,
    String password,
    String municipalityId,
  ) => _write((data) async {
    _requireAdmin(data);
    validateAgentCredentials(name, email, password);
    _municipality(data, municipalityId);
    if (_accountIdByEmail(data, email) != null) {
      throw const RepositoryException(
        'Un compte utilise déjà cette adresse e-mail.',
      );
    }
    final agent = Account(
      id: const Uuid().v4(),
      name: name.trim(),
      email: email.trim().toLowerCase(),
      role: AccountRole.agent,
      createdAt: DateTime.now(),
      municipalityId: municipalityId,
    );
    _table(data, 'accounts')[agent.id] = {
      ...agent.toJson(),
      ..._credential(password),
    };
    await _save(data);
    return agent;
  });

  Map<String, dynamic> _agentData(Map<String, dynamic> data, String id) {
    final agent = _table(data, 'accounts')[id] as Map<String, dynamic>?;
    if (agent == null || agent['role'] != AccountRole.agent.name) {
      throw const RepositoryException('Compte agent introuvable.');
    }
    return agent;
  }

  @override
  Future<void> updateAgent(String id, {required String municipalityId}) =>
      _write((data) async {
        _requireAdmin(data);
        _municipality(data, municipalityId);
        _agentData(data, id)['municipalityId'] = municipalityId;
        await _save(data);
      });

  @override
  Future<void> setAgentEnabled(String id, bool enabled) => _write((data) async {
    _requireAdmin(data);
    _agentData(data, id)['enabled'] = enabled;
    await _save(data);
  });

  void _checkCitizen(Map<String, dynamic> data, String citizenId) {
    _policy.require(_policy.isCitizen(_actor(data), citizenId));
  }

  @override
  Future<List<Municipality>> listMunicipalities() async =>
      _visibleMunicipalities();

  @override
  Stream<List<Municipality>> watchMunicipalities() {
    final actorId = _actor(_data)?.id;
    return _observe(() {
      _policy.require(_actor(_data)?.id == actorId);
      return _visibleMunicipalities();
    });
  }

  List<Municipality> _visibleMunicipalities() {
    _policy.require(_actor(_data)?.enabled == true);
    return _municipalities(_data);
  }

  List<Municipality> _municipalities(Map<String, dynamic> data) => [
    for (final entry in _table(data, 'municipalities').entries)
      Municipality.fromJson(entry.key, entry.value as Map<String, dynamic>),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Municipality _municipality(Map<String, dynamic> data, String id) {
    final item = _table(data, 'municipalities')[id] as Map<String, dynamic>?;
    if (item == null) {
      throw const RepositoryException('Municipalité introuvable.');
    }
    return Municipality.fromJson(id, item);
  }

  @override
  Future<Municipality> saveMunicipality(Municipality input) =>
      _write((data) async {
        _requireAdmin(data);
        validateMunicipality(input, _municipalities(data));
        if (input.id.isNotEmpty) _municipality(data, input.id);
        final item = Municipality(
          input.id.isEmpty ? const Uuid().v4() : input.id,
          input.name.trim(),
          input.centerLat,
          input.centerLng,
          input.radiusKm,
        );
        _table(data, 'municipalities')[item.id] = item.toJson();
        await _save(data);
        return item;
      });

  @override
  Future<void> deleteMunicipality(String id) => _write((data) async {
    _requireAdmin(data);
    final hasLinks = ['accounts', 'reports'].any(
      (table) => _table(
        data,
        table,
      ).values.any((row) => (row as Map)['municipalityId'] == id),
    );
    if (hasLinks) {
      throw const RepositoryException(
        'Cette municipalité est liée à des agents ou à des signalements.',
      );
    }
    _table(data, 'municipalities').remove(id);
    await _save(data);
  });

  List<Report> _list(String citizenId) {
    _checkCitizen(_data, citizenId);
    return _visibleReports(_actor(_data)!);
  }

  @override
  Future<List<Report>> listReports(String citizenId) async {
    await Future<void>.delayed(_latency);
    return _list(citizenId);
  }

  @override
  Stream<List<Report>> watchReports(String citizenId) =>
      _observe(() => _list(citizenId));

  @override
  Stream<List<Report>> watchMunicipalReports() {
    final actorId = _actor(_data)?.id;
    return _observe(() {
      final actor = _actor(_data);
      _policy.require(
        actor?.id == actorId && _policy.canViewMunicipalReports(actor),
      );
      return _visibleReports(actor!);
    });
  }

  List<Report> _visibleReports(Account actor) {
    final reports = [
      for (final entry in _table(_data, 'reports').entries)
        if (_decodeReport(_data, entry.key, entry.value as Map<String, dynamic>)
            case final report when _policy.canReadReport(actor, report))
          report,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(reports);
  }

  Report _decodeReport(
    Map<String, dynamic> data,
    String id,
    Map<String, dynamic> row,
  ) {
    final citizen = _table(data, 'accounts')[row['citizenId']] as Map?;
    final municipality =
        _table(data, 'municipalities')[row['municipalityId']] as Map?;
    return Report.fromJson(id, {
      ...row,
      'citizenName': row['citizenName'] ?? citizen?['name'],
      'municipalityName': municipality?['name'] ?? row['municipalityName'],
    });
  }

  Map<String, dynamic> _reportData(Map<String, dynamic> data, String id) {
    final row = _table(data, 'reports')[id] as Map<String, dynamic>?;
    if (row == null) {
      throw const RepositoryException('Signalement introuvable.');
    }
    return row;
  }

  @override
  Future<void> changeStatus(String id, ReportStatus status, String note) =>
      _write((data) async {
        final actor = _actor(data);
        _policy.require(_policy.canViewMunicipalReports(actor));
        final row = _reportData(data, id);
        final report = _decodeReport(data, id, row);
        _policy.require(_policy.canChangeStatus(actor, report));
        final event = statusEvent(report, status, actor!.name, note);
        row['status'] = status.code;
        row['history'] = [...(row['history'] as List), event.toJson()];
        row['updatedAt'] = event.at.toUtc().toIso8601String();
        await _save(data);
      });

  @override
  Future<void> assignReport(String id, String municipalityId) =>
      _write((data) async {
        _requireAdmin(data);
        final municipality = _municipality(data, municipalityId);
        final row = _reportData(data, id);
        if (row['municipalityId'] != null) {
          throw const RepositoryException('Ce signalement est déjà affecté.');
        }
        row['municipalityId'] = municipality.id;
        row['municipalityName'] = municipality.name;
        row['updatedAt'] = DateTime.now().toUtc().toIso8601String();
        await _save(data);
      });

  Stream<T> _observe<T>(T Function() read) => Stream.multi((controller) {
    void emit() {
      try {
        controller.addSync(read());
      } catch (error, stack) {
        controller.addErrorSync(error, stack);
      }
    }

    final subscription = _changes.stream.listen(
      (_) => emit(),
      onDone: controller.closeSync,
    );
    controller.onCancel = subscription.cancel;
    emit();
  });

  @override
  Future<Report> createReport(String citizenId, ReportDraft draft) => _write((
    data,
  ) async {
    final actor = _actor(data);
    _policy.require(
      _policy.canCreateReport(actor, citizenId, ReportStatus.enAttente),
    );
    final reports = _table(data, 'reports');
    final existing = reports[draft.id] as Map<String, dynamic>?;
    if (existing != null) {
      if (existing['citizenId'] != citizenId) {
        throw const RepositoryException(
          'Impossible d’enregistrer ce signalement.',
        );
      }
      return _decodeReport(data, draft.id, existing);
    }

    String? photo;
    try {
      final bytes = await draft.photo.readAsBytes();
      if (bytes.isEmpty) throw const FormatException('Photo vide');
      photo = await savePhoto(draft.id, bytes, baseDirectory: _photoDirectory);
      final municipality = const MunicipalityLocator().locate(
        draft.location.lat,
        draft.location.lng,
        _municipalities(data),
      );
      final report = Report.submitted(
        draft.withMunicipality(municipality),
        citizenId,
        photo,
        citizenName: actor!.name,
      );
      reports[report.id] = report.toJson();
      await _save(data);
      return report;
    } catch (_) {
      if (photo != null) {
        try {
          await deletePhoto(photo);
        } catch (_) {
          // A later attempt can overwrite an orphan with the same draft id.
        }
      }
      throw const RepositoryException(
        'Impossible d’enregistrer la photo ou le signalement.',
      );
    }
  });

  Future<void> close() => _changes.close();
}
