import '../models/account.dart';

abstract interface class UserRepository {
  Future<Account> updateName(String id, String name);
  Stream<Account?> watchOwnAccount(String id);
  Stream<List<Account>> watchAgents();
  Future<Account> createAgent(
    String name,
    String email,
    String password,
    String municipalityId,
  );
  Future<void> updateAgent(String id, {required String municipalityId});
  Future<void> setAgentEnabled(String id, bool enabled);
}
