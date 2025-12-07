import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/appeal.dart';

class AppealRepository {
  AppealRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _appealsRef =>
      _firestore.collection('appeals');

  /// Tạo đơn kháng cáo
  Future<String> createAppeal({
    required String uid,
    required String banId,
    required String reason,
    List<String>? evidence,
  }) async {
    final appealDoc = _appealsRef.doc();
    final appealId = appealDoc.id;

    await appealDoc.set({
      'uid': uid,
      'banId': banId,
      'reason': reason,
      'evidence': evidence ?? [],
      'status': AppealStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return appealId;
  }

  /// Stream appeals chưa xử lý (admin view)
  Stream<List<Appeal>> watchPendingAppeals() {
    return _appealsRef
        .where('status', isEqualTo: AppealStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Appeal.fromDoc(doc)).toList());
  }

  /// Lấy chi tiết appeal
  Future<Appeal?> getAppeal(String appealId) async {
    final doc = await _appealsRef.doc(appealId).get();
    if (!doc.exists) return null;
    return Appeal.fromDoc(doc);
  }

  /// Cập nhật status appeal
  Future<void> updateAppealStatus(
    String appealId,
    AppealStatus status, {
    required String adminUid,
    String? adminNotes,
  }) async {
    await _appealsRef.doc(appealId).update({
      'status': status.name,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': adminUid,
      if (adminNotes != null) 'adminNotes': adminNotes,
    });
  }

  /// Lấy appeals của một user
  Future<List<Appeal>> getAppealsByUser(String uid) async {
    final snapshot =
        await _appealsRef.where('uid', isEqualTo: uid).get();
    final appeals = snapshot.docs.map((doc) => Appeal.fromDoc(doc)).toList();
    appeals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return appeals;
  }

  /// Stream appeals của user hiện tại
  Stream<List<Appeal>> watchAppealsByUser(String uid) {
    return _appealsRef.where('uid', isEqualTo: uid).snapshots().map(
          (snapshot) {
            final appeals =
                snapshot.docs.map((doc) => Appeal.fromDoc(doc)).toList();
            appeals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return appeals;
          },
        );
  }

  /// Lấy tất cả appeals với filter (admin view)
  Future<List<Appeal>> getAllAppeals({AppealStatus? status}) async {
    Query<Map<String, dynamic>> query =
        _appealsRef.orderBy('createdAt', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Appeal.fromDoc(doc)).toList();
  }

  /// Stream tất cả appeals với filter (admin view)
  Stream<List<Appeal>> watchAllAppeals({AppealStatus? status}) {
    Query<Map<String, dynamic>> query =
        _appealsRef.orderBy('createdAt', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Appeal.fromDoc(doc)).toList());
  }
}

