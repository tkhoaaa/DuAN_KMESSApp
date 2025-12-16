import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedCredentialsRepository {
  SavedCredentialsRepository._();

  static final SavedCredentialsRepository instance =
      SavedCredentialsRepository._();

  static const _keyPrefix = 'cred_'; // cred_<uid> -> password

  FlutterSecureStorage get _storage => const FlutterSecureStorage();

  Future<void> savePassword({
    required String uid,
    required String password,
  }) async {
    await _storage.write(key: '$_keyPrefix$uid', value: password);
  }

  Future<String?> getPassword(String uid) async {
    return _storage.read(key: '$_keyPrefix$uid');
  }

  Future<void> removePassword(String uid) async {
    await _storage.delete(key: '$_keyPrefix$uid');
  }

  Future<void> clearAll() async {
    // Xoá toàn bộ credential do repo này quản lý
    final all = await _storage.readAll();
    for (final entry in all.entries) {
      if (entry.key.startsWith(_keyPrefix)) {
        await _storage.delete(key: entry.key);
      }
    }
  }
}


