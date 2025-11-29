import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification_digest.dart';

class NotificationDigestRepository {
  NotificationDigestRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _digests(String uid) =>
      _firestore.collection('notification_digests').doc(uid).collection('items');

  /// Tạo digest mới
  Future<String> createDigest(NotificationDigest digest) async {
    final docRef = _digests(digest.uid).doc();
    await docRef.set(digest.toMap());
    return docRef.id;
  }

  /// Lấy digest theo ID
  Future<NotificationDigest?> fetchDigest({
    required String uid,
    required String digestId,
  }) async {
    final doc = await _digests(uid).doc(digestId).get();
    if (!doc.exists) return null;
    return NotificationDigest.fromDoc(doc);
  }

  /// Lấy digests của user với pagination
  Future<List<NotificationDigest>> fetchDigests({
    required String uid,
    DigestPeriod? period,
    int limit = 10,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _digests(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (period != null) {
      final periodStr = period == DigestPeriod.weekly ? 'weekly' : 'daily';
      query = query.where('period', isEqualTo: periodStr);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => NotificationDigest.fromDoc(doc)).toList();
  }

  /// Watch digests của user
  /// Lưu ý: Với subcollection, không thể dùng where + orderBy cùng lúc mà không có index
  /// Nên ta sẽ orderBy trước, rồi filter period ở client-side
  Stream<List<NotificationDigest>> watchDigests({
    required String uid,
    DigestPeriod? period,
    int limit = 10,
  }) {
    Query<Map<String, dynamic>> query = _digests(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit * 2); // Lấy nhiều hơn để filter client-side

    return query.snapshots().map(
          (snapshot) {
            var digests = snapshot.docs
                .map((doc) => NotificationDigest.fromDoc(doc))
                .toList();
            
            // Filter theo period ở client-side nếu có
            if (period != null) {
              final periodStr = period == DigestPeriod.weekly ? 'weekly' : 'daily';
              digests = digests
                  .where((d) => d.period == period)
                  .take(limit)
                  .toList();
            } else {
              digests = digests.take(limit).toList();
            }
            
            return digests;
          },
        );
  }

  /// Tìm digest cho một period cụ thể
  Future<NotificationDigest?> findDigestForPeriod({
    required String uid,
    required DigestPeriod period,
    required DateTime startDate,
  }) async {
    final periodStr = period == DigestPeriod.weekly ? 'weekly' : 'daily';
    final snapshot = await _digests(uid)
        .where('period', isEqualTo: periodStr)
        .where('startDate', isEqualTo: Timestamp.fromDate(startDate))
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return NotificationDigest.fromDoc(snapshot.docs.first);
  }

  /// Xóa digest cũ (nếu cần cleanup)
  Future<void> deleteDigest({
    required String uid,
    required String digestId,
  }) async {
    await _digests(uid).doc(digestId).delete();
  }
}

