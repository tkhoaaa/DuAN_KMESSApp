import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportTargetType {
  user,
  post,
  comment,
  story,
}

class Report {
  Report({
    required this.id,
    required this.reporterUid,
    required this.targetId,
    required this.targetType,
    this.targetOwnerUid,
    this.reason,
    this.status,
    this.createdAt,
  });

  final String id;
  final String reporterUid;
  final String targetId;
  final ReportTargetType targetType;
  final String? targetOwnerUid;
  final String? reason;
  final String? status;
  final DateTime? createdAt;

  factory Report.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Report(
      id: doc.id,
      reporterUid: data['reporterUid'] as String? ?? '',
      targetId: data['targetId'] as String? ?? '',
      targetType: _parseTargetType(data['targetType'] as String?),
      targetOwnerUid: data['targetOwnerUid'] as String?,
      reason: data['reason'] as String?,
      status: data['status'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static ReportTargetType _parseTargetType(String? raw) {
    return ReportTargetType.values.firstWhere(
      (type) => type.name == raw,
      orElse: () => ReportTargetType.post,
    );
  }
}

