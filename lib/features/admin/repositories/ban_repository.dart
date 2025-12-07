import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ban.dart';

class BanRepository {
  BanRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _bansRef =>
      _firestore.collection('bans');

  /// Tạo ban mới
  Future<String> createBan({
    required String uid,
    required BanType banType,
    required BanLevel banLevel,
    required String reason,
    String? reportId,
    required String adminUid,
    DateTime? expiresAt,
  }) async {
    final banDoc = _bansRef.doc();
    final banId = banDoc.id;

    await banDoc.set({
      'uid': uid,
      'banType': banType.name,
      'banLevel': banLevel.name,
      'reason': reason,
      if (reportId != null) 'reportId': reportId,
      'bannedAt': FieldValue.serverTimestamp(),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt),
      'bannedBy': adminUid,
      'isActive': true,
    });

    return banId;
  }

  /// Lấy ban đang active của user
  Future<Ban?> getActiveBan(String uid) async {
    final snapshot = await _bansRef
        .where('uid', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return Ban.fromDoc(snapshot.docs.first);
  }

  /// Stream ban status của user
  Stream<Ban?> watchActiveBan(String uid) {
    return _bansRef
        .where('uid', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return Ban.fromDoc(snapshot.docs.first);
    });
  }

  /// Mở khóa tài khoản
  Future<void> unbanUser(
    String banId,
    String adminUid, {
    String? reason,
  }) async {
    await _bansRef.doc(banId).update({
      'isActive': false,
      'unbannedAt': FieldValue.serverTimestamp(),
      'unbannedBy': adminUid,
      if (reason != null) 'unbanReason': reason,
    });
  }

  /// Lấy ban theo ID
  Future<Ban?> getBan(String banId) async {
    final doc = await _bansRef.doc(banId).get();
    if (!doc.exists) return null;
    return Ban.fromDoc(doc);
  }

  /// Lấy danh sách bans (admin view)
  Future<List<Ban>> getAllBans({
    BanType? banType,
    BanLevel? banLevel,
    bool? isActive,
  }) async {
    Query<Map<String, dynamic>> query = _bansRef.orderBy('bannedAt', descending: true);

    if (banType != null) {
      query = query.where('banType', isEqualTo: banType.name);
    }

    if (banLevel != null) {
      query = query.where('banLevel', isEqualTo: banLevel.name);
    }

    if (isActive != null) {
      query = query.where('isActive', isEqualTo: isActive);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Ban.fromDoc(doc)).toList();
  }

  /// Stream tất cả bans (admin view)
  Stream<List<Ban>> watchAllBans({
    BanType? banType,
    BanLevel? banLevel,
    bool? isActive,
  }) {
    Query<Map<String, dynamic>> query = _bansRef.orderBy('bannedAt', descending: true);

    if (banType != null) {
      query = query.where('banType', isEqualTo: banType.name);
    }

    if (banLevel != null) {
      query = query.where('banLevel', isEqualTo: banLevel.name);
    }

    if (isActive != null) {
      query = query.where('isActive', isEqualTo: isActive);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Ban.fromDoc(doc)).toList());
  }

  /// Kiểm tra user có bị ban không
  Future<bool> checkIfBanned(String uid) async {
    final ban = await getActiveBan(uid);
    if (ban == null) return false;
    if (ban.isExpired) {
      // Auto unban nếu đã hết hạn
      await unbanUser(ban.id, 'system', reason: 'Auto unban - expired');
      return false;
    }
    return ban.isActive;
  }

  /// Cập nhật appealId vào ban
  Future<void> updateBanAppealId(String banId, String appealId) async {
    await _bansRef.doc(banId).update({
      'appealId': appealId,
    });
  }
}

