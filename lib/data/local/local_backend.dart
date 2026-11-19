import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/validators.dart';
import '../models/account.dart';
import '../models/municipality.dart';
import '../models/report.dart';
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
  final _reportChanges = StreamController<void>.broadcast();
  Future<void> _pendingWrite = Future.value();

  static Future<LocalBackend> open({
    SharedPreferences? preferences,
    String? photoDirectory,
    Duration latency = const Duration(milliseconds: 300),
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored != null) {
      return LocalBackend._(prefs, _decode(stored), latency, photoDirectory);
    }
    final now = DateTime.now();
    final data = <String, dynamic>{
      'session': null,
      'municipalities': {
        for (final municipality in demoMunicipalities)
          municipality.id: municipality.toJson(),
      },
      'accounts': {
        for (final account in demoAccounts(now))
          account.id: {...account.toJson(), ..._credential(demoPassword)},
      },
      'reports': {
        for (final report in demoReports(now)) report.id: report.toJson(),
      },
    };
    final backend = LocalBackend._(prefs, data, latency, photoDirectory);
    await backend._save(data);
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
    final id = _data['session'] as String?;
    return id == null ? null : _account(_data, id);
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
    data['session'] = id;
    await _save(data);
    return _account(data, id);
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
    _checkCitizen(data, id);
    final error = requiredText(name, 'Saisissez votre nom complet.');
    if (error != null) throw RepositoryException(error);
    (_table(data, 'accounts')[id] as Map)['name'] = name.trim();
    await _save(data);
    return _account(data, id);
  });

  void _checkCitizen(Map<String, dynamic> data, String citizenId) {
    if (data['session'] != citizenId ||
        _account(data, citizenId).role != AccountRole.citizen) {
      throw const RepositoryException(
        'Connectez-vous pour accéder à cet espace.',
      );
    }
  }

  @override
  Future<List<Municipality>> listMunicipalities() async {
    final stored = _data['municipalities'] as Map<String, dynamic>?;
    if (stored == null) return demoMunicipalities;
    return List.unmodifiable(
      stored.entries.map(
        (entry) => Municipality.fromJson(
          entry.key,
          entry.value as Map<String, dynamic>,
        ),
      ),
    );
  }

  List<Report> _list(String citizenId) {
    _checkCitizen(_data, citizenId);
    final reports =
        _table(_data, 'reports').entries
            .where((entry) => (entry.value as Map)['citizenId'] == citizenId)
            .map(
              (entry) => Report.fromJson(
                entry.key,
                entry.value as Map<String, dynamic>,
              ),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(reports);
  }

  @override
  Future<List<Report>> listReports(String citizenId) async {
    await Future<void>.delayed(_latency);
    return _list(citizenId);
  }

  @override
  Stream<List<Report>> watchReports(String citizenId) =>
      Stream.multi((controller) {
        void emit() {
          try {
            controller.addSync(_list(citizenId));
          } catch (error, stack) {
            controller.addErrorSync(error, stack);
          }
        }

        final subscription = _reportChanges.stream.listen(
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
    _checkCitizen(data, citizenId);
    final reports = _table(data, 'reports');
    final existing = reports[draft.id] as Map<String, dynamic>?;
    if (existing != null) {
      if (existing['citizenId'] != citizenId) {
        throw const RepositoryException(
          'Impossible d’enregistrer ce signalement.',
        );
      }
      return Report.fromJson(draft.id, existing);
    }

    String? photo;
    try {
      final bytes = await draft.photo.readAsBytes();
      if (bytes.isEmpty) throw const FormatException('Photo vide');
      photo = await savePhoto(draft.id, bytes, baseDirectory: _photoDirectory);
      final report = Report.submitted(draft, citizenId, photo);
      reports[report.id] = report.toJson();
      await _save(data);
      _reportChanges.add(null);
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

  Future<void> close() => _reportChanges.close();
}
