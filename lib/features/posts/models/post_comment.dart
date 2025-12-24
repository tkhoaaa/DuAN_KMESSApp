import 'package:cloud_firestore/cloud_firestore.dart';

class PostComment {
  PostComment({
    required this.id,
    required this.authorUid,
    required this.text,
    required this.createdAt,
    this.parentId,
    this.replyToUid,
    this.reactionCounts = const {},
    this.replyCount = 0,
    this.editedAt,
  });

  final String id;
  final String authorUid;
  final String text;
  final DateTime? createdAt;

  /// Id của comment cha (nếu là trả lời)
  final String? parentId;

  /// UID của người được trả lời trực tiếp
  final String? replyToUid;

  /// Đếm số reaction theo loại, ví dụ: {'👍': 2, '❤️': 1}
  final Map<String, int> reactionCounts;

  /// Số câu trả lời trực tiếp (để future dùng khi phân trang sâu)
  final int replyCount;

  /// Thời điểm chỉnh sửa comment (null nếu chưa chỉnh sửa)
  final DateTime? editedAt;

  factory PostComment.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final reactionsRaw = data['reactionCounts'] as Map<String, dynamic>? ?? {};
    final reactions = reactionsRaw.map(
      (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
    );

    return PostComment(
      id: doc.id,
      authorUid: data['authorUid'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      parentId: data['parentId'] as String?,
      replyToUid: data['replyToUid'] as String?,
      reactionCounts: reactions,
      replyCount: (data['replyCount'] as num?)?.toInt() ?? 0,
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
    );
  }
}

