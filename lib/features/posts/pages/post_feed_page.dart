import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../profile/public_profile_page.dart';
import '../models/post.dart';
import '../models/post_media.dart';
import '../services/post_service.dart';
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
  final List<PostFeedEntry> _entries = [];
  final ScrollController _scrollController = ScrollController();

  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
                itemCount: _entries.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _entries.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final entry = _entries[index];
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Post>(
      stream: widget.service.watchPost(widget.entry.doc.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final post = snapshot.data!;
        final author = widget.entry.author;
        final displayName = author?.displayName?.isNotEmpty == true
            ? author!.displayName!
            : (author?.email?.isNotEmpty == true
                ? author!.email!
                : post.authorUid);

        if (_currentPage >= (post.media.isNotEmpty ? post.media.length : 1)) {
          _currentPage = 0;
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: author?.photoUrl != null
                      ? NetworkImage(author!.photoUrl!)
                      : null,
                  child: author?.photoUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(displayName),
                subtitle: post.createdAt != null
                    ? Text(post.createdAt!.toLocal().toString())
                    : null,
                onTap: () => widget.onOpenProfile(post.authorUid),
                trailing: authRepository.currentUser()?.uid == post.authorUid
                    ? PopupMenuButton<String>(
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
                                  // Gọi callback để reload feed
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
                          }
                        },
                        itemBuilder: (context) => [
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
                      )
                    : null,
              ),
              _buildMediaCarousel(post),
              if (post.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(post.caption),
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
                                        content: Text('Lỗi cập nhật lượt thích: $e'),
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

  String _formatDuration(int durationMs) {
    final duration = Duration(milliseconds: durationMs);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    final minutesStr = minutes.toString().padLeft(1, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
    return '$minutesStr:$secondsStr';
  }
}

