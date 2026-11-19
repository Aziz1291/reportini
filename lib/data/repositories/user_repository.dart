import '../models/account.dart';

abstract interface class UserRepository {
  Future<Account> updateName(String id, String name);
}
