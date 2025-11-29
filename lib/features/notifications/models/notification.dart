import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  like,
  comment,
  follow,
  message,
}

class Notification {
  Notification({
    required this.id,
    required this.type,
    required this.fromUid,
    required this.toUid,
    this.postId,
    this.commentId,
    this.conversationId,
    required this.read,
    required this.createdAt,
    this.text,
    this.groupKey,
    this.count = 1,
    this.fromUids,
  });

  final String id;
  final NotificationType type;
  final String fromUid;
  final String toUid;
  final String? postId;
  final String? commentId;
  final String? conversationId;
  final bool read;
  final DateTime? createdAt;
  final String? text; // Text của comment hoặc message
  final String? groupKey; // Key để group notifications (format: {type}_{postId?}_{toUid})
  final int count; // Số lượng notifications được group (default: 1)
  final List<String>? fromUids; // Danh sách UIDs của những người đã thực hiện action

  factory Notification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final typeStr = data['type'] as String? ?? '';
    NotificationType type;
    switch (typeStr) {
      case 'like':
        type = NotificationType.like;
        break;
      case 'comment':
        type = NotificationType.comment;
        break;
      case 'follow':
        type = NotificationType.follow;
        break;
      case 'message':
        type = NotificationType.message;
        break;
      default:
        type = NotificationType.like;
    }

    final fromUidsData = data['fromUids'] as List<dynamic>?;
    final fromUids = fromUidsData != null
        ? fromUidsData.map((item) => item.toString()).toList()
        : null;

    return Notification(
      id: doc.id,
      type: type,
      fromUid: data['fromUid'] as String? ?? '',
      toUid: data['toUid'] as String? ?? '',
      postId: data['postId'] as String?,
      commentId: data['commentId'] as String?,
      conversationId: data['conversationId'] as String?,
      read: data['read'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      text: data['text'] as String?,
      groupKey: data['groupKey'] as String?,
      count: (data['count'] as num?)?.toInt() ?? 1,
      fromUids: fromUids,
    );
  }

  Map<String, dynamic> toMap() {
    String typeStr;
    switch (type) {
      case NotificationType.like:
        typeStr = 'like';
        break;
      case NotificationType.comment:
        typeStr = 'comment';
        break;
      case NotificationType.follow:
        typeStr = 'follow';
        break;
      case NotificationType.message:
        typeStr = 'message';
        break;
    }

    return {
      'type': typeStr,
      'fromUid': fromUid,
      'toUid': toUid,
      if (postId != null) 'postId': postId,
      if (commentId != null) 'commentId': commentId,
      if (conversationId != null) 'conversationId': conversationId,
      'read': read,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      if (text != null) 'text': text,
      if (groupKey != null) 'groupKey': groupKey,
      'count': count,
      if (fromUids != null && fromUids!.isNotEmpty) 'fromUids': fromUids,
    };
  }
}

