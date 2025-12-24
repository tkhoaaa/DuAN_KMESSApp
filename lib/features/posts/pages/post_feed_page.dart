import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/auth_repository.dart';
import '../../profile/public_profile_page.dart';
import '../../profile/user_profile_repository.dart';
import '../../saved_posts/services/saved_posts_service.dart';
import '../../safety/services/block_service.dart';
import '../../safety/services/report_service.dart';
import '../../stories/pages/story_create_page.dart';
import '../../stories/pages/story_archive_page.dart';
import '../../stories/pages/story_viewer_page.dart';
import '../../notifications/pages/notification_center_page.dart';
import '../../notifications/services/notification_service.dart';
import '../../profile/pages/manage_pinned_posts_page.dart';
import 'drafts_and_scheduled_page.dart';
import '../../stories/models/story.dart';
import '../../stories/repositories/story_repository.dart';
import '../../follow/services/follow_service.dart';
import '../../share/services/share_service.dart';
import '../models/post.dart';
import '../models/post_media.dart';
import '../models/feed_filters.dart';
import '../services/post_service.dart';
import '../widgets/post_caption_with_hashtags.dart';
import '../widgets/feed_filter_bottom_sheet.dart';
import '../widgets/feed_filter_chips.dart';
import 'post_comments_sheet.dart';
import 'post_create_page.dart';
import 'post_video_page.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';

enum _FeedMenuAction { filter, story, notifications, drafts, pinned, storyArchive }

class PostFeedPage extends StatefulWidget {
  const PostFeedPage({super.key});

  @override
  State<PostFeedPage> createState() => _PostFeedPageState();
}

class _PostFeedPageState extends State<PostFeedPage> {
  // Gộp các hành động AppBar vào một menu gọn
  static const _menuActions = [
    _FeedMenuAction.filter,
    _FeedMenuAction.story,
    _FeedMenuAction.notifications,
    _FeedMenuAction.drafts,
    _FeedMenuAction.pinned,
    _FeedMenuAction.storyArchive,
  ];

  final PostService _postService = PostService();
  final StoryRepository _storyRepository = StoryRepository();
  final NotificationService _notificationService = NotificationService();
  final List<PostFeedEntry> _entries = [];
  final ScrollController _scrollController = ScrollController();

  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _initialLoading = true;
  StreamSubscription<List<Post>>? _publishedPostsSubscription;
  StreamSubscription<int>? _unreadNotificationsSub;
  Set<String> _knownPostIds = {}; // Track posts đã load để tránh duplicate
  FeedFilters _filters = FeedFilters(); // Default filters
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
    // Listen cho posts mới được publish
    _listenForNewPublishedPosts();
    _listenUnreadNotifications();
  }

  @override
  void dispose() {
    _publishedPostsSubscription?.cancel();
    _unreadNotificationsSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Listen cho posts mới được publish (realtime)
  void _listenForNewPublishedPosts() {
    // Chỉ listen top 5 posts mới nhất để detect posts mới được publish
    _publishedPostsSubscription = _postService.watchPublishedPosts(limit: 5).listen(
      (newPosts) {
        if (!mounted) return;
        
        // Tìm posts mới (chưa có trong _knownPostIds)
        final newPostIds = newPosts
            .where((post) => !_knownPostIds.contains(post.id))
            .map((post) => post.id)
            .toList();
        
        if (newPostIds.isNotEmpty) {
          // Reload feed để hiển thị posts mới
          _loadInitial();
        }
        
        // Update known post IDs
        _knownPostIds.addAll(newPosts.map((p) => p.id));
      },
      onError: (error) {
        debugPrint('Error listening for published posts: $error');
      },
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoading &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _initialLoading = true;
      _entries.clear();
      _lastDoc = null;
      _hasMore = true;
      _knownPostIds.clear(); // Reset known post IDs khi reload
    });
    await _loadMore(reset: true);
    setState(() {
      _initialLoading = false;
    });
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final result = _filters.isDefault
          ? await _postService.fetchFeedPage(
              startAfter: reset ? null : _lastDoc,
              limit: 8,
            )
          : await _postService.fetchFeedPageWithFilters(
              filters: _filters,
              startAfter: reset ? null : _lastDoc,
              limit: 8,
            );
      setState(() {
        _entries.addAll(result.entries);
        _lastDoc = result.lastDoc;
        _hasMore = result.hasMore;
        // Update known post IDs
        _knownPostIds.addAll(result.entries.map((e) => e.doc.id));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải bài đăng: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleMenuAction(_FeedMenuAction action) {
    switch (action) {
      case _FeedMenuAction.filter:
        _openFilterSheet();
        break;
      case _FeedMenuAction.story:
        _openStoryCreator();
        break;
      case _FeedMenuAction.notifications:
        _openNotifications();
        break;
      case _FeedMenuAction.drafts:
        _openDraftsAndScheduled();
        break;
      case _FeedMenuAction.pinned:
        _openPinnedPosts();
        break;
      case _FeedMenuAction.storyArchive:
        _openStoryArchive();
        break;
    }
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FeedFilterBottomSheet(
        initialFilters: _filters,
        onApply: (filters) {
          setState(() {
            _filters = filters;
          });
          _loadInitial();
        },
      ),
    );
  }

  Future<void> _openStoryCreator() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StoryCreatePage()),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationCenterPage()),
    );
  }

  void _listenUnreadNotifications() {
    final uid = authRepository.currentUser()?.uid;
    _unreadNotificationsSub?.cancel();
    if (uid == null) return;
    _unreadNotificationsSub =
        _notificationService.watchUnreadCount(uid).listen((count) {
      if (!mounted) return;
      setState(() {
        _unreadNotifications = count;
      });
    });
  }

  Future<void> _openDraftsAndScheduled() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DraftsAndScheduledPage()),
    );
  }

  Future<void> _openPinnedPosts() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ManagePinnedPostsPage()),
    );
  }

  Future<void> _openStoryArchive() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StoryArchivePage()),
    );
  }

  IconData _menuIcon(_FeedMenuAction action) {
    switch (action) {
      case _FeedMenuAction.filter:
        return Icons.filter_list;
      case _FeedMenuAction.story:
        return Icons.history;
      case _FeedMenuAction.storyArchive:
        return Icons.archive_outlined;
      case _FeedMenuAction.notifications:
        return Icons.notifications_outlined;
      case _FeedMenuAction.drafts:
        return Icons.drafts;
      case _FeedMenuAction.pinned:
        return Icons.push_pin;
    }
  }

  String _menuLabel(_FeedMenuAction action) {
    switch (action) {
      case _FeedMenuAction.filter:
        return 'Lọc & sắp xếp';
      case _FeedMenuAction.story:
        return 'Tin của bạn';
      case _FeedMenuAction.storyArchive:
        return 'Kho lưu trữ Story';
      case _FeedMenuAction.notifications:
        return 'Thông báo';
      case _FeedMenuAction.drafts:
        return 'Bài nháp & hẹn giờ';
      case _FeedMenuAction.pinned:
        return 'Bài viết ghim';
    }
  }

  Widget _menuButtonIcon() {
    if (_unreadNotifications <= 0) {
      return const Icon(Icons.more_vert, color: AppColors.primaryPink);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.more_vert, color: AppColors.primaryPink),
        Positioned(
          right: -4,
          top: -2,
          child: _badge(_unreadNotifications),
        ),
      ],
    );
  }

  Widget _menuItem(_FeedMenuAction action) {
    final showBadge =
        action == _FeedMenuAction.notifications && _unreadNotifications > 0;
    final label = _menuLabel(action);
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(_menuIcon(action), color: AppColors.primaryPink),
            if (showBadge)
              Positioned(
                right: -4,
                top: -2,
                child: _badge(_unreadNotifications, dense: true),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Text(label),
              if (showBadge) ...[
                const SizedBox(width: 8),
                _badge(_unreadNotifications, dense: true),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _badge(int count, {bool dense = false}) {
    final display = count > 99 ? '99+' : '$count';
    final padding = dense
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.all(6);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.primaryPink,
        borderRadius: BorderRadius.circular(12),
      ),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      child: Text(
        display,
        style: AppTypography.small
            .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            height: 50,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: 5,
              itemBuilder: (context, index) => Container(
                width: 70,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade200,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 12,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade200,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 16,
                              width: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 12,
                              width: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        height: 24,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 24,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            childCount: 5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Bảng tin',
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryPink,
          ),
        ),
        actions: [
          PopupMenuButton<_FeedMenuAction>(
            icon: _menuButtonIcon(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            onSelected: _handleMenuAction,
            itemBuilder: (context) => _menuActions
                .map(
                  (action) => PopupMenuItem<_FeedMenuAction>(
                    value: action,
                    child: _menuItem(action),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const PostCreatePage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                );
              },
            ),
          );
          if (created == true) {
            _loadInitial();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Tạo bài viết'),
        backgroundColor: AppColors.primaryPink,
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
        color: AppColors.primaryPink,
        child: _initialLoading
            ? _buildShimmerLoading()
            : CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: FeedFilterChips(
                      filters: _filters,
                      onRemoveFilter: (filters) {
                        setState(() {
                          _filters = filters;
                        });
                        _loadInitial();
                      },
                      onTap: () {
                        _openFilterSheet();
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _StoriesBar(storyRepository: _storyRepository),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= _entries.length) {
                          if (_hasMore && _isLoading) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryPink,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }
                        final entry = _entries[index];
                        return _AnimatedPostItem(
                          key: ValueKey(entry.doc.id),
                          index: index,
                          entry: entry,
                          service: _postService,
                          onOpenProfile: (uid) {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    PublicProfilePage(uid: uid),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                              ),
                            );
                          },
                          onOpenComments: (post) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => PostCommentsSheet(post: post),
                            );
                          },
                          onPostDeleted: () {
                            _loadInitial();
                          },
                        );
                      },
                      childCount: _entries.length + (_hasMore ? 1 : 0),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 80),
                  ),
                ],
              ),
      ),
    );
  }
}

class PostFeedItem extends StatefulWidget {
  const PostFeedItem({
    super.key,
    required this.entry,
    required this.service,
    required this.onOpenProfile,
    required this.onOpenComments,
    this.onPostDeleted,
  });

  final PostFeedEntry entry;
  final PostService service;
  final void Function(String uid) onOpenProfile;
  final void Function(Post post) onOpenComments;
  final VoidCallback? onPostDeleted;

  @override
  State<PostFeedItem> createState() => _PostFeedItemState();
}

class _PostFeedItemState extends State<PostFeedItem> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final BlockService _blockService = blockService;
  final ReportService _reportService = reportService;
  final SavedPostsService _savedPostsService = savedPostsService;
  final UserProfileRepository _profileRepository = userProfileRepository;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = authRepository.currentUser()?.uid;
    return StreamBuilder<Post>(
      stream: widget.service.watchPost(widget.entry.doc.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final post = snapshot.data!;
        final author = widget.entry.author;
        final authorPhotoUrl = author?.photoUrl;
        final displayName = author?.displayName?.isNotEmpty == true
            ? author!.displayName!
            : (author?.email?.isNotEmpty == true
                ? author!.email!
                : post.authorUid);

        if (_currentPage >= (post.media.isNotEmpty ? post.media.length : 1)) {
          _currentPage = 0;
        }

        final isOwner = currentUid == post.authorUid;
        if (currentUid == null || isOwner) {
          return _buildPostCard(
            context: context,
            post: post,
            displayName: displayName,
            authorPhotoUrl: authorPhotoUrl,
            blockedByMe: false,
            blockedByAuthor: false,
            currentUid: currentUid,
          );
        }

        return StreamBuilder<bool>(
          stream: _blockService.watchIsBlocked(
            blockerUid: currentUid,
            blockedUid: post.authorUid,
          ),
          builder: (context, blockedByMeSnapshot) {
            final blockedByMe = blockedByMeSnapshot.data ?? false;
            return StreamBuilder<bool>(
              stream: _blockService.watchIsBlocked(
                blockerUid: post.authorUid,
                blockedUid: currentUid,
              ),
              builder: (context, blockedMeSnapshot) {
                final blockedByAuthor = blockedMeSnapshot.data ?? false;
                return _buildPostCard(
                  context: context,
                  post: post,
                  displayName: displayName,
                  authorPhotoUrl: authorPhotoUrl,
                  blockedByMe: blockedByMe,
                  blockedByAuthor: blockedByAuthor,
                  currentUid: currentUid,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMediaCarousel(Post post) {
    final media = post.media;
    if (media.isEmpty) {
      return Container(
        height: 250,
        color: Colors.grey.shade200,
        child: const Center(child: Icon(Icons.image_not_supported)),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 360,
          child: PageView.builder(
            controller: _pageController,
            itemCount: media.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final item = media[index];
              switch (item.type) {
                case PostMediaType.image:
                  return Image.network(
                    item.url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 360,
                        color: Colors.grey.shade200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 360,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Không thể tải ảnh',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                case PostMediaType.video:
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PostVideoPage(videoUrl: item.url),
                        ),
                      );
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (item.thumbnailUrl != null)
                          Image.network(
                            item.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: Colors.black87),
                          )
                        else
                          Container(color: Colors.black87),
                        const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            color: Colors.white,
                            size: 72,
                          ),
                        ),
                        if (item.durationMs != null)
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _formatDuration(item.durationMs!),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
              }
            },
          ),
        ),
        if (media.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(media.length, (index) {
                final selected = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: selected ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: selected ? AppColors.primaryPink : Colors.grey.shade300,
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildPostCard({
    required BuildContext context,
    required Post post,
    required String displayName,
    required String? authorPhotoUrl,
    required bool blockedByMe,
    required bool blockedByAuthor,
    required String? currentUid,
  }) {
    if (blockedByAuthor) {
      return _HiddenPostNotice(
        message: '$displayName đã chặn bạn. Bài đăng bị ẩn.',
      );
    }
    if (blockedByMe) {
      return _HiddenPostNotice(
        message: 'Bạn đã chặn $displayName. Bỏ chặn để xem bài viết.',
        action: TextButton(
          onPressed: () => _unblockAuthor(post.authorUid),
          child: const Text('Bỏ chặn'),
        ),
      );
    }

    final isOwner = currentUid == post.authorUid;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Hero(
                  tag: 'avatar_${post.authorUid}',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => widget.onOpenProfile(post.authorUid),
                      borderRadius: BorderRadius.circular(30),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundImage:
                            authorPhotoUrl != null ? NetworkImage(authorPhotoUrl) : null,
                        backgroundColor: AppColors.borderGrey,
                        child: authorPhotoUrl == null
                            ? const Icon(Icons.person, color: AppColors.textLight)
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => widget.onOpenProfile(post.authorUid),
                        child: Text(
                          displayName,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (post.createdAt != null)
                        Text(
                          _formatTimeAgo(post.createdAt!),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textLight,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildTrailingMenu(
                  context: context,
                  post: post,
                  isOwner: isOwner,
                  blockedByMe: blockedByMe,
                ) ?? const SizedBox.shrink(),
              ],
            ),
          ),
          _buildMediaCarousel(post),
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: PostCaptionWithHashtags(
                caption: post.caption,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                StreamBuilder<bool>(
                  stream: widget.service.watchLikeStatus(post.id),
                  builder: (context, likeSnapshot) {
                    final isLiked = likeSnapshot.data ?? false;
                    final isLoggedIn = authRepository.currentUser() != null;
                    return _LikeButton(
                      isLiked: isLiked,
                      onPressed: isLoggedIn
                          ? () async {
                              try {
                                await widget.service.toggleLike(
                                  postId: post.id,
                                  like: !isLiked,
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Lỗi cập nhật lượt thích: $e'),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              }
                            }
                          : null,
                    );
                  },
                ),
                Text(
                  '${post.likeCount}',
                  style: AppTypography.caption.copyWith(color: AppColors.textDark),
                ),
                const SizedBox(width: 4),
                // Tổng số reaction trên tất cả bình luận của bài viết
                StreamBuilder<int>(
                  key: ValueKey('reaction_count_${post.id}'),
                  stream: widget.service.watchPostReactionCount(post.id),
                  initialData: 0,
                  builder: (context, snapshot) {
                    debugPrint('StreamBuilder for post ${post.id}: connectionState=${snapshot.connectionState}, hasData=${snapshot.hasData}, data=${snapshot.data}, hasError=${snapshot.hasError}');
                    if (snapshot.hasError) {
                      debugPrint('Error watching post reaction count for post ${post.id}: ${snapshot.error}');
                      return const SizedBox.shrink();
                    }
                    final totalReactions = snapshot.data ?? 0;
                    debugPrint('Post ${post.id}: totalReactions = $totalReactions (connectionState=${snapshot.connectionState})');
                    if (totalReactions <= 0) {
                      return const SizedBox.shrink();
                    }
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_emotions_outlined,
                          size: 18,
                          color: AppColors.primaryPink,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$totalReactions',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textDark),
                        ),
                      ],
                    );
                  },
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => widget.onOpenComments(post),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.comment_outlined,
                        color: AppColors.primaryPink,
                      ),
                    ),
                  ),
                ),
                Text(
                  '${post.commentCount}',
                  style: AppTypography.caption.copyWith(color: AppColors.textDark),
                ),
                const Spacer(),
                if (!isOwner && currentUid != null)
                  StreamBuilder<bool>(
                    stream: _savedPostsService.watchIsPostSaved(post.id),
                    builder: (context, snapshot) {
                      final isSaved = snapshot.data ?? false;
                      return IconButton(
                        icon: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: isSaved ? AppColors.primaryPink : AppColors.textLight,
                        ),
                        onPressed: () => _handleToggleSave(post, isSaved),
                      );
                    },
                  ),
                Material(
                  color: Colors.transparent,
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.share, color: AppColors.primaryPink),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    onSelected: (value) async {
                      if (value == 'share') {
                        await ShareService.sharePost(
                          postId: post.id,
                          caption: post.caption.isNotEmpty ? post.caption : null,
                        );
                      } else if (value == 'copy') {
                        await ShareService.copyPostLink(post.id);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Đã sao chép link'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share, color: AppColors.primaryPink),
                            SizedBox(width: 8),
                            Text('Chia sẻ'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.copy, color: AppColors.textDark),
                            SizedBox(width: 8),
                            Text('Sao chép link'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _handleToggleSave(Post post, bool isSaved) async {
    try {
      final saved = await _savedPostsService.toggleSaved(
        postId: post.id,
        postOwnerUid: post.authorUid,
        postUrl: SavedPostsService.buildPostLink(post.id),
      );
      if (!mounted) return;
      final message =
          saved ? 'Đã lưu bài viết.' : 'Đã bỏ lưu bài viết khỏi mục đã lưu.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật lưu bài viết: $e')),
      );
    }
  }

  Future<void> _handleTogglePin(Post post, bool isPinned) async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) return;

    try {
      if (isPinned) {
        await _profileRepository.removePinnedPost(currentUid, post.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gỡ ghim bài viết')),
        );
      } else {
        await _profileRepository.addPinnedPost(currentUid, post.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã ghim bài viết')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  Widget? _buildTrailingMenu({
    required BuildContext context,
    required Post post,
    required bool isOwner,
    required bool blockedByMe,
  }) {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) return null;
    if (isOwner) {
      return StreamBuilder<UserProfile?>(
        stream: _profileRepository.watchProfile(currentUid),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final isPinned = profile?.pinnedPostIds.contains(post.id) ?? false;
          
          return PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Xóa bài đăng'),
                    content: const Text(
                      'Bạn có chắc chắn muốn xóa bài đăng này?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Hủy'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Xóa'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  try {
                    await widget.service.deletePost(post.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã xóa bài đăng'),
                        ),
                      );
                      widget.onPostDeleted?.call();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lỗi xóa bài đăng: $e'),
                        ),
                      );
                    }
                  }
                }
              } else if (value == 'pin' || value == 'unpin') {
                await _handleTogglePin(post, isPinned);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: isPinned ? 'unpin' : 'pin',
                child: Row(
                  children: [
                    Icon(
                      isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: isPinned ? Colors.orange : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(isPinned ? 'Gỡ ghim' : 'Ghim bài viết'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Xóa bài đăng'),
                  ],
                ),
              ),
            ],
          );
        },
      );
    }

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        if (value == 'report') {
          await _reportPost(post);
        } else if (value == 'block') {
          await _confirmBlockAuthor(post.authorUid);
        } else if (value == 'unblock') {
          await _unblockAuthor(post.authorUid);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag_outlined, color: Colors.orange),
              SizedBox(width: 8),
              Text('Báo cáo bài viết'),
            ],
          ),
        ),
        PopupMenuItem(
          value: blockedByMe ? 'unblock' : 'block',
          child: Row(
            children: [
              Icon(
                blockedByMe ? Icons.lock_open : Icons.block,
                color: blockedByMe ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                blockedByMe ? 'Bỏ chặn tác giả' : 'Chặn tác giả',
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(int durationMs) {
    final duration = Duration(milliseconds: durationMs);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    final minutesStr = minutes.toString().padLeft(1, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
    return '$minutesStr:$secondsStr';
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'năm' : 'năm'} trước';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'tháng' : 'tháng'} trước';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'ngày' : 'ngày'} trước';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'giờ' : 'giờ'} trước';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'phút' : 'phút'} trước';
    } else {
      return 'Vừa xong';
    }
  }

  Future<void> _confirmBlockAuthor(String authorUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chặn tác giả'),
        content: const Text(
          'Bạn sẽ không nhìn thấy bài viết hoặc nhận thông báo từ người này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Chặn'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _blockService.blockUser(targetUid: authorUid);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã chặn tác giả.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chặn: $e')),
        );
      }
    }
  }

  Future<void> _unblockAuthor(String authorUid) async {
    try {
      await _blockService.unblockUser(authorUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã bỏ chặn.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể bỏ chặn: $e')),
      );
    }
  }

  Future<void> _reportPost(Post post) async {
    final reasons = [
      'Spam / Quảng cáo',
      'Nội dung phản cảm',
      'Giả mạo',
      'Bạo lực / Thù ghét',
      'Khác',
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons
              .map(
                (item) => ListTile(
                  title: Text(item),
                  onTap: () => Navigator.pop(context, item),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (reason == null) return;
    try {
      await _reportService.reportPost(
        postId: post.id,
        ownerUid: post.authorUid,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi báo cáo bài viết.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể báo cáo: $e')),
      );
    }
  }
}

class _HiddenPostNotice extends StatelessWidget {
  const _HiddenPostNotice({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 8),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _StoriesBar extends StatelessWidget {
  const _StoriesBar({required this.storyRepository});

  final StoryRepository storyRepository;

  @override
  Widget build(BuildContext context) {
    final user = authRepository.currentUser();
    if (user == null) {
      return const SizedBox.shrink();
    }

    final followService = FollowService();

    return SizedBox(
      height: 110,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: StreamBuilder<List<FollowEntry>>(
          stream: followService.watchFollowingEntries(user.uid),
          builder: (context, snapshot) {
            final following = snapshot.data ?? [];

            return ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Story của chính mình
                StreamBuilder<List<Story>>(
                  stream: storyRepository.watchUserStories(user.uid),
                  builder: (context, userStorySnap) {
                    final myStories = userStorySnap.data ?? [];
                    final hasMyStories = myStories.isNotEmpty;
                    return StreamBuilder<UserProfile?>(
                      stream: userProfileRepository.watchProfile(user.uid),
                      builder: (context, profileSnap) {
                        final profile = profileSnap.data;
                        final photoUrl = profile?.photoUrl;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  // Avatar: bấm để xem / tạo story
                                  GestureDetector(
                                    onTap: () {
                                      if (hasMyStories) {
                                        // Xem story hiện tại của mình + người đang theo dõi
                                        final usersWithStories = <String>[user.uid];
                                        for (final entry in following) {
                                          usersWithStories.add(entry.uid);
                                        }
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => StoryViewerPage(
                                              initialAuthorUid: user.uid,
                                              userIdsWithStories: usersWithStories,
                                            ),
                                          ),
                                        );
                                      } else {
                                        // Chưa có story: chuyển thẳng tới trang tạo story
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const StoryCreatePage(),
                                          ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: hasMyStories
                                            ? const LinearGradient(
                                                colors: [Colors.orange, Colors.pink],
                                              )
                                            : null,
                                        color: hasMyStories
                                            ? null
                                            : Colors.grey.shade300,
                                      ),
                                      child: CircleAvatar(
                                        radius: 30,
                                        backgroundImage: photoUrl != null
                                            ? NetworkImage(photoUrl)
                                            : null,
                                        backgroundColor: photoUrl == null
                                            ? Colors.grey.shade300
                                            : null,
                                        child: photoUrl == null
                                            ? const Icon(Icons.person)
                                            : null,
                                      ),
                                    ),
                                  ),
                                  // Nút dấu +: luôn mở trang tạo story
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const StoryCreatePage(),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.blue,
                                        ),
                                        padding: const EdgeInsets.all(2),
                                        child: const Icon(
                                          Icons.add,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hasMyStories ? 'Tin của bạn' : 'Thêm tin',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                // Stories của những người đang theo dõi
                ...following.map((entry) {
                  final profile = entry.profile;
                  final displayName = profile?.displayName?.isNotEmpty == true
                      ? profile!.displayName!
                      : entry.uid;
                  return StreamBuilder<List<Story>>(
                    stream: storyRepository.watchUserStories(entry.uid),
                    builder: (context, storySnap) {
                      final stories = storySnap.data ?? [];
                      if (stories.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return GestureDetector(
                        onTap: () {
                          // Tạo danh sách users có story: chính mình + người theo dõi có story
                          final usersWithStories = <String>[user.uid];
                          for (final followEntry in following) {
                            // Chỉ thêm những user có story (đã được check trong StreamBuilder)
                            usersWithStories.add(followEntry.uid);
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StoryViewerPage(
                                initialAuthorUid: entry.uid,
                                userIdsWithStories: usersWithStories,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [Colors.orange, Colors.pink],
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundImage: profile?.photoUrl != null
                                      ? NetworkImage(profile!.photoUrl!)
                                      : null,
                                  child: profile?.photoUrl == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedPostItem extends StatefulWidget {
  const _AnimatedPostItem({
    super.key,
    required this.index,
    required this.entry,
    required this.service,
    required this.onOpenProfile,
    required this.onOpenComments,
    this.onPostDeleted,
  });

  final int index;
  final PostFeedEntry entry;
  final PostService service;
  final void Function(String uid) onOpenProfile;
  final void Function(Post post) onOpenComments;
  final VoidCallback? onPostDeleted;

  @override
  State<_AnimatedPostItem> createState() => _AnimatedPostItemState();
}

class _AnimatedPostItemState extends State<_AnimatedPostItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300 + (widget.index * 50).clamp(0, 300)),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: PostFeedItem(
          entry: widget.entry,
          service: widget.service,
          onOpenProfile: widget.onOpenProfile,
          onOpenComments: widget.onOpenComments,
          onPostDeleted: widget.onPostDeleted,
        ),
      ),
    );
  }
}

class _LikeButton extends StatefulWidget {
  const _LikeButton({
    required this.isLiked,
    this.onPressed,
  });

  final bool isLiked;
  final VoidCallback? onPressed;

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void didUpdateWidget(_LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked != oldWidget.isLiked && widget.isLiked) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              widget.isLiked ? Icons.favorite : Icons.favorite_border,
              color: widget.isLiked ? AppColors.primaryPink : AppColors.textLight,
            ),
          ),
        ),
      ),
    );
  }
}

