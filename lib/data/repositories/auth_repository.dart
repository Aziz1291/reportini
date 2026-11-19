import '../models/account.dart';

class RepositoryException implements Exception {
  const RepositoryException(this.message);
  final String message;
}

abstract interface class AuthRepository {
  Future<Account?> restoreSession();
  Future<Account> signIn(String email, String password);
  Future<void> register(String name, String email, String password);
  Future<void> signOut();
}
