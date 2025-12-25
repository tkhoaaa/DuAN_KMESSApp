import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../admin/pages/admin_appeal_detail_page.dart';
import '../../admin/pages/admin_report_detail_page.dart';
import '../../auth/auth_repository.dart';
// import '../../chat/pages/chat_detail_page.dart';
import '../../posts/pages/post_permalink_page.dart';
import '../../profile/public_profile_page.dart';
import '../../profile/user_profile_repository.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
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
      case models.NotificationType.commentReaction:
      case models.NotificationType.save:
      case models.NotificationType.share:
      case models.NotificationType.replyComment:
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
      case models.NotificationType.call:
        // Không còn navigate đối với notification tin nhắn/cuộc gọi
        break;
      case models.NotificationType.report:
        // Navigate đến report detail page
        if (notification.reportId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AdminReportDetailPage(
                reportId: notification.reportId!,
              ),
            ),
          );
        } else if (notification.targetUid != null) {
          // Nếu không có reportId, navigate đến profile của user bị report
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PublicProfilePage(uid: notification.targetUid!),
            ),
          );
        }
        break;
      case models.NotificationType.appeal:
        // Navigate đến appeal detail page
        if (notification.appealId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AdminAppealDetailPage(
                appealId: notification.appealId!,
              ),
            ),
          );
        }
        break;
      case models.NotificationType.storyLike:
        // Có thể mở Story viewer trong tương lai, tạm thời không navigate
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
        case models.NotificationType.commentReaction:
        case models.NotificationType.message:
        case models.NotificationType.call:
        case models.NotificationType.report:
        case models.NotificationType.appeal:
        case models.NotificationType.storyLike:
        case models.NotificationType.save:
        case models.NotificationType.share:
        case models.NotificationType.replyComment:
          // Các loại này hiện không group
          break;
      }
    }

    // Notification đơn lẻ hoặc count = 1
    switch (notification.type) {
      case models.NotificationType.like:
        return 'Đã thích bài đăng của bạn';
      case models.NotificationType.comment:
        return 'Đã bình luận bài đăng của bạn';
      case models.NotificationType.commentReaction:
        final reactionEmoji = notification.text ?? '👍';
        return 'Đã thả reaction $reactionEmoji vào bình luận của bạn';
      case models.NotificationType.replyComment:
        return 'Đã trả lời bình luận của bạn';
      case models.NotificationType.follow:
        return 'Đã theo dõi bạn';
      case models.NotificationType.message:
        return 'Đã gửi tin nhắn';
      case models.NotificationType.call:
        return notification.text ?? 'Cuộc gọi đến';
      case models.NotificationType.report:
        return 'Có báo cáo mới';
      case models.NotificationType.appeal:
        return 'Có đơn kháng cáo mới';
      case models.NotificationType.storyLike:
        return 'Đã tim tin của bạn';
      case models.NotificationType.save:
        return 'Đã lưu bài đăng của bạn';
      case models.NotificationType.share:
        return 'Đã chia sẻ bài đăng của bạn';
    }
  }

  IconData _getNotificationIcon(models.Notification notification) {
    switch (notification.type) {
      case models.NotificationType.like:
        return Icons.favorite;
      case models.NotificationType.comment:
        return Icons.comment;
      case models.NotificationType.commentReaction:
        return Icons.emoji_emotions;
      case models.NotificationType.replyComment:
        return Icons.reply;
      case models.NotificationType.follow:
        return Icons.person_add;
      case models.NotificationType.message:
        return Icons.chat;
      case models.NotificationType.call:
        return Icons.phone;
      case models.NotificationType.report:
        return Icons.report;
      case models.NotificationType.appeal:
        return Icons.gavel;
      case models.NotificationType.storyLike:
        return Icons.favorite;
      case models.NotificationType.save:
        return Icons.bookmark;
      case models.NotificationType.share:
        return Icons.share;
    }
  }

  Color _getNotificationColor(models.Notification notification) {
    // Dùng tông hồng nhất quán
    return AppColors.primaryPink;
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
        title: Text(
          'Thông báo',
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryPink,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize, color: AppColors.primaryPink),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _NotificationTile(
                  notification: notification,
                  onTap: () => _handleNotificationTap(notification),
                  getTitle: _getNotificationTitle,
                  getIcon: _getNotificationIcon,
                  getColor: _getNotificationColor,
                ),
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

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderGrey),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: isGrouped && displayUids.isNotEmpty
            ? _buildGroupedAvatars(
                displayUids,
                remainingCount,
                getColor(notification),
              )
            : (notification.type == models.NotificationType.comment ||
                    notification.type == models.NotificationType.commentReaction ||
                    notification.type == models.NotificationType.like ||
                    notification.type == models.NotificationType.save ||
                    notification.type == models.NotificationType.share ||
                    notification.type == models.NotificationType.replyComment ||
                    notification.type == models.NotificationType.report ||
                    notification.type == models.NotificationType.appeal)
                ? _buildSingleAvatar(
                    notification.type == models.NotificationType.report || 
                    notification.type == models.NotificationType.appeal
                        ? (notification.targetUid ?? notification.fromUid)
                        : notification.fromUid,
                    getColor(notification),
                  )
                : CircleAvatar(
                    backgroundColor:
                        getColor(notification).withOpacity(0.15),
                    child: Icon(
                      getIcon(notification),
                      color: getColor(notification),
                    ),
                  ),
        title: (notification.type == models.NotificationType.like ||
                notification.type == models.NotificationType.save ||
                notification.type == models.NotificationType.share ||
                notification.type == models.NotificationType.replyComment ||
                notification.type == models.NotificationType.report ||
                notification.type == models.NotificationType.appeal)
            ? _buildTitleWithUserName(notification)
            : Text(
                getTitle(notification),
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
              ),
        subtitle: notification.text != null && notification.text!.isNotEmpty
            ? Text(
                notification.text!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(color: AppColors.textLight),
              )
            : null,
        trailing: notification.read
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primaryPink,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: onTap,
      ),
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

  Widget _buildSingleAvatar(String uid, Color color) {
    return StreamBuilder(
      stream: userProfileRepository.watchProfile(uid),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final photoUrl = profile?.photoUrl;
        return CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          backgroundImage:
              photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          child: (photoUrl == null || photoUrl.isEmpty)
              ? Icon(Icons.person, color: color)
              : null,
        );
      },
    );
  }

  Widget _buildTitleWithUserName(models.Notification notification) {
    // Xác định UID để lấy profile
    final targetUid = (notification.type == models.NotificationType.report || 
                       notification.type == models.NotificationType.appeal)
        ? (notification.targetUid ?? notification.fromUid)
        : notification.fromUid;
    
    return StreamBuilder(
      stream: userProfileRepository.watchProfile(targetUid),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final displayName = profile?.displayName?.isNotEmpty == true
            ? profile!.displayName!
            : (profile?.email?.isNotEmpty == true
                ? profile!.email!
                : targetUid);
        
        String actionText;
        switch (notification.type) {
          case models.NotificationType.like:
            actionText = 'đã thích bài đăng của bạn';
            break;
          case models.NotificationType.save:
            actionText = 'đã lưu bài đăng của bạn';
            break;
          case models.NotificationType.share:
            actionText = 'đã chia sẻ bài đăng của bạn';
            break;
          case models.NotificationType.replyComment:
            actionText = 'đã trả lời bình luận của bạn';
            break;
          case models.NotificationType.report:
            actionText = ' - Có báo cáo mới về người dùng';
            break;
          case models.NotificationType.appeal:
            actionText = ' - Có đơn kháng cáo mới';
            break;
          default:
            actionText = getTitle(notification);
        }
        
        return RichText(
          text: TextSpan(
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
            children: [
              TextSpan(
                text: displayName,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryPink,
                ),
              ),
              TextSpan(
                text: actionText,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

