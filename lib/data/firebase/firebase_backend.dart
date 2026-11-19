import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/validators.dart';
import '../models/account.dart';
import '../models/municipality.dart';
import '../models/report.dart';
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

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('reports');

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
    final data = (await _users.doc(id).get()).data();
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
    return user == null ? null : _profile(user.uid);
  }

  @override
  Future<Account> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      try {
        return await _profile(result.user!.uid);
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
    _checkUser(id);
    final error = requiredText(name, 'Saisissez votre nom complet.');
    if (error != null) throw RepositoryException(error);
    await _users.doc(id).update({'name': name.trim()});
    return _profile(id);
  }

  @override
  Future<List<Municipality>> listMunicipalities() async {
    final snapshot = await _db.collection('municipalities').get();
    return snapshot.docs
        .map((doc) => Municipality.fromJson(doc.id, doc.data()))
        .toList();
  }

  Query<Map<String, dynamic>> _citizenReports(String id) {
    _checkUser(id);
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
  Stream<List<Report>> watchReports(String citizenId) =>
      _citizenReports(citizenId).snapshots().map(_sortedReports);

  @override
  Future<List<Report>> listReports(String citizenId) async =>
      _sortedReports(await _citizenReports(citizenId).get());

  @override
  Future<Report> createReport(String citizenId, ReportDraft draft) async {
    _checkUser(citizenId);
    final document = _reports.doc(draft.id);
    final bytes = await draft.photo.readAsBytes();
    if (bytes.isEmpty) {
      throw const RepositoryException('La photo sélectionnée est vide.');
    }

    // The stable upload and document paths let a retry reuse the same report.
    final photo = _storage.ref('reports/$citizenId/${draft.id}');
    await photo.putData(
      bytes,
      SettableMetadata(
        contentType: draft.photo.mimeType ?? 'application/octet-stream',
      ),
    );
    final report = Report.submitted(
      draft,
      citizenId,
      await photo.getDownloadURL(),
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
