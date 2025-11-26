import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../chat/pages/chat_detail_page.dart';
import '../../chat/repositories/chat_repository.dart';
import '../../posts/pages/post_feed_page.dart';
import '../../profile/public_profile_page.dart';
import '../models/notification.dart' as models;
import '../services/notification_service.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  final NotificationService _notificationService = NotificationService();
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _currentUid = authRepository.currentUser()?.uid;
    // Đánh dấu tất cả notifications là đã đọc khi mở page
    if (_currentUid != null) {
      _notificationService.markAllAsRead(_currentUid!);
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
              builder: (_) => const PostFeedPage(),
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
    }
  }

  String _getNotificationTitle(models.Notification notification) {
    switch (notification.type) {
      case models.NotificationType.like:
        return 'Đã thích bài đăng của bạn';
      case models.NotificationType.comment:
        return 'Đã bình luận bài đăng của bạn';
      case models.NotificationType.follow:
        return 'Đã theo dõi bạn';
      case models.NotificationType.message:
        return 'Đã gửi tin nhắn';
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
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getNotificationColor(notification)
                      .withOpacity(0.2),
                  child: Icon(
                    _getNotificationIcon(notification),
                    color: _getNotificationColor(notification),
                  ),
                ),
                title: Text(_getNotificationTitle(notification)),
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
                onTap: () => _handleNotificationTap(notification),
              );
            },
          );
        },
      ),
    );
  }
}

