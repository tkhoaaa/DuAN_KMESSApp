import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../profile/public_profile_page.dart';
import '../../profile/user_profile_repository.dart';
import '../../saved_posts/services/saved_posts_service.dart';
import '../../safety/services/block_service.dart';
import '../../safety/services/report_service.dart';
import '../../stories/pages/story_create_page.dart';
import '../../stories/pages/story_viewer_page.dart';
import '../../stories/models/story.dart';
import '../../stories/repositories/story_repository.dart';
import '../../follow/services/follow_service.dart';
import '../models/post.dart';
import '../models/post_media.dart';
import '../services/post_service.dart';
import '../widgets/post_caption_with_hashtags.dart';
import 'post_comments_sheet.dart';
import 'post_create_page.dart';
import 'post_video_page.dart';

class PostFeedPage extends StatefulWidget {
  const PostFeedPage({super.key});

  @override
  State<PostFeedPage> createState() => _PostFeedPageState();
}

class _PostFeedPageState extends State<PostFeedPage> {
  final PostService _postService = PostService();
  final StoryRepository _storyRepository = StoryRepository();
  final List<PostFeedEntry> _entries = [];
  final ScrollController _scrollController = ScrollController();

  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _initialLoading = true;
  StreamSubscription<List<Post>>? _publishedPostsSubscription;
  Set<String> _knownPostIds = {}; // Track posts đã load để tránh duplicate

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
    // Listen cho posts mới được publish
    _listenForNewPublishedPosts();
  }

  @override
  void dispose() {
    _publishedPostsSubscription?.cancel();
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
      final result = await _postService.fetchFeedPage(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng tin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Story của bạn',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StoryCreatePage()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const PostCreatePage()),
          );
          if (created == true) {
            _loadInitial();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
        child: _initialLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: _entries.length + 1 + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _StoriesBar(storyRepository: _storyRepository);
                  }
                  final postIndex = index - 1;
                  if (postIndex >= _entries.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final entry = _entries[postIndex];
                  return PostFeedItem(
                    entry: entry,
                    service: _postService,
                    onOpenProfile: (uid) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PublicProfilePage(uid: uid),
                        ),
                      );
                    },
                    onOpenComments: (post) {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => PostCommentsSheet(post: post),
                      );
                    },
                    onPostDeleted: () {
                      // Reload feed sau khi xóa post
                      _loadInitial();
                    },
                  );
                },
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(media.length, (index) {
                final selected = index == _currentPage;
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? Colors.blue : Colors.grey.shade400,
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  authorPhotoUrl != null ? NetworkImage(authorPhotoUrl) : null,
              child: authorPhotoUrl == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(displayName),
            subtitle: post.createdAt != null
                ? Text(post.createdAt!.toLocal().toString())
                : null,
            onTap: () => widget.onOpenProfile(post.authorUid),
            trailing: _buildTrailingMenu(
              context: context,
              post: post,
              isOwner: isOwner,
              blockedByMe: blockedByMe,
            ),
          ),
          _buildMediaCarousel(post),
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: PostCaptionWithHashtags(
                caption: post.caption,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                StreamBuilder<bool>(
                  stream: widget.service.watchLikeStatus(post.id),
                  builder: (context, likeSnapshot) {
                    final isLiked = likeSnapshot.data ?? false;
                    final isLoggedIn = authRepository.currentUser() != null;
                    return IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.grey,
                      ),
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
                                    content:
                                        Text('Lỗi cập nhật lượt thích: $e'),
                                  ),
                                );
                              }
                            }
                          : null,
                    );
                  },
                ),
                Text('${post.likeCount}'),
                IconButton(
                  icon: const Icon(Icons.comment_outlined),
                  onPressed: () => widget.onOpenComments(post),
                ),
                Text('${post.commentCount}'),
                const Spacer(),
                if (!isOwner && currentUid != null)
                  StreamBuilder<bool>(
                    stream: _savedPostsService.watchIsPostSaved(post.id),
                    builder: (context, snapshot) {
                      final isSaved = snapshot.data ?? false;
                      return IconButton(
                        icon: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: isSaved ? Colors.blueAccent : Colors.grey,
                        ),
                        onPressed: () => _handleToggleSave(post, isSaved),
                      );
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
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
                    return GestureDetector(
                      onTap: () {
                        if (hasMyStories) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  StoryViewerPage(authorUid: user.uid),
                            ),
                          );
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const StoryCreatePage(),
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: hasMyStories
                                        ? const LinearGradient(
                                            colors: [
                                              Colors.orange,
                                              Colors.pink
                                            ],
                                          )
                                        : null,
                                    color: hasMyStories
                                        ? null
                                        : Colors.grey.shade300,
                                  ),
                                  child: const CircleAvatar(
                                    radius: 30,
                                    child: Icon(Icons.person),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
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
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasMyStories ? 'Story của bạn' : 'Thêm story',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
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
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  StoryViewerPage(authorUid: entry.uid),
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

