import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../auth/auth_repository.dart';
import '../models/draft_post.dart';
import '../models/post.dart';
import '../models/post_media.dart';
import '../repositories/draft_post_repository.dart';
import '../repositories/post_repository.dart';
import '../services/post_service.dart';
import 'post_create_page.dart';
import 'post_permalink_page.dart';

class DraftsAndScheduledPage extends StatefulWidget {
  const DraftsAndScheduledPage({super.key});

  @override
  State<DraftsAndScheduledPage> createState() => _DraftsAndScheduledPageState();
}

class _DraftsAndScheduledPageState extends State<DraftsAndScheduledPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final DraftPostRepository _draftRepository = DraftPostRepository();
  final PostRepository _postRepository = PostRepository();
  final PostService _postService = PostService();

  List<DraftPost> _drafts = [];
  List<Post> _scheduledPosts = [];
  bool _isLoadingDrafts = false;
  bool _isLoadingScheduled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDrafts();
    _loadScheduledPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDrafts() async {
    final uid = authRepository.currentUser()?.uid;
    if (uid == null) return;

    setState(() {
      _isLoadingDrafts = true;
    });

    try {
      final drafts = await _draftRepository.fetchDrafts(uid: uid, limit: 50);
      if (mounted) {
        setState(() {
          _drafts = drafts;
          _isLoadingDrafts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDrafts = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải bài nháp: $e')),
        );
      }
    }
  }

  Future<void> _loadScheduledPosts() async {
    final uid = authRepository.currentUser()?.uid;
    if (uid == null) return;

    setState(() {
      _isLoadingScheduled = true;
    });

    try {
      final posts = await _postRepository.fetchScheduledPosts(
        authorUid: uid,
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _scheduledPosts = posts;
          _isLoadingScheduled = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingScheduled = false;
        });
        
        // Hiển thị error message chi tiết hơn
        String errorMessage = 'Lỗi tải bài hẹn giờ: $e';
        if (e.toString().contains('failed-precondition') || 
            e.toString().contains('index')) {
          errorMessage = 'Đang tạo index cho truy vấn. Vui lòng đợi vài phút rồi thử lại.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _deleteDraft(String draftId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bài nháp'),
        content: const Text('Bạn có chắc muốn xóa bài nháp này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _postService.deleteDraft(draftId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa bài nháp')),
        );
        _loadDrafts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa bài nháp: $e')),
        );
      }
    }
  }

  Future<void> _continueEditingDraft(DraftPost draft) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostCreatePage(draftId: draft.id),
      ),
    );
    if (result == true && mounted) {
      _loadDrafts();
    }
  }

  Future<void> _cancelScheduledPost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy lên lịch'),
        content: const Text('Bạn có chắc muốn hủy lên lịch bài viết này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xác nhận', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _postRepository.cancelScheduledPost(postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã hủy lên lịch')),
        );
        _loadScheduledPosts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi hủy lên lịch: $e')),
        );
      }
    }
  }

  Future<void> _publishNow(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng ngay'),
        content: const Text('Bạn có muốn đăng bài viết này ngay bây giờ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Đăng ngay'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final uid = authRepository.currentUser()?.uid;
      if (uid == null) return;

      await _postRepository.publishScheduledPost(
        postId: post.id,
        authorUid: uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã đăng bài viết')),
        );
        _loadScheduledPosts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi đăng bài: $e')),
        );
      }
    }
  }

  Future<void> _updateScheduledTime(Post post) async {
    final now = DateTime.now();
    final initialDate = post.scheduledAt ?? now.add(const Duration(days: 1));
    
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: post.scheduledAt != null
          ? TimeOfDay.fromDateTime(post.scheduledAt!)
          : TimeOfDay.now(),
    );
    if (pickedTime == null) return;

    final newScheduledAt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (newScheduledAt.isBefore(now)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thời gian hẹn đăng phải trong tương lai.')),
      );
      return;
    }

    try {
      await _postRepository.updateScheduledTime(
        postId: post.id,
        newScheduledAt: newScheduledAt,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật thời gian hẹn đăng: ${DateFormat('dd/MM/yyyy HH:mm').format(newScheduledAt)}'),
          ),
        );
        _loadScheduledPosts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật thời gian: $e')),
        );
      }
    }
  }

  /// Chỉ chỉnh giờ đăng bài (giữ nguyên ngày)
  Future<void> _updateScheduledTimeOnly(Post post) async {
    if (post.scheduledAt == null) {
      // Nếu chưa có scheduledAt, dùng method chỉnh cả ngày và giờ
      return _updateScheduledTime(post);
    }

    final now = DateTime.now();
    final currentScheduled = post.scheduledAt!;
    
    // Chỉ hiển thị TimePicker, giữ nguyên ngày
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentScheduled),
    );
    if (pickedTime == null) return;

    // Giữ nguyên ngày, chỉ cập nhật giờ
    final newScheduledAt = DateTime(
      currentScheduled.year,
      currentScheduled.month,
      currentScheduled.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // Kiểm tra nếu thời gian mới vẫn trong tương lai
    if (newScheduledAt.isBefore(now)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thời gian hẹn đăng phải trong tương lai.')),
      );
      return;
    }

    try {
      await _postRepository.updateScheduledTime(
        postId: post.id,
        newScheduledAt: newScheduledAt,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật giờ đăng: ${DateFormat('HH:mm').format(newScheduledAt)}'),
          ),
        );
        _loadScheduledPosts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật giờ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bài nháp & Bài hẹn giờ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Bài nháp'),
            Tab(text: 'Bài hẹn giờ'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_tabController.index == 0) {
                _loadDrafts();
              } else {
                _loadScheduledPosts();
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDraftsTab(),
          _buildScheduledTab(),
        ],
      ),
    );
  }

  Widget _buildDraftsTab() {
    if (_isLoadingDrafts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_drafts.isEmpty) {
      return const Center(
        child: Text('Chưa có bài nháp nào'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _drafts.length,
      itemBuilder: (context, index) {
        final draft = _drafts[index];
        return _DraftCard(
          draft: draft,
          onTap: () => _continueEditingDraft(draft),
          onDelete: () => _deleteDraft(draft.id),
        );
      },
    );
  }

  Widget _buildScheduledTab() {
    if (_isLoadingScheduled) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_scheduledPosts.isEmpty) {
      return const Center(
        child: Text('Chưa có bài viết nào được lên lịch'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _scheduledPosts.length,
      itemBuilder: (context, index) {
        final post = _scheduledPosts[index];
        return _ScheduledPostCard(
          post: post,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PostPermalinkPage(postId: post.id),
              ),
            );
          },
          onCancel: () => _cancelScheduledPost(post.id),
          onUpdateTime: () => _updateScheduledTime(post),
          onUpdateTimeOnly: () => _updateScheduledTimeOnly(post),
          onPublishNow: () => _publishNow(post),
        );
      },
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    required this.onTap,
    required this.onDelete,
  });

  final DraftPost draft;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              if (draft.media.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    draft.media.first.url,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image),
                    ),
                  ),
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description),
                ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (draft.caption?.isNotEmpty == true)
                      Text(
                        draft.caption!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      )
                    else
                      const Text(
                        'Bài nháp không có caption',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Lưu lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(draft.updatedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Xóa', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'delete') {
                    onDelete();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduledPostCard extends StatelessWidget {
  const _ScheduledPostCard({
    required this.post,
    required this.onTap,
    required this.onCancel,
    required this.onUpdateTime,
    required this.onUpdateTimeOnly,
    required this.onPublishNow,
  });

  final Post post;
  final VoidCallback onTap;
  final VoidCallback onCancel;
  final VoidCallback onUpdateTime;
  final VoidCallback onUpdateTimeOnly;
  final VoidCallback onPublishNow;

  @override
  Widget build(BuildContext context) {
    final scheduledAt = post.scheduledAt;
    final now = DateTime.now();
    final timeRemaining = scheduledAt != null
        ? scheduledAt.difference(now)
        : const Duration();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Đã lên lịch',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'publish',
                        child: Row(
                          children: [
                            Icon(Icons.publish, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Đăng ngay', style: TextStyle(color: Colors.green)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'updateTimeOnly',
                        child: Row(
                          children: [
                            Icon(Icons.access_time),
                            SizedBox(width: 8),
                            Text('Chỉnh giờ'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'update',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Chỉnh ngày và giờ'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'cancel',
                        child: Row(
                          children: [
                            Icon(Icons.cancel, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Hủy lên lịch',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'publish') {
                        onPublishNow();
                      } else if (value == 'updateTimeOnly') {
                        onUpdateTimeOnly();
                      } else if (value == 'update') {
                        onUpdateTime();
                      } else if (value == 'cancel') {
                        onCancel();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Post preview
              if (post.media.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    post.media.first.url,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 8),
              if (post.caption.isNotEmpty)
                Text(
                  post.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    scheduledAt != null
                        ? 'Sẽ đăng vào: ${DateFormat('dd/MM/yyyy HH:mm').format(scheduledAt)}'
                        : 'Chưa có thời gian',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (timeRemaining.inSeconds > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Còn ${_formatDuration(timeRemaining)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} ngày ${duration.inHours % 24} giờ';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} giờ ${duration.inMinutes % 60} phút';
    } else {
      return '${duration.inMinutes} phút';
    }
  }
}

