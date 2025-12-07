import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/report.dart';

class ReportRepository {
  ReportRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('reports');

  Future<String> submitReport({
    required String reporterUid,
    required ReportTargetType targetType,
    required String targetId,
    String? targetOwnerUid,
    required String reason,
  }) async {
    final docRef = await _reports.add({
      'reporterUid': reporterUid,
      'targetType': targetType.name,
      'targetId': targetId,
      'targetOwnerUid': targetOwnerUid,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Stream reports chưa xử lý (admin view)
  Stream<List<Report>> watchPendingReports() {
    return _reports
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Report.fromDoc(doc)).toList());
  }

  /// Stream reports với filter (admin view)
  Stream<List<Report>> watchReports({ReportStatus? status}) {
    Query<Map<String, dynamic>> query =
        _reports.orderBy('createdAt', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Report.fromDoc(doc)).toList());
  }

  /// Cập nhật status report
  Future<void> updateReportStatus(
    String reportId,
    ReportStatus status, {
    String? adminNotes,
    String? adminUid,
    String? banId,
    ReportAction? actionTaken,
  }) async {
    final updates = <String, dynamic>{
      'status': status.name,
      if (status != ReportStatus.pending) 'resolvedAt': FieldValue.serverTimestamp(),
      if (adminUid != null) 'resolvedBy': adminUid,
      if (adminNotes != null) 'adminNotes': adminNotes,
      if (banId != null) 'banId': banId,
      if (actionTaken != null) 'actionTaken': actionTaken.name,
    };

    await _reports.doc(reportId).update(updates);
  }

  /// Lấy chi tiết report
  Future<Report?> getReport(String reportId) async {
    final doc = await _reports.doc(reportId).get();
    if (!doc.exists) return null;
    return Report.fromDoc(doc);
  }

  /// Lấy tất cả reports về một user (admin view)
  Future<List<Report>> getReportsByTarget(String targetUid) async {
    final snapshot = await _reports
        .where('targetOwnerUid', isEqualTo: targetUid)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Report.fromDoc(doc)).toList();
  }

  /// Lấy tất cả reports với filter (admin view)
  Future<List<Report>> getAllReports({ReportStatus? status}) async {
    Query<Map<String, dynamic>> query =
        _reports.orderBy('createdAt', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Report.fromDoc(doc)).toList();
  }
}

