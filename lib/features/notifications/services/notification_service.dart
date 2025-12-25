import '../../admin/repositories/admin_repository.dart';
import '../../call/models/call.dart';
import '../../profile/user_profile_repository.dart';
import '../models/notification.dart';
import '../repositories/notification_repository.dart';

class NotificationService {
  NotificationService({
    NotificationRepository? repository,
    AdminRepository? adminRepository,
    UserProfileRepository? profileRepository,
  })  : _repository = repository ?? NotificationRepository(),
        _adminRepository = adminRepository ?? AdminRepository(),
        _profiles = profileRepository ?? userProfileRepository;

  final NotificationRepository _repository;
  final AdminRepository _adminRepository;
  final UserProfileRepository _profiles;

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
      case NotificationType.save:
        if (postId == null) {
          throw ArgumentError('postId is required for save notifications');
        }
        return 'save_${postId}_$toUid';
      case NotificationType.share:
        if (postId == null) {
          throw ArgumentError('postId is required for share notifications');
        }
        return 'share_${postId}_$toUid';
      case NotificationType.comment:
      case NotificationType.message:
      case NotificationType.call:
      case NotificationType.report:
      case NotificationType.appeal:
      case NotificationType.storyLike:
      case NotificationType.commentReaction:
      case NotificationType.replyComment:
        // Comments, messages, calls, reports, appeals, story likes, comment reactions, reply comments không group
        throw ArgumentError('This notification type should not be grouped');
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

    String? commenterName;
    try {
      final profile = await _profiles.fetchProfile(commenterUid);
      if (profile != null) {
        if (profile.displayName?.isNotEmpty == true) {
          commenterName = profile.displayName;
        } else if (profile.email?.isNotEmpty == true) {
          commenterName = profile.email;
        }
      }
    } catch (_) {
      // Không block notification nếu lỗi load profile
    }

    final trimmedComment = commentText?.trim() ?? '';
    final notificationText = [
      if (commenterName != null) commenterName,
      if (trimmedComment.isNotEmpty) trimmedComment,
    ].join(': ');

    final notification = Notification(
      id: '',
      type: NotificationType.comment,
      fromUid: commenterUid,
      toUid: postAuthorUid,
      postId: postId,
      commentId: commentId,
      read: false,
      createdAt: DateTime.now(),
      text: notificationText.isNotEmpty ? notificationText : null,
    );

    await _repository.createNotification(notification);
  }

  /// Tạo notification khi có reply comment
  Future<void> createReplyCommentNotification({
    required String postId,
    required String commentId,
    required String replyCommentId,
    required String replierUid,
    required String commentAuthorUid,
    String? replyText,
  }) async {
    // Không tạo notification nếu người reply là chính tác giả comment
    if (replierUid == commentAuthorUid) return;

    // Lấy tên người reply
    String? replierName;
    try {
      final profile = await userProfileRepository.fetchProfile(replierUid);
      replierName = profile?.displayName?.isNotEmpty == true
          ? profile!.displayName!
          : (profile?.email?.isNotEmpty == true ? profile!.email! : null);
    } catch (_) {
      // Không block notification nếu lỗi load profile
    }

    final trimmedReply = replyText?.trim() ?? '';
    final notificationText = [
      if (replierName != null) replierName,
      if (trimmedReply.isNotEmpty) trimmedReply,
    ].join(': ');

    final notification = Notification(
      id: '',
      type: NotificationType.replyComment,
      fromUid: replierUid,
      toUid: commentAuthorUid,
      postId: postId,
      commentId: commentId, // ID của comment gốc
      read: false,
      createdAt: DateTime.now(),
      text: notificationText.isNotEmpty ? notificationText : null,
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

  /// Tạo notification khi có tim (like) story
  Future<void> createStoryLikeNotification({
    required String storyId,
    required String storyAuthorUid,
    required String likerUid,
  }) async {
    // Không tạo notification nếu người tim là chính tác giả
    if (likerUid == storyAuthorUid) return;

    final notification = Notification(
      id: '',
      type: NotificationType.storyLike,
      fromUid: likerUid,
      toUid: storyAuthorUid,
      // storyId sẽ được lưu trong postId field để tái sử dụng cấu trúc hiện tại
      postId: storyId,
      read: false,
      createdAt: DateTime.now(),
    );

    await _repository.createNotification(notification);
  }

  /// Tạo notification khi có reaction vào comment
  Future<void> createCommentReactionNotification({
    required String postId,
    required String commentId,
    required String commentAuthorUid,
    required String reactorUid,
    required String reactionType,
  }) async {
    // Không tạo notification nếu người reaction là chính tác giả comment
    if (reactorUid == commentAuthorUid) return;

    final notification = Notification(
      id: '',
      type: NotificationType.commentReaction,
      fromUid: reactorUid,
      toUid: commentAuthorUid,
      postId: postId,
      commentId: commentId,
      read: false,
      createdAt: DateTime.now(),
      text: reactionType, // Lưu loại reaction (emoji) vào text field
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

  /// Tạo notification cho admin khi có report mới
  Future<void> createReportNotification({
    required String reportId,
    required String reporterUid,
    required String targetUid,
  }) async {
    // Lấy danh sách tất cả admin
    final adminUids = await _adminRepository.getAllAdmins();
    if (adminUids.isEmpty) return; // Không có admin nào

    // Tạo notification cho mỗi admin
    final notifications = adminUids.map((adminUid) {
      return Notification(
        id: '',
        type: NotificationType.report,
        fromUid: reporterUid,
        toUid: adminUid,
        reportId: reportId,
        targetUid: targetUid, // UID của người bị report
        read: false,
        createdAt: DateTime.now(),
        text: 'Có báo cáo mới về người dùng',
      );
    }).toList();

    // Tạo tất cả notifications
    for (final notification in notifications) {
      await _repository.createNotification(notification);
    }
  }

  /// Tạo notification cho admin khi có appeal mới
  Future<void> createAppealNotification({
    required String appealId,
    required String uid,
    required String banId,
  }) async {
    // Lấy danh sách tất cả admin
    final adminUids = await _adminRepository.getAllAdmins();
    if (adminUids.isEmpty) return; // Không có admin nào

    // Tạo notification cho mỗi admin
    final notifications = adminUids.map((adminUid) {
      return Notification(
        id: '',
        type: NotificationType.appeal,
        fromUid: uid, // User bị ban (người kháng cáo)
        toUid: adminUid,
        appealId: appealId,
        read: false,
        createdAt: DateTime.now(),
        text: 'Có đơn kháng cáo mới',
      );
    }).toList();

    // Tạo tất cả notifications
    for (final notification in notifications) {
      await _repository.createNotification(notification);
    }
  }
}

