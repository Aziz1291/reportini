import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' as core;
import 'package:firebase_storage/firebase_storage.dart';
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

class FirebaseBackend
    implements
        AuthRepository,
        ReportRepository,
        MunicipalityRepository,
        UserRepository {
  FirebaseBackend(this._auth, this._db, this._storage);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  static const _policy = PermissionPolicy();
  static const _server = GetOptions(source: Source.server);

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('reports');
  CollectionReference<Map<String, dynamic>> get _municipalities =>
      _db.collection('municipalities');

  Map<String, dynamic> _readDates(
    Map<String, dynamic> data,
    List<String> fields,
  ) => {
    ...data,
    for (final field in fields)
      if (data[field] is Timestamp)
        field: (data[field] as Timestamp).toDate().toUtc().toIso8601String(),
  };

  Future<Account> _profile(String id) async {
    final data = (await _users.doc(id).get(_server)).data();
    if (data == null) {
      throw const RepositoryException(
        'Le profil de ce compte est indisponible.',
      );
    }
    return Account.fromJson(id, _readDates(data, ['createdAt']));
  }

  RepositoryException _authError(FirebaseAuthException error) =>
      RepositoryException(switch (error.code) {
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' => 'Adresse e-mail ou mot de passe incorrect.',
        'invalid-email' => 'Saisissez une adresse e-mail valide.',
        'email-already-in-use' =>
          'Un compte utilise déjà cette adresse e-mail.',
        'weak-password' =>
          'Ce mot de passe ne respecte pas les règles de sécurité.',
        'too-many-requests' =>
          'Trop de tentatives. Réessayez dans quelques minutes.',
        'network-request-failed' =>
          'Connexion indisponible. Vérifiez votre accès à Internet.',
        'user-disabled' => 'Ce compte est désactivé.',
        _ => 'Authentification indisponible. Réessayez.',
      });

  @override
  Future<Account?> restoreSession() async {
    final user = await _auth.authStateChanges().first;
    if (user == null) return null;
    try {
      final account = await _profile(user.uid);
      if (account.enabled) return account;
      await _auth.signOut();
      return null;
    } on RepositoryException {
      await _auth.signOut();
      return null;
    }
  }

  @override
  Future<Account> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      try {
        final account = await _profile(result.user!.uid);
        if (!account.enabled) {
          throw const RepositoryException('Ce compte est désactivé.');
        }
        return account;
      } catch (_) {
        await _auth.signOut();
        rethrow;
      }
    } on FirebaseAuthException catch (error) {
      throw _authError(error);
    }
  }

  @override
  Future<void> register(String name, String email, String password) async {
    final error =
        requiredText(name, 'Saisissez votre nom complet.') ??
        validateEmail(email) ??
        validatePassword(password);
    if (error != null) throw RepositoryException(error);

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = credential.user!;
      final account = Account(
        id: user.uid,
        name: name.trim(),
        email: user.email!,
        role: AccountRole.citizen,
        createdAt: DateTime.now(),
      );
      try {
        await _users.doc(user.uid).set(account.toJson());
      } catch (_) {
        try {
          await user.delete();
        } finally {
          await _auth.signOut();
        }
        rethrow;
      }
      await _auth.signOut();
    } on FirebaseAuthException catch (error) {
      throw _authError(error);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  void _checkUser(String id) {
    if (_auth.currentUser?.uid != id) {
      throw const RepositoryException(
        'Connectez-vous pour accéder à cet espace.',
      );
    }
  }

  @override
  Future<Account> updateName(String id, String name) async {
    _policy.require(_policy.canEditName(await _currentAccount(), id));
    final error = requiredText(name, 'Saisissez votre nom complet.');
    if (error != null) throw RepositoryException(error);
    await _users.doc(id).update({'name': name.trim()});
    return _profile(id);
  }

  @override
  Future<List<Municipality>> listMunicipalities() async =>
      _activeMunicipalities(await _municipalities.get(_server));

  List<Municipality> _activeMunicipalities(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) => [
    for (final doc in snapshot.docs)
      if (doc.data()['archived'] != true)
        Municipality.fromJson(doc.id, doc.data()),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  Stream<List<Municipality>> watchMunicipalities() =>
      _municipalities.snapshots().map(_activeMunicipalities);

  Future<Account> _currentAccount() {
    final id = _auth.currentUser?.uid;
    if (id == null) {
      throw const RepositoryException(
        'Connectez-vous pour accéder à cet espace.',
      );
    }
    return _profile(id);
  }

  Future<void> _requireAdmin() async =>
      _policy.require(_policy.canManage(await _currentAccount()));

  DocumentReference<Map<String, dynamic>> _nameReservation(String name) {
    final hash = sha256.convert(utf8.encode(municipalityNameKey(name)));
    return _db.collection('municipalityNames').doc(hash.toString());
  }

  Municipality _activeMunicipality(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null || data['archived'] == true) {
      throw const RepositoryException('Municipalité introuvable.');
    }
    return Municipality.fromJson(document.id, data);
  }

  @override
  Future<Municipality> saveMunicipality(Municipality input) async {
    await _requireAdmin();
    validateMunicipality(input, await listMunicipalities());
    final isNew = input.id.isEmpty;
    final document = isNew
        ? _municipalities.doc()
        : _municipalities.doc(input.id);
    final item = Municipality(
      document.id,
      input.name.trim(),
      input.centerLat,
      input.centerLng,
      input.radiusKm,
    );
    final reservation = _nameReservation(item.name);
    return _db.runTransaction((transaction) async {
      final previous = isNew
          ? null
          : _activeMunicipality(await transaction.get(document));
      final owner = (await transaction.get(reservation)).data()?['id'];
      if (owner != null && owner != item.id) {
        throw const RepositoryException('Une municipalité porte déjà ce nom.');
      }
      if (previous != null) {
        final oldReservation = _nameReservation(previous.name);
        if (oldReservation.path != reservation.path) {
          transaction.delete(oldReservation);
        }
      }
      transaction.set(reservation, {'id': item.id});
      transaction.set(document, {...item.toJson(), 'archived': false});
      return item;
    });
  }

  @override
  Future<void> deleteMunicipality(String id) async {
    await _requireAdmin();
    final linked = await Future.wait([
      _users.where('municipalityId', isEqualTo: id).limit(1).get(_server),
      _reports.where('municipalityId', isEqualTo: id).limit(1).get(_server),
    ]);
    if (linked.any((result) => result.docs.isNotEmpty)) {
      throw const RepositoryException(
        'Cette municipalité est liée à des agents ou à des signalements.',
      );
    }
    final document = _municipalities.doc(id);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);
      if (!snapshot.exists || snapshot.data()?['archived'] == true) return;
      final item = _activeMunicipality(snapshot);
      // Preserve a reference if a report is committed during the removal.
      transaction.update(document, {'archived': true});
      transaction.delete(_nameReservation(item.name));
    });
  }

  @override
  Stream<Account?> watchOwnAccount(String id) async* {
    _checkUser(id);
    yield* _users.doc(id).snapshots().map((snapshot) {
      final data = snapshot.data();
      return data == null
          ? null
          : Account.fromJson(id, _readDates(data, ['createdAt']));
    });
  }

  @override
  Stream<List<Account>> watchAgents() async* {
    await _requireAdmin();
    yield* _users
        .where('role', isEqualTo: 'agent')
        .snapshots()
        .map(
          (snapshot) =>
              [
                for (final doc in snapshot.docs)
                  Account.fromJson(
                    doc.id,
                    _readDates(doc.data(), ['createdAt']),
                  ),
              ]..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              ),
        );
  }

  @override
  Future<Account> createAgent(
    String name,
    String email,
    String password,
    String municipalityId,
  ) async {
    await _requireAdmin();
    validateAgentCredentials(name, email, password);
    _activeMunicipality(await _municipalities.doc(municipalityId).get(_server));

    final app = await core.Firebase.initializeApp(
      name: 'reportini-agent-${const Uuid().v4()}',
      options: _auth.app.options,
    );
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: app);
      final result = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = result.user!;
      final agent = Account(
        id: user.uid,
        name: name.trim(),
        email: user.email!,
        role: AccountRole.agent,
        municipalityId: municipalityId,
        createdAt: DateTime.now(),
      );
      try {
        await _users.doc(agent.id).set(agent.toJson());
      } catch (_) {
        try {
          await user.delete();
        } catch (_) {
          throw const RepositoryException(
            'Le profil n’a pas été créé. Le compte doit être supprimé dans Firebase Authentication avant de réessayer.',
          );
        }
        rethrow;
      }
      return agent;
    } on FirebaseAuthException catch (error) {
      throw _authError(error);
    } finally {
      try {
        try {
          await FirebaseAuth.instanceFor(app: app).signOut();
        } finally {
          await app.delete();
        }
      } catch (_) {
        // Cleanup of the isolated app must not mask the provisioning result.
      }
    }
  }

  Future<void> _updateAgent(String id, Map<String, dynamic> changes) async {
    await _requireAdmin();
    final document = _users.doc(id);
    await _db.runTransaction((transaction) async {
      final data = (await transaction.get(document)).data();
      if (data?['role'] != 'agent') {
        throw const RepositoryException('Compte agent introuvable.');
      }
      if (changes['municipalityId'] case final String municipalityId) {
        _activeMunicipality(
          await transaction.get(_municipalities.doc(municipalityId)),
        );
      }
      transaction.update(document, changes);
    });
  }

  @override
  Future<void> updateAgent(String id, {required String municipalityId}) =>
      _updateAgent(id, {'municipalityId': municipalityId});

  @override
  Future<void> setAgentEnabled(String id, bool enabled) =>
      _updateAgent(id, {'enabled': enabled});

  Stream<List<Report>> _watchReportQuery(Query<Map<String, dynamic>> query) =>
      query.snapshots().map(_sortedReports);

  @override
  Stream<List<Report>> watchMunicipalReports() async* {
    final account = await _currentAccount();
    _policy.require(_policy.canViewMunicipalReports(account));
    final query = account.role == AccountRole.admin
        ? _reports
        : _reports.where('municipalityId', isEqualTo: account.municipalityId);
    yield* _watchReportQuery(query);
  }

  @override
  Future<void> changeStatus(String id, ReportStatus status, String note) async {
    final account = await _currentAccount();
    _policy.require(_policy.canViewMunicipalReports(account));
    final document = _reports.doc(id);
    await _db.runTransaction((transaction) async {
      final data = (await transaction.get(document)).data();
      if (data == null) {
        throw const RepositoryException('Signalement introuvable.');
      }
      final report = _report(id, data);
      _policy.require(_policy.canChangeStatus(account, report));
      final event = statusEvent(report, status, account.name, note);
      final at = Timestamp.fromDate(event.at);
      transaction.update(document, {
        'status': status.code,
        'history': [
          ...(data['history'] as List),
          {...event.toJson(), 'at': at},
        ],
        'updatedAt': at,
      });
    });
  }

  @override
  Future<void> assignReport(String id, String municipalityId) async {
    await _requireAdmin();
    final document = _reports.doc(id);
    await _db.runTransaction((transaction) async {
      final municipality = _activeMunicipality(
        await transaction.get(_municipalities.doc(municipalityId)),
      );
      final data = (await transaction.get(document)).data();
      if (data == null) {
        throw const RepositoryException('Signalement introuvable.');
      }
      if (data['municipalityId'] != null) {
        throw const RepositoryException('Ce signalement est déjà affecté.');
      }
      transaction.update(document, {
        'municipalityId': municipality.id,
        'municipalityName': municipality.name,
        'updatedAt': Timestamp.now(),
      });
    });
  }

  Future<Query<Map<String, dynamic>>> _citizenReports(String id) async {
    _policy.require(_policy.isCitizen(await _currentAccount(), id));
    return _reports.where('citizenId', isEqualTo: id);
  }

  Report _report(String id, Map<String, dynamic> data) => Report.fromJson(id, {
    ..._readDates(data, ['createdAt', 'updatedAt']),
    'history': (data['history'] as List)
        .map(
          (event) =>
              _readDates(Map<String, dynamic>.from(event as Map), ['at']),
        )
        .toList(),
  });

  List<Report> _sortedReports(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      snapshot.docs.map((doc) => _report(doc.id, doc.data())).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Stream<List<Report>> watchReports(String citizenId) async* {
    yield* _watchReportQuery(await _citizenReports(citizenId));
  }

  @override
  Future<List<Report>> listReports(String citizenId) async {
    final query = await _citizenReports(citizenId);
    return _sortedReports(await query.get());
  }

  @override
  Future<Report> createReport(String citizenId, ReportDraft draft) async {
    final account = await _currentAccount();
    _policy.require(
      _policy.canCreateReport(account, citizenId, ReportStatus.enAttente),
    );
    final document = _reports.doc(draft.id);
    final previous = (await document.get(_server)).data();
    if (previous != null) return _report(document.id, previous);
    final bytes = await draft.photo.readAsBytes();
    if (bytes.isEmpty) {
      throw const RepositoryException('La photo sélectionnée est vide.');
    }

    // The stable upload and document paths let a retry reuse the same report.
    final photo = _storage.ref('reports/$citizenId/${draft.id}');
    final mimeType = draft.photo.mimeType;
    try {
      await photo.putData(
        bytes,
        SettableMetadata(
          contentType: mimeType != null && mimeType.startsWith('image/')
              ? mimeType
              : 'image/jpeg',
        ),
      );
    } on core.FirebaseException {
      final saved = (await document.get(_server)).data();
      if (saved != null) return _report(document.id, saved);
      rethrow;
    }
    final municipality = const MunicipalityLocator().locate(
      draft.location.lat,
      draft.location.lng,
      await listMunicipalities(),
    );
    final report = Report.submitted(
      draft.withMunicipality(municipality),
      citizenId,
      'gs://${photo.bucket}/${photo.fullPath}',
      citizenName: account.name,
    );
    return _db.runTransaction((transaction) async {
      final existing = (await transaction.get(document)).data();
      if (existing != null) {
        if (existing['citizenId'] != citizenId) {
          throw const RepositoryException(
            'Impossible d’enregistrer ce signalement.',
          );
        }
        return _report(document.id, existing);
      }
      transaction.set(document, report.toJson());
      return report;
    });
  }
}
