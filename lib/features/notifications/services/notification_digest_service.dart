import '../models/notification.dart';
import '../models/notification_digest.dart';
import '../repositories/notification_digest_repository.dart';
import '../repositories/notification_repository.dart';

class NotificationDigestService {
  NotificationDigestService({
    NotificationDigestRepository? digestRepository,
    NotificationRepository? notificationRepository,
  })  : _digestRepository =
            digestRepository ?? NotificationDigestRepository(),
        _notificationRepository =
            notificationRepository ?? NotificationRepository();

  final NotificationDigestRepository _digestRepository;
  final NotificationRepository _notificationRepository;

  /// Generate daily digest cho một ngày cụ thể
  Future<NotificationDigest> generateDailyDigest({
    required String uid,
    required DateTime date,
  }) async {
    // Kiểm tra xem đã có digest cho ngày này chưa
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(
          const Duration(milliseconds: 1),
        );

    final existingDigest = await _digestRepository.findDigestForPeriod(
      uid: uid,
      period: DigestPeriod.daily,
      startDate: startOfDay,
    );

    if (existingDigest != null) {
      return existingDigest;
    }

    // Query notifications trong ngày
    final notifications = await _notificationRepository.fetchNotificationsInRange(
      uid: uid,
      startDate: startOfDay,
      endDate: endOfDay,
    );

    // Aggregate stats
    final stats = _aggregateStats(notifications);

    // Tìm top posts (posts có nhiều likes + comments nhất)
    final topPosts = _findTopPosts(notifications);

    // Tạo digest
    final digest = NotificationDigest(
      id: '', // Sẽ được tạo bởi Firestore
      uid: uid,
      period: DigestPeriod.daily,
      startDate: startOfDay,
      endDate: endOfDay,
      stats: stats,
      topPosts: topPosts,
      createdAt: DateTime.now(),
    );

    final digestId = await _digestRepository.createDigest(digest);
    return NotificationDigest(
      id: digestId,
      uid: digest.uid,
      period: digest.period,
      startDate: digest.startDate,
      endDate: digest.endDate,
      stats: digest.stats,
      topPosts: digest.topPosts,
      createdAt: digest.createdAt,
    );
  }

  /// Generate weekly digest cho một tuần cụ thể
  Future<NotificationDigest> generateWeeklyDigest({
    required String uid,
    required DateTime weekStart,
  }) async {
    // Tính toán start và end của tuần (Monday to Sunday)
    final startOfWeek = _getStartOfWeek(weekStart);
    final endOfWeek = startOfWeek.add(const Duration(days: 7)).subtract(
          const Duration(milliseconds: 1),
        );

    // Kiểm tra xem đã có digest cho tuần này chưa
    final existingDigest = await _digestRepository.findDigestForPeriod(
      uid: uid,
      period: DigestPeriod.weekly,
      startDate: startOfWeek,
    );

    if (existingDigest != null) {
      return existingDigest;
    }

    // Query notifications trong tuần
    final notifications = await _notificationRepository.fetchNotificationsInRange(
      uid: uid,
      startDate: startOfWeek,
      endDate: endOfWeek,
    );

    // Aggregate stats
    final stats = _aggregateStats(notifications);

    // Tìm top posts
    final topPosts = _findTopPosts(notifications);

    // Tạo digest
    final digest = NotificationDigest(
      id: '',
      uid: uid,
      period: DigestPeriod.weekly,
      startDate: startOfWeek,
      endDate: endOfWeek,
      stats: stats,
      topPosts: topPosts,
      createdAt: DateTime.now(),
    );

    final digestId = await _digestRepository.createDigest(digest);
    return NotificationDigest(
      id: digestId,
      uid: digest.uid,
      period: digest.period,
      startDate: digest.startDate,
      endDate: digest.endDate,
      stats: digest.stats,
      topPosts: digest.topPosts,
      createdAt: digest.createdAt,
    );
  }

  /// Aggregate stats từ notifications
  /// Lưu ý: Không tính messagesCount (bỏ tổng kết tin nhắn)
  DigestStats _aggregateStats(List<Notification> notifications) {
    int likesCount = 0;
    int commentsCount = 0;
    int followsCount = 0;
    // messagesCount không được tính nữa

    for (final notification in notifications) {
      // Nếu là grouped notification, dùng count
      final count = notification.count;

      switch (notification.type) {
        case NotificationType.like:
          likesCount += count;
          break;
        case NotificationType.comment:
          commentsCount += count;
          break;
        case NotificationType.follow:
          followsCount += count;
          break;
        case NotificationType.message:
        case NotificationType.call:
          // Bỏ qua messages và calls - không tính vào stats
          break;
      }
    }

    return DigestStats(
      likesCount: likesCount,
      commentsCount: commentsCount,
      followsCount: followsCount,
      messagesCount: 0, // Luôn set = 0 vì không tính nữa
    );
  }

  /// Nhóm comments theo postId và đếm số lượng comments mới cho mỗi post
  /// Trả về Map<postId, commentsCount>
  Map<String, int> aggregateCommentsByPost(List<Notification> notifications) {
    final commentsByPost = <String, int>{};

    for (final notification in notifications) {
      if (notification.type != NotificationType.comment) continue;
      if (notification.postId == null) continue;

      final postId = notification.postId!;
      final count = notification.count;

      commentsByPost[postId] = (commentsByPost[postId] ?? 0) + count;
    }

    return commentsByPost;
  }

  /// Tìm top 5 posts có nhiều tương tác nhất
  List<String> _findTopPosts(List<Notification> notifications) {
    // Map postId -> số lượng tương tác (likes + comments)
    final postInteractions = <String, int>{};

    for (final notification in notifications) {
      if (notification.postId == null) continue;

      final postId = notification.postId!;
      final count = notification.count;

      if (notification.type == NotificationType.like ||
          notification.type == NotificationType.comment) {
        postInteractions[postId] = (postInteractions[postId] ?? 0) + count;
      }
    }

    // Sort theo số lượng tương tác và lấy top 5
    final sortedPosts = postInteractions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedPosts.take(5).map((e) => e.key).toList();
  }

  /// Lấy start of week (Monday)
  DateTime _getStartOfWeek(DateTime date) {
    final weekday = date.weekday; // 1 = Monday, 7 = Sunday
    final daysFromMonday = weekday - 1;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: daysFromMonday));
  }

  /// Watch digests của user
  Stream<List<NotificationDigest>> watchDigests({
    required String uid,
    DigestPeriod? period,
    int limit = 10,
  }) {
    return _digestRepository.watchDigests(
      uid: uid,
      period: period,
      limit: limit,
    );
  }

  /// Fetch digests của user
  Future<List<NotificationDigest>> fetchDigests({
    required String uid,
    DigestPeriod? period,
    int limit = 10,
  }) async {
    return _digestRepository.fetchDigests(
      uid: uid,
      period: period,
      limit: limit,
    );
  }
}

