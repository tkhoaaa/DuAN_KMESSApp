import '../models/notification.dart';
import '../repositories/notification_repository.dart';

class NotificationService {
  NotificationService({NotificationRepository? repository})
      : _repository = repository ?? NotificationRepository();

  final NotificationRepository _repository;

  /// Tạo notification khi có like
  Future<void> createLikeNotification({
    required String postId,
    required String likerUid,
    required String postAuthorUid,
  }) async {
    // Không tạo notification nếu người like là chính tác giả
    if (likerUid == postAuthorUid) return;

    final notification = Notification(
      id: '', // Sẽ được tạo bởi Firestore
      type: NotificationType.like,
      fromUid: likerUid,
      toUid: postAuthorUid,
      postId: postId,
      read: false,
      createdAt: DateTime.now(),
    );

    await _repository.createNotification(notification);
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

  /// Tạo notification khi có follow
  Future<void> createFollowNotification({
    required String followerUid,
    required String followedUid,
  }) async {
    // Không tạo notification nếu follow chính mình
    if (followerUid == followedUid) return;

    final notification = Notification(
      id: '',
      type: NotificationType.follow,
      fromUid: followerUid,
      toUid: followedUid,
      read: false,
      createdAt: DateTime.now(),
    );

    await _repository.createNotification(notification);
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
}

