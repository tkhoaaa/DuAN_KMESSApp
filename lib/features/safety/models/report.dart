import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportTargetType {
  user,
  post,
  comment,
  story,
}

enum ReportStatus {
  pending,
  resolved,
  rejected,
}

enum ReportAction {
  none, // Bỏ qua report
  warning, // Cảnh báo (ghi nhận)
  banned, // Khóa tài khoản
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
    this.adminNotes,
    this.resolvedAt,
    this.resolvedBy,
    this.actionTaken,
    this.banId,
  });

  final String id;
  final String reporterUid;
  final String targetId;
  final ReportTargetType targetType;
  final String? targetOwnerUid;
  final String? reason;
  final String? status; // Legacy field, sử dụng ReportStatus enum
  final DateTime? createdAt;
  final String? adminNotes; // Ghi chú của admin khi xử lý
  final DateTime? resolvedAt; // Thời gian admin xử lý
  final String? resolvedBy; // Admin UID xử lý
  final ReportAction? actionTaken; // Hành động đã thực hiện
  final String? banId; // ID của ban document nếu admin quyết định khóa

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
      adminNotes: data['adminNotes'] as String?,
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      resolvedBy: data['resolvedBy'] as String?,
      actionTaken: _parseActionTaken(data['actionTaken'] as String?),
      banId: data['banId'] as String?,
    );
  }

  ReportStatus get reportStatus {
    if (status == null) return ReportStatus.pending;
    switch (status!.toLowerCase()) {
      case 'pending':
        return ReportStatus.pending;
      case 'resolved':
        return ReportStatus.resolved;
      case 'rejected':
        return ReportStatus.rejected;
      default:
        return ReportStatus.pending;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'reporterUid': reporterUid,
      'targetType': targetType.name,
      'targetId': targetId,
      if (targetOwnerUid != null) 'targetOwnerUid': targetOwnerUid,
      if (reason != null) 'reason': reason,
      'status': status ?? 'pending',
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (adminNotes != null) 'adminNotes': adminNotes,
      if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
      if (resolvedBy != null) 'resolvedBy': resolvedBy,
      if (actionTaken != null) 'actionTaken': actionTaken!.name,
      if (banId != null) 'banId': banId,
    };
  }

  static ReportAction? _parseActionTaken(String? raw) {
    if (raw == null) return null;
    return ReportAction.values.firstWhere(
      (action) => action.name == raw,
      orElse: () => ReportAction.none,
    );
  }

  static ReportTargetType _parseTargetType(String? raw) {
    return ReportTargetType.values.firstWhere(
      (type) => type.name == raw,
      orElse: () => ReportTargetType.post,
    );
  }
}

