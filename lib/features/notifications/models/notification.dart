import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  like,
  comment,
  follow,
  message,
  call,
  report, // Report notification cho admin
  appeal, // Appeal notification cho admin
  storyLike, // Tim (like) story
  commentReaction, // Reaction (emoji) trên comment
  save, // Lưu bài viết
  share, // Chia sẻ bài viết
  replyComment, // Trả lời bình luận
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
    this.callId,
    this.reportId,
    this.appealId,
    this.targetUid, // UID của người bị report (để navigate đến profile)
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
  final String? callId;
  final String? reportId; // ID của report (cho notification type report)
  final String? appealId; // ID của appeal (cho notification type appeal)
  final String? targetUid; // UID của người bị report (để navigate đến profile)
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
      case 'call':
        type = NotificationType.call;
        break;
      case 'report':
        type = NotificationType.report;
        break;
      case 'appeal':
        type = NotificationType.appeal;
        break;
      case 'storyLike':
        type = NotificationType.storyLike;
        break;
      case 'commentReaction':
        type = NotificationType.commentReaction;
        break;
      case 'save':
        type = NotificationType.save;
        break;
      case 'share':
        type = NotificationType.share;
        break;
      case 'replyComment':
        type = NotificationType.replyComment;
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
      callId: data['callId'] as String?,
      reportId: data['reportId'] as String?,
      appealId: data['appealId'] as String?,
      targetUid: data['targetUid'] as String?,
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
      case NotificationType.call:
        typeStr = 'call';
        break;
      case NotificationType.report:
        typeStr = 'report';
        break;
      case NotificationType.appeal:
        typeStr = 'appeal';
        break;
      case NotificationType.storyLike:
        typeStr = 'storyLike';
        break;
      case NotificationType.commentReaction:
        typeStr = 'commentReaction';
        break;
      case NotificationType.save:
        typeStr = 'save';
        break;
      case NotificationType.share:
        typeStr = 'share';
        break;
      case NotificationType.replyComment:
        typeStr = 'replyComment';
        break;
    }

    return {
      'type': typeStr,
      'fromUid': fromUid,
      'toUid': toUid,
      if (postId != null) 'postId': postId,
      if (commentId != null) 'commentId': commentId,
      if (conversationId != null) 'conversationId': conversationId,
      if (callId != null) 'callId': callId,
      if (reportId != null) 'reportId': reportId,
      if (appealId != null) 'appealId': appealId,
      if (targetUid != null) 'targetUid': targetUid,
      'read': read,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      if (text != null) 'text': text,
      if (groupKey != null) 'groupKey': groupKey,
      'count': count,
      if (fromUids != null && fromUids!.isNotEmpty) 'fromUids': fromUids,
    };
  }
}

