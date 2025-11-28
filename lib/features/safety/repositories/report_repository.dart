import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/report.dart';

class ReportRepository {
  ReportRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('reports');

  Future<void> submitReport({
    required String reporterUid,
    required ReportTargetType targetType,
    required String targetId,
    String? targetOwnerUid,
    required String reason,
  }) async {
    await _reports.add({
      'reporterUid': reporterUid,
      'targetType': targetType.name,
      'targetId': targetId,
      'targetOwnerUid': targetOwnerUid,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

