import 'package:cloud_firestore/cloud_firestore.dart';

enum AppealStatus {
  pending,
  approved,
  rejected,
}

class Appeal {
  Appeal({
    required this.id,
    required this.uid,
    required this.banId,
    required this.reason,
    this.evidence = const [],
    this.status = AppealStatus.pending,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.adminNotes,
  });

  final String id;
  final String uid; // User gửi đơn kháng cáo
  final String banId; // ID của ban đang kháng cáo
  final String reason; // Lý do kháng cáo
  final List<String> evidence; // List URLs ảnh/bằng chứng
  final AppealStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy; // Admin UID xử lý
  final String? adminNotes; // Ghi chú của admin khi reject/approve

  factory Appeal.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final evidenceData = data['evidence'] as List<dynamic>? ?? [];
    return Appeal(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      banId: data['banId'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      evidence: evidenceData.map((e) => e.toString()).toList(),
      status: _parseStatus(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'] as String?,
      adminNotes: data['adminNotes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'banId': banId,
      'reason': reason,
      'evidence': evidence,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (adminNotes != null) 'adminNotes': adminNotes,
    };
  }

  static AppealStatus _parseStatus(String? raw) {
    return AppealStatus.values.firstWhere(
      (status) => status.name == raw,
      orElse: () => AppealStatus.pending,
    );
  }
}

