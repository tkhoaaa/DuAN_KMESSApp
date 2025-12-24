import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../admin/pages/admin_appeal_detail_page.dart';
import '../../admin/pages/admin_report_detail_page.dart';
import '../../auth/auth_repository.dart';
// import '../../chat/pages/chat_detail_page.dart';
import '../../posts/models/post.dart';
import '../../posts/pages/post_permalink_page.dart';
// import '../../posts/repositories/post_repository.dart';
import '../../profile/public_profile_page.dart';
// import '../../profile/user_profile_repository.dart';
import '../models/notification.dart' as models;
import '../models/notification_digest.dart';
import '../repositories/notification_repository.dart';
import '../services/notification_digest_service.dart';

class NotificationDigestPage extends StatefulWidget {
  const NotificationDigestPage({super.key});

  @override
  State<NotificationDigestPage> createState() =>
      _NotificationDigestPageState();
}

class _NotificationDigestPageState extends State<NotificationDigestPage>
    with SingleTickerProviderStateMixin {
  final NotificationDigestService _digestService = NotificationDigestService();
  late TabController _tabController;
  String? _currentUid;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _currentUid = authRepository.currentUser()?.uid;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generateDigest(DigestPeriod period) async {
    if (_currentUid == null) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      if (period == DigestPeriod.daily) {
        await _digestService.generateDailyDigest(
          uid: _currentUid!,
          date: DateTime.now(),
        );
      } else {
        await _digestService.generateWeeklyDigest(
          uid: _currentUid!,
          weekStart: DateTime.now(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tạo tổng kết thành công'),
            duration: Duration(seconds: 2),
          ),
        );
        // StreamBuilder sẽ tự động update khi có document mới
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
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
        title: const Text('Tổng kết'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Hôm nay'),
            Tab(text: 'Tuần này'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DigestTab(
            uid: _currentUid!,
            period: DigestPeriod.daily,
            digestService: _digestService,
            isGenerating: _isGenerating,
            onGenerate: () => _generateDigest(DigestPeriod.daily),
          ),
          _DigestTab(
            uid: _currentUid!,
            period: DigestPeriod.weekly,
            digestService: _digestService,
            isGenerating: _isGenerating,
            onGenerate: () => _generateDigest(DigestPeriod.weekly),
          ),
        ],
      ),
    );
  }
}

class _DigestTab extends StatelessWidget {
  const _DigestTab({
    required this.uid,
    required this.period,
    required this.digestService,
    required this.isGenerating,
    required this.onGenerate,
  });

  final String uid;
  final DigestPeriod period;
  final NotificationDigestService digestService;
  final bool isGenerating;
  final Future<void> Function() onGenerate;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NotificationDigest>>(
      stream: digestService.watchDigests(
        uid: uid,
        period: period,
        limit: 1,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final digests = snapshot.data ?? [];
        final digest = digests.isNotEmpty ? digests.first : null;

        if (digest == null) {
          return SingleChildScrollView(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.summarize_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      period == DigestPeriod.daily
                          ? 'Chưa có tổng kết hôm nay'
                          : 'Chưa có tổng kết tuần này',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: isGenerating ? null : onGenerate,
                      icon: isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: const Text('Tạo tổng kết'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await onGenerate();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _DigestHeader(
                  digest: digest,
                  period: period,
                ),
                const SizedBox(height: 24),
                // Stats Cards
                _StatsGrid(
                  stats: digest.stats,
                  digest: digest,
                ),
                const SizedBox(height: 24),
                // Top Posts
                if (digest.topPosts.isNotEmpty) ...[
                  const Text(
                    'Bài viết nổi bật',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TopPostsList(postIds: digest.topPosts),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DigestHeader extends StatelessWidget {
  const _DigestHeader({
    required this.digest,
    required this.period,
  });

  final NotificationDigest digest;
  final DigestPeriod period;

  String _getPeriodText() {
    if (period == DigestPeriod.daily) {
      return 'Hôm nay';
    } else {
      return 'Tuần này';
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = digest.stats.totalInteractions;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getPeriodText(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn có $total tương tác mới',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.stats,
    required this.digest,
  });

  final DigestStats stats;
  final NotificationDigest digest;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.0, // Giảm vì chỉ còn số lượng, không cần nhiều không gian
      children: [
        _StatCard(
          icon: Icons.favorite,
          label: 'Lượt thích',
          value: stats.likesCount,
          color: Colors.red,
          notificationType: models.NotificationType.like,
          digest: digest,
        ),
        _StatCard(
          icon: Icons.comment,
          label: 'Bình luận',
          value: stats.commentsCount,
          color: Colors.blue,
          notificationType: models.NotificationType.comment,
          digest: digest,
        ),
        _StatCard(
          icon: Icons.person_add,
          label: 'Người theo dõi',
          value: stats.followsCount,
          color: Colors.green,
          notificationType: models.NotificationType.follow,
          digest: digest,
        ),
        // Bỏ card Messages - không tổng kết tin nhắn nữa
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.notificationType,
    required this.digest,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final models.NotificationType notificationType;
  final NotificationDigest digest;

  void _showNotificationDetails(BuildContext context) async {
    if (value == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không có $label trong khoảng thời gian này')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _NotificationDetailsModal(
        notificationType: notificationType,
        digest: digest,
        label: label,
        color: color,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showNotificationDetails(context),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopPostsList extends StatelessWidget {
  const _TopPostsList({required this.postIds});

  final List<String> postIds;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: postIds.length,
      itemBuilder: (context, index) {
        final postId = postIds[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.article),
            title: Text('Bài viết #${index + 1}'),
            subtitle: const Text('Nhiều tương tác nhất'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PostPermalinkPage(postId: postId),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _NotificationDetailsModal extends StatefulWidget {
  const _NotificationDetailsModal({
    required this.notificationType,
    required this.digest,
    required this.label,
    required this.color,
    required this.icon,
  });

  final models.NotificationType notificationType;
  final NotificationDigest digest;
  final String label;
  final Color color;
  final IconData icon;

  @override
  State<_NotificationDetailsModal> createState() =>
      _NotificationDetailsModalState();
}

// Model để lưu thông tin post với số comments mới
class PostCommentSummary {
  PostCommentSummary({
    required this.postId,
    required this.commentsCount,
    this.post,
  });

  final String postId;
  final int commentsCount;
  final Post? post; // Post details (có thể null nếu post đã bị xóa)
}

class _NotificationDetailsModalState extends State<_NotificationDetailsModal> {
  final NotificationRepository _notificationRepository =
      NotificationRepository();
  final NotificationDigestService _digestService = NotificationDigestService();
  
  // Helper để access _posts collection
  CollectionReference<Map<String, dynamic>> get _posts =>
      FirebaseFirestore.instance.collection('posts');
  
  List<models.Notification> _notifications = [];
  List<PostCommentSummary> _postCommentSummaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final allNotifications = await _notificationRepository
          .fetchNotificationsInRange(
        uid: widget.digest.uid,
        startDate: widget.digest.startDate,
        endDate: widget.digest.endDate,
      );

      // Nếu là comments, nhóm theo postId
      if (widget.notificationType == models.NotificationType.comment) {
        final commentsByPost = _digestService.aggregateCommentsByPost(
          allNotifications,
        );

        // Fetch post details cho mỗi postId
        final summaries = <PostCommentSummary>[];
        for (final entry in commentsByPost.entries) {
          try {
            // Fetch post document trực tiếp từ Firestore
            final postDoc = await _posts.doc(entry.key).get();
            Post? post;
            if (postDoc.exists) {
              post = Post.fromDoc(postDoc);
            }
            summaries.add(
              PostCommentSummary(
                postId: entry.key,
                commentsCount: entry.value,
                post: post,
              ),
            );
          } catch (e) {
            // Nếu post không tồn tại hoặc lỗi, vẫn thêm vào list nhưng post = null
            summaries.add(
              PostCommentSummary(
                postId: entry.key,
                commentsCount: entry.value,
                post: null,
              ),
            );
          }
        }

        setState(() {
          _postCommentSummaries = summaries;
          _isLoading = false;
        });
      } else {
        // Các loại khác (like, follow) giữ nguyên logic cũ
        setState(() {
          _notifications = allNotifications
              .where((n) => n.type == widget.notificationType)
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    }
  }

  String _getNotificationTitle(models.Notification notification) {
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
          // Không group các loại này trong digest
          break;
      }
    }

    switch (notification.type) {
      case models.NotificationType.like:
        return 'Đã thích bài đăng của bạn';
      case models.NotificationType.comment:
        return 'Đã bình luận bài đăng của bạn';
      case models.NotificationType.commentReaction:
        final reactionEmoji = notification.text ?? '👍';
        return 'Đã thả reaction $reactionEmoji vào bình luận của bạn';
      case models.NotificationType.follow:
        return 'Đã theo dõi bạn';
      case models.NotificationType.message:
        return 'Đã gửi tin nhắn';
      case models.NotificationType.call:
        return 'Cuộc gọi đến';
      case models.NotificationType.report:
        return 'Có báo cáo mới';
      case models.NotificationType.appeal:
        return 'Có đơn kháng cáo mới';
      case models.NotificationType.storyLike:
        return 'Đã tim tin của bạn';
    }
  }

  Widget _buildContent(ScrollController scrollController) {
    // Nếu là comments, hiển thị theo posts
    if (widget.notificationType == models.NotificationType.comment) {
      if (_postCommentSummaries.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 64,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Không có bình luận mới',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        controller: scrollController,
        itemCount: _postCommentSummaries.length,
        itemBuilder: (context, index) {
          final summary = _postCommentSummaries[index];
          return _buildPostCommentItem(summary);
        },
      );
    }

    // Các loại khác (like, follow) hiển thị từng notification
    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Không có thông báo',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: widget.color.withOpacity(0.1),
            child: Icon(
              widget.icon,
              color: widget.color,
              size: 20,
            ),
          ),
          title: Text(_getNotificationTitle(notification)),
          subtitle: notification.text != null
              ? Text(
                  notification.text!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: notification.createdAt != null
              ? Text(
                  _formatTime(notification.createdAt!),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                )
              : null,
          onTap: () => _handleNotificationTap(notification),
        );
      },
    );
  }

  Widget _buildPostCommentItem(PostCommentSummary summary) {
    final post = summary.post;
    final hasPost = post != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: hasPost && post.media.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.media.first.url,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
                ),
              )
            : Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.article,
                  color: widget.color,
                ),
              ),
        title: Text(
          hasPost
              ? (post.caption.isNotEmpty
                  ? post.caption.length > 50
                      ? '${post.caption.substring(0, 50)}...'
                      : post.caption
                  : 'Bài viết')
              : 'Bài viết đã bị xóa',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: hasPost ? null : Colors.grey,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${summary.commentsCount} bình luận mới',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: hasPost
            ? () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PostPermalinkPage(postId: summary.postId),
                  ),
                );
              }
            : null,
      ),
    );
  }

  void _handleNotificationTap(models.Notification notification) {
    Navigator.of(context).pop(); // Đóng modal trước

    switch (notification.type) {
      case models.NotificationType.like:
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
        // Không còn navigate với message trong digest
        break;
      case models.NotificationType.comment:
        // Không cần xử lý vì đã xử lý trong _buildPostCommentItem
        break;
      case models.NotificationType.commentReaction:
        if (notification.postId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostPermalinkPage(postId: notification.postId!),
            ),
          );
        }
        break;
      case models.NotificationType.call:
        // Không cần navigation
        break;
      case models.NotificationType.report:
        if (notification.reportId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  AdminReportDetailPage(reportId: notification.reportId!),
            ),
          );
        } else if (notification.targetUid != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PublicProfilePage(uid: notification.targetUid!),
            ),
          );
        }
        break;
      case models.NotificationType.appeal:
        if (notification.appealId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  AdminAppealDetailPage(appealId: notification.appealId!),
            ),
          );
        }
        break;
      case models.NotificationType.storyLike:
        // Sau này có thể mở viewer story; hiện tại chỉ đóng modal
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(widget.icon, color: widget.color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.label,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.notificationType == models.NotificationType.comment
                                ? '${_postCommentSummaries.length} bài viết'
                                : '${_notifications.length} thông báo',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildContent(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} ngày trước';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }
}

