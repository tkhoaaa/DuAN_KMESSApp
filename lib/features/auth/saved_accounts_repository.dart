import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../profile/user_profile_repository.dart';

class SavedAccount {
  SavedAccount({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.providerId,
    required this.lastUsedAt,
  });

  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final String providerId;
  final DateTime lastUsedAt;

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'providerId': providerId,
      'lastUsedAt': lastUsedAt.toIso8601String(),
    };
  }

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    return SavedAccount(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      photoUrl: json['photoUrl'] as String?,
      providerId: json['providerId'] as String? ?? 'password',
      lastUsedAt: DateTime.tryParse(json['lastUsedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class SavedAccountsRepository {
  SavedAccountsRepository._();

  static const String _storageKey = 'saved_accounts';
  static final SavedAccountsRepository instance = SavedAccountsRepository._();

  Future<List<SavedAccount>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? <String>[];
    final result = <SavedAccount>[];
    for (final item in raw) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        result.add(SavedAccount.fromJson(map));
      } catch (_) {
        // ignore invalid item
      }
    }
    // Sắp xếp tài khoản dùng gần nhất lên trên
    result.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    return result;
  }

  Future<void> saveAccountFromUser(User user) async {
    final providerId =
        user.providerData.isNotEmpty ? user.providerData.first.providerId : 'password';
    
    // Lấy avatar từ profile nếu có, nếu không mới lấy từ Firebase user
    // Điều này đảm bảo avatar đã thay đổi bởi user sẽ được lưu đúng
    String? photoUrl = user.photoURL;
    try {
      final profile = await userProfileRepository.fetchProfile(user.uid);
      if (profile != null && profile.photoUrl != null && profile.photoUrl!.isNotEmpty) {
        photoUrl = profile.photoUrl;
      }
    } catch (e) {
      // Nếu không lấy được profile, dùng avatar từ Firebase user
      // Ignore error
    }
    
    final account = SavedAccount(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
      photoUrl: photoUrl,
      providerId: providerId,
      lastUsedAt: DateTime.now(),
    );
    await upsertAccount(account);
  }

  Future<void> upsertAccount(SavedAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAccounts();
    final existingIndex = accounts.indexWhere((a) => a.uid == account.uid);
    if (existingIndex >= 0) {
      accounts[existingIndex] = account;
    } else {
      accounts.add(account);
    }
    final raw = accounts.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_storageKey, raw);
  }

  Future<void> removeAccount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAccounts();
    accounts.removeWhere((a) => a.uid == uid);
    final raw = accounts.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_storageKey, raw);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}


