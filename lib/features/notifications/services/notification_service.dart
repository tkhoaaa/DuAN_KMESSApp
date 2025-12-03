import '../../call/models/call.dart';
import '../models/notification.dart';
import '../repositories/notification_repository.dart';

class NotificationService {
  NotificationService({NotificationRepository? repository})
      : _repository = repository ?? NotificationRepository();

  final NotificationRepository _repository;

  /// Generate group key cho notification
  /// Format: {type}_{postId?}_{toUid}
  String _generateGroupKey({
    required NotificationType type,
    required String toUid,
    String? postId,
  }) {
    switch (type) {
      case NotificationType.like:
        if (postId == null) {
          throw ArgumentError('postId is required for like notifications');
        }
        return 'like_${postId}_$toUid';
      case NotificationType.follow:
        return 'follow_$toUid';
      case NotificationType.comment:
      case NotificationType.message:
      case NotificationType.call:
        // Comments, messages và calls không group
        throw ArgumentError('Comments, messages and calls should not be grouped');
    }
  }

  /// Tạo notification khi có like (với grouping)
  Future<void> createLikeNotification({
    required String postId,
    required String likerUid,
    required String postAuthorUid,
  }) async {
    // Không tạo notification nếu người like là chính tác giả
    if (likerUid == postAuthorUid) return;

    final groupKey = _generateGroupKey(
      type: NotificationType.like,
      toUid: postAuthorUid,
      postId: postId,
    );

    // Tìm notification đã tồn tại trong 1 giờ gần đây
    final existingNotification = await _repository.findGroupedNotification(
      groupKey: groupKey,
      toUid: postAuthorUid,
      timeWindow: const Duration(hours: 1),
    );

    if (existingNotification != null) {
      // Update notification đã tồn tại
      await _repository.updateGroupedNotification(
        notificationId: existingNotification.id,
        fromUid: likerUid,
      );
    } else {
      // Tạo notification mới với groupKey
      final notification = Notification(
        id: '', // Sẽ được tạo bởi Firestore
        type: NotificationType.like,
        fromUid: likerUid,
        toUid: postAuthorUid,
        postId: postId,
        read: false,
        createdAt: DateTime.now(),
        groupKey: groupKey,
        count: 1,
        fromUids: [likerUid],
      );

      await _repository.createNotification(notification);
    }
  }

  /// Tạo notification khi có comment
  Future<void> createCommentNotification({
    required String postId,
    required String commentId,
    required String commenterUid,
    required String postAuthorUid,
    String? commentText,
  }) async {
    // Không tạo notification nếu người comment là chính tác giả
    if (commenterUid == postAuthorUid) return;

    final notification = Notification(
      id: '',
      type: NotificationType.comment,
      fromUid: commenterUid,
      toUid: postAuthorUid,
      postId: postId,
      commentId: commentId,
      read: false,
      createdAt: DateTime.now(),
      text: commentText,
    );

    await _repository.createNotification(notification);
  }

  /// Tạo notification khi có follow (với grouping)
  Future<void> createFollowNotification({
    required String followerUid,
    required String followedUid,
  }) async {
    // Không tạo notification nếu follow chính mình
    if (followerUid == followedUid) return;

    final groupKey = _generateGroupKey(
      type: NotificationType.follow,
      toUid: followedUid,
    );

    // Tìm notification đã tồn tại trong 1 giờ gần đây
    final existingNotification = await _repository.findGroupedNotification(
      groupKey: groupKey,
      toUid: followedUid,
      timeWindow: const Duration(hours: 1),
    );

    if (existingNotification != null) {
      // Update notification đã tồn tại
      await _repository.updateGroupedNotification(
        notificationId: existingNotification.id,
        fromUid: followerUid,
      );
    } else {
      // Tạo notification mới với groupKey
      final notification = Notification(
        id: '',
        type: NotificationType.follow,
        fromUid: followerUid,
        toUid: followedUid,
        read: false,
        createdAt: DateTime.now(),
        groupKey: groupKey,
        count: 1,
        fromUids: [followerUid],
      );

      await _repository.createNotification(notification);
    }
  }

  /// Tạo notification khi có message
  Future<void> createMessageNotification({
    required String conversationId,
    required String senderUid,
    required String receiverUid,
    String? messageText,
  }) async {
    // Không tạo notification nếu gửi cho chính mình
    if (senderUid == receiverUid) return;

    final notification = Notification(
      id: '',
      type: NotificationType.message,
      fromUid: senderUid,
      toUid: receiverUid,
      conversationId: conversationId,
      read: false,
      createdAt: DateTime.now(),
      text: messageText,
    );

    await _repository.createNotification(notification);
  }

  /// Đánh dấu notification là đã đọc
  Future<void> markAsRead(String notificationId) async {
    await _repository.markAsRead(notificationId);
  }

  /// Đánh dấu tất cả notifications là đã đọc
  Future<void> markAllAsRead(String uid) async {
    await _repository.markAllAsRead(uid);
  }

  /// Lấy danh sách notifications
  Stream<List<Notification>> watchNotifications(String uid) {
    return _repository.watchNotifications(uid);
  }

  /// Đếm số lượng notifications chưa đọc
  Stream<int> watchUnreadCount(String uid) {
    return _repository.watchUnreadCount(uid);
  }

  /// Tạo notification khi có incoming call
  Future<void> createCallNotification({
    required String callId,
    required String callerUid,
    required String calleeUid,
    required CallType callType,
  }) async {
    // Không tạo notification nếu gọi cho chính mình
    if (callerUid == calleeUid) return;

    final notification = Notification(
      id: '',
      type: NotificationType.call,
      fromUid: callerUid,
      toUid: calleeUid,
      callId: callId,
      read: false,
      createdAt: DateTime.now(),
      text: callType == CallType.voice ? 'Cuộc gọi thoại' : 'Cuộc gọi video',
    );

    await _repository.createNotification(notification);
  }
}

