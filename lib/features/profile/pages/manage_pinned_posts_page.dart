import 'package:flutter/material.dart';
import '../user_profile_repository.dart';
import '../../auth/auth_repository.dart';
import '../../posts/repositories/post_repository.dart';
import '../../posts/models/post.dart';
import '../../posts/models/post_media.dart';
import '../../posts/pages/post_permalink_page.dart';

class ManagePinnedPostsPage extends StatefulWidget {
  const ManagePinnedPostsPage({super.key});

  @override
  State<ManagePinnedPostsPage> createState() => _ManagePinnedPostsPageState();
}

class _ManagePinnedPostsPageState extends State<ManagePinnedPostsPage> {
  final PostRepository _postRepository = PostRepository();
  bool _isLoading = false;
  List<Post> _pinnedPosts = [];
  List<Post> _allPosts = [];
  bool _isLoadingPosts = false;

  @override
  void initState() {
    super.initState();
    _loadPinnedPosts();
    _loadAllPosts();
  }

  Future<void> _loadPinnedPosts() async {
    final user = authRepository.currentUser();
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final profile = await userProfileRepository.fetchProfile(user.uid);
      if (profile == null || profile.pinnedPostIds.isEmpty) {
        setState(() {
          _pinnedPosts = [];
          _isLoading = false;
        });
        return;
      }

      // Fetch tất cả pinned posts
      final posts = <Post>[];
      for (final postId in profile.pinnedPostIds) {
        try {
          final post = await _postRepository.watchPost(postId).first;
          posts.add(post);
        } catch (e) {
          // Post có thể đã bị xóa, bỏ qua
          continue;
        }
      }

      setState(() {
        _pinnedPosts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _loadAllPosts() async {
    final user = authRepository.currentUser();
    if (user == null) return;

    setState(() {
      _isLoadingPosts = true;
    });

    try {
      final pageResult = await _postRepository.fetchPostsByAuthor(
        authorUid: user.uid,
        limit: 50,
      );

      final posts = pageResult.docs.map((doc) => Post.fromDoc(doc)).toList();

      setState(() {
        _allPosts = posts;
        _isLoadingPosts = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPosts = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải bài viết: $e')),
        );
      }
    }
  }

  Future<void> _addPinnedPost(String postId) async {
    final user = authRepository.currentUser();
    if (user == null) return;

    if (_pinnedPosts.length >= 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đạt giới hạn 3 bài viết ghim'),
          ),
        );
      }
      return;
    }

    try {
      await userProfileRepository.addPinnedPost(user.uid, postId);
      await _loadPinnedPosts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã ghim bài viết')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _removePinnedPost(String postId) async {
    final user = authRepository.currentUser();
    if (user == null) return;

    try {
      await userProfileRepository.removePinnedPost(user.uid, postId);
      await _loadPinnedPosts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gỡ ghim bài viết')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _reorderPinnedPosts(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final user = authRepository.currentUser();
    if (user == null) return;

    final newOrder = List<Post>.from(_pinnedPosts);
    final item = newOrder.removeAt(oldIndex);
    newIndex = newIndex.clamp(0, newOrder.length);
    newOrder.insert(newIndex, item);

    try {
      await userProfileRepository.reorderPinnedPosts(
        user.uid,
        newOrder.map((p) => p.id).toList(),
      );
      await _loadPinnedPosts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _showAddPostDialog() async {
    final user = authRepository.currentUser();
    if (user == null) return;

    if (_pinnedPosts.length >= 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đạt giới hạn 3 bài viết ghim'),
          ),
        );
      }
      return;
    }

    // Lọc ra các posts chưa được ghim
    final pinnedIds = _pinnedPosts.map((p) => p.id).toSet();
    final availablePosts = _allPosts
        .where((post) => !pinnedIds.contains(post.id))
        .toList();

    if (availablePosts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không còn bài viết nào để ghim')),
        );
      }
      return;
    }

    if (!mounted) return;
    final selectedPost = await showModalBottomSheet<Post>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Chọn bài viết để ghim',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: availablePosts.length,
                itemBuilder: (context, index) {
                  final post = availablePosts[index];
                  return _PostSelectionTile(
                    post: post,
                    onTap: () => Navigator.pop(context, post),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selectedPost != null) {
      await _addPinnedPost(selectedPost.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý bài viết ghim'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header với thông tin
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Row(
                    children: [
                      const Icon(Icons.push_pin),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bạn có thể ghim tối đa 3 bài viết (${_pinnedPosts.length}/3)',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                // Danh sách pinned posts
                Expanded(
                  child: _pinnedPosts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.push_pin_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Chưa có bài viết nào được ghim',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _showAddPostDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Thêm bài viết'),
                              ),
                            ],
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _pinnedPosts.length,
                          onReorder: _reorderPinnedPosts,
                          itemBuilder: (context, index) {
                            final post = _pinnedPosts[index];
                            return _PinnedPostCard(
                              key: ValueKey(post.id),
                              post: post,
                              index: index + 1,
                              onRemove: () => _removePinnedPost(post.id),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PostPermalinkPage(
                                      postId: post.id,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
                // Nút thêm bài viết
                if (_pinnedPosts.length < 3)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      onPressed: _showAddPostDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm bài viết'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _PinnedPostCard extends StatelessWidget {
  const _PinnedPostCard({
    required this.post,
    required this.index,
    required this.onRemove,
    required this.onTap,
    super.key,
  });

  final Post post;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final firstMedia = post.media.isNotEmpty ? post.media.first : null;
    final isImage = firstMedia?.type == PostMediaType.image;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Drag handle
              const Icon(Icons.drag_handle, color: Colors.grey),
              const SizedBox(width: 8),
              // Thumbnail
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: firstMedia != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: isImage
                            ? Image.network(
                                firstMedia.url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image,
                                ),
                              )
                            : const Icon(Icons.videocam, size: 32),
                      )
                    : const Icon(Icons.image, size: 32),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.push_pin,
                          size: 16,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Bài viết #$index',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (post.caption.isNotEmpty)
                      Text(
                        post.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      )
                    else
                      const Text(
                        'Không có mô tả',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${post.likeCount} lượt thích • ${post.commentCount} bình luận',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              // Remove button
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onRemove,
                tooltip: 'Gỡ ghim',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostSelectionTile extends StatelessWidget {
  const _PostSelectionTile({
    required this.post,
    required this.onTap,
  });

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final firstMedia = post.media.isNotEmpty ? post.media.first : null;
    final isImage = firstMedia?.type == PostMediaType.image;

    return ListTile(
      leading: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: firstMedia != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isImage
                    ? Image.network(
                        firstMedia.url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image,
                        ),
                      )
                    : const Icon(Icons.videocam),
              )
            : const Icon(Icons.image),
      ),
      title: Text(
        post.caption.isNotEmpty
            ? post.caption
            : 'Bài viết không có mô tả',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${post.likeCount} lượt thích • ${post.commentCount} bình luận',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: onTap,
    );
  }
}

