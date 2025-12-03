import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../chat/pages/chat_detail_page.dart';
import '../../chat/repositories/chat_repository.dart';
import '../../posts/pages/post_feed_page.dart';
import '../../posts/pages/post_permalink_page.dart';
import '../../profile/public_profile_page.dart';
import '../../profile/user_profile_repository.dart';
import '../models/notification.dart' as models;
import '../services/notification_service.dart';
import '../services/notification_digest_service.dart';
import 'notification_digest_page.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  final NotificationService _notificationService = NotificationService();
  final NotificationDigestService _digestService = NotificationDigestService();
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _currentUid = authRepository.currentUser()?.uid;
    // Đánh dấu tất cả notifications là đã đọc khi mở page
    if (_currentUid != null) {
      _notificationService.markAllAsRead(_currentUid!);
      // Auto-generate daily digest nếu chưa có (lazy generation)
      _generateDailyDigestIfNeeded();
    }
  }

  Future<void> _generateDailyDigestIfNeeded() async {
    if (_currentUid == null) return;
    try {
      await _digestService.generateDailyDigest(
        uid: _currentUid!,
        date: DateTime.now(),
      );
    } catch (e) {
      // Silent fail - không ảnh hưởng UX
      debugPrint('Error generating daily digest: $e');
    }
  }

  Future<void> _handleNotificationTap(models.Notification notification) async {
    if (_currentUid == null) return;

    // Đánh dấu notification là đã đọc
    await _notificationService.markAsRead(notification.id);

    // Navigate đến đúng page dựa trên type
    if (!mounted) return;

    switch (notification.type) {
      case models.NotificationType.like:
      case models.NotificationType.comment:
        if (notification.postId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostPermalinkPage(postId: notification.postId!),
            ),
          );
        }
        break;
      case models.NotificationType.follow:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PublicProfilePage(uid: notification.fromUid),
          ),
        );
        break;
      case models.NotificationType.message:
        if (notification.conversationId != null) {
          final chatRepo = ChatRepository();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatDetailPage(
                conversationId: notification.conversationId!,
                otherUid: notification.fromUid,
              ),
            ),
          );
        }
        break;
      case models.NotificationType.call:
        // Call notifications được xử lý tự động bởi incoming call dialog
        // Không cần navigation
        break;
    }
  }

  String _getNotificationTitle(models.Notification notification) {
    // Nếu là grouped notification (count > 1)
    if (notification.count > 1) {
      switch (notification.type) {
        case models.NotificationType.like:
          return '${notification.count} người đã thích bài đăng của bạn';
        case models.NotificationType.follow:
          return '${notification.count} người đã theo dõi bạn';
        case models.NotificationType.comment:
        case models.NotificationType.message:
        case models.NotificationType.call:
          // Comments, messages và calls không group, nhưng vẫn check để an toàn
          break;
      }
    }

    // Notification đơn lẻ hoặc count = 1
    switch (notification.type) {
      case models.NotificationType.like:
        return 'Đã thích bài đăng của bạn';
      case models.NotificationType.comment:
        return 'Đã bình luận bài đăng của bạn';
      case models.NotificationType.follow:
        return 'Đã theo dõi bạn';
      case models.NotificationType.message:
        return 'Đã gửi tin nhắn';
      case models.NotificationType.call:
        return notification.text ?? 'Cuộc gọi đến';
    }
  }

  IconData _getNotificationIcon(models.Notification notification) {
    switch (notification.type) {
      case models.NotificationType.like:
        return Icons.favorite;
      case models.NotificationType.comment:
        return Icons.comment;
      case models.NotificationType.follow:
        return Icons.person_add;
      case models.NotificationType.message:
        return Icons.chat;
      case models.NotificationType.call:
        return Icons.phone;
    }
  }

  Color _getNotificationColor(models.Notification notification) {
    switch (notification.type) {
      case models.NotificationType.like:
        return Colors.red;
      case models.NotificationType.comment:
        return Colors.blue;
      case models.NotificationType.follow:
        return Colors.green;
      case models.NotificationType.message:
        return Colors.purple;
      case models.NotificationType.call:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUid == null) {
      return const Scaffold(
        body: Center(child: Text('Bạn cần đăng nhập.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize),
            tooltip: 'Tổng kết',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationDigestPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<models.Notification>>(
        stream: _notificationService.watchNotifications(_currentUid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return const Center(
              child: Text('Chưa có thông báo nào.'),
            );
          }
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(
                notification: notification,
                onTap: () => _handleNotificationTap(notification),
                getTitle: _getNotificationTitle,
                getIcon: _getNotificationIcon,
                getColor: _getNotificationColor,
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.getTitle,
    required this.getIcon,
    required this.getColor,
  });

  final models.Notification notification;
  final VoidCallback onTap;
  final String Function(models.Notification) getTitle;
  final IconData Function(models.Notification) getIcon;
  final Color Function(models.Notification) getColor;

  @override
  Widget build(BuildContext context) {
    final isGrouped = notification.count > 1 && notification.fromUids != null;
    final fromUids = notification.fromUids ?? [];
    final displayUids = fromUids.take(3).toList();
    final remainingCount = fromUids.length > 3 ? fromUids.length - 3 : 0;

    return ListTile(
      leading: isGrouped && displayUids.isNotEmpty
          ? _buildGroupedAvatars(displayUids, remainingCount, getColor(notification))
          : CircleAvatar(
              backgroundColor: getColor(notification).withOpacity(0.2),
              child: Icon(
                getIcon(notification),
                color: getColor(notification),
              ),
            ),
      title: Text(getTitle(notification)),
      subtitle: notification.text != null && notification.text!.isNotEmpty
          ? Text(
              notification.text!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: notification.read
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
      onTap: onTap,
    );
  }

  Widget _buildGroupedAvatars(
    List<String> uids,
    int remainingCount,
    Color color,
  ) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          // Hiển thị tối đa 3 avatars
          for (int i = 0; i < uids.length && i < 3; i++)
            Positioned(
              left: i * 12.0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  color: color.withOpacity(0.2),
                ),
                child: StreamBuilder(
                  stream: userProfileRepository.watchProfile(uids[i]),
                  builder: (context, snapshot) {
                    final profile = snapshot.data;
                    final photoUrl = profile?.photoUrl;
                    return photoUrl != null && photoUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.person,
                                size: 16,
                                color: color,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.person,
                            size: 16,
                            color: color,
                          );
                  },
                ),
              ),
            ),
          // Hiển thị "+X" nếu còn nhiều người
          if (remainingCount > 0)
            Positioned(
              left: 36.0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.3),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$remainingCount',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

