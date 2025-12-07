import 'package:cloud_firestore/cloud_firestore.dart';

enum BanType {
  temporary,
  permanent,
}

enum BanLevel {
  warning, // Cảnh báo (chưa khóa)
  light, // Vi phạm nhẹ → khóa 1-3 ngày
  medium, // Vi phạm trung bình → khóa 7-30 ngày
  severe, // Vi phạm nghiêm trọng → khóa vĩnh viễn
}

class Ban {
  Ban({
    required this.id,
    required this.uid,
    required this.banType,
    required this.banLevel,
    required this.reason,
    this.reportId,
    required this.bannedAt,
    this.expiresAt,
    required this.bannedBy,
    this.isActive = true,
    this.appealId,
  });

  final String id;
  final String uid;
  final BanType banType;
  final BanLevel banLevel;
  final String reason;
  final String? reportId;
  final DateTime bannedAt;
  final DateTime? expiresAt; // null nếu permanent ban
  final String bannedBy; // Admin UID
  final bool isActive;
  final String? appealId; // ID của appeal nếu user đã kháng cáo

  bool get isExpired {
    if (banType == BanType.permanent) return false;
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  factory Ban.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Ban(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      banType: _parseBanType(data['banType'] as String?),
      banLevel: _parseBanLevel(data['banLevel'] as String?),
      reason: data['reason'] as String? ?? '',
      reportId: data['reportId'] as String?,
      bannedAt: (data['bannedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      bannedBy: data['bannedBy'] as String? ?? '',
      isActive: (data['isActive'] as bool?) ?? true,
      appealId: data['appealId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'banType': banType.name,
      'banLevel': banLevel.name,
      'reason': reason,
      if (reportId != null) 'reportId': reportId,
      'bannedAt': Timestamp.fromDate(bannedAt),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      'bannedBy': bannedBy,
      'isActive': isActive,
      if (appealId != null) 'appealId': appealId,
    };
  }

  static BanType _parseBanType(String? raw) {
    return BanType.values.firstWhere(
      (type) => type.name == raw,
      orElse: () => BanType.temporary,
    );
  }

  static BanLevel _parseBanLevel(String? raw) {
    return BanLevel.values.firstWhere(
      (level) => level.name == raw,
      orElse: () => BanLevel.light,
    );
  }
}

