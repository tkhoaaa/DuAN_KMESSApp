import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../posts/models/post.dart';
import '../../posts/models/post_media.dart';
import '../../posts/pages/post_permalink_page.dart';
import '../../posts/pages/post_video_page.dart';
import '../../posts/repositories/post_repository.dart';
import '../../profile/user_profile_repository.dart';
import '../models/saved_post.dart';
import '../services/saved_posts_service.dart';

class SavedPostsPage extends StatefulWidget {
  const SavedPostsPage({super.key});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> {
  final SavedPostsService _service = savedPostsService;
  final PostRepository _postRepository = PostRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bài viết đã lưu'),
      ),
      body: StreamBuilder<List<SavedPost>>(
        stream: _service.watchMySavedPosts(limit: 100),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final savedPosts = snapshot.data ?? [];
          if (savedPosts.isEmpty) {
            return _EmptySavedState(
              onBrowseFeed: () => Navigator.of(context).pop(),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final saved = savedPosts[index];
              return _SavedPostListItem(
                savedPost: saved,
                repository: _postRepository,
                onOpenPostPreview: _openPostPreview,
                onOpenOriginalPost: _openOriginalPost,
                onUnsave: () => _unsavePost(saved.postId),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: savedPosts.length,
          );
        },
      ),
    );
  }

  Future<void> _unsavePost(String postId) async {
    try {
      await _service.unsavePost(postId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã bỏ lưu bài viết.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể bỏ lưu: $e')),
      );
    }
  }

  void _openPostPreview(Post post, UserProfile? author, String postLink) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SavedPostPreviewSheet(
        post: post,
        author: author,
        postLink: postLink,
        onOpenOriginal: () {
          Navigator.of(context).pop();
          _openOriginalPost(post);
        },
      ),
    );
  }

  void _openOriginalPost(Post post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostPermalinkPage(postId: post.id),
      ),
    );
  }
}

class _SavedPostListItem extends StatelessWidget {
  const _SavedPostListItem({
    required this.savedPost,
    required this.repository,
    required this.onOpenPostPreview,
    required this.onOpenOriginalPost,
    required this.onUnsave,
  });

  final SavedPost savedPost;
  final PostRepository repository;
  final void Function(Post, UserProfile?, String postLink) onOpenPostPreview;
  final void Function(Post) onOpenOriginalPost;
  final VoidCallback onUnsave;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Post>(
      stream: repository.watchPost(savedPost.postId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: ListTile(
              leading: CircularProgressIndicator(),
              title: Text('Đang tải bài viết...'),
            ),
          );
        }
        final post = snapshot.data!;
        return StreamBuilder<UserProfile?>(
          stream: userProfileRepository.watchProfile(post.authorUid),
          builder: (context, profileSnapshot) {
            final profile = profileSnapshot.data;
            final caption = post.caption.isNotEmpty
                ? post.caption
                : 'Bài viết của ${_authorLabel(profile, post.authorUid)}';
            final authorName = _authorLabel(profile, post.authorUid);
            final postLink = savedPost.postUrl?.isNotEmpty == true
                ? savedPost.postUrl!
                : SavedPostsService.buildPostLink(post.id);
            return Card(
              child: InkWell(
                onTap: () => onOpenPostPreview(post, profile, postLink),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _SavedPostThumbnail(post: post),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              caption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tác giả: $authorName',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Đã lưu lúc ${savedPost.savedAt.toLocal()}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => onOpenOriginalPost(post),
                              child: Text(
                                postLink,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () => onOpenOriginalPost(post),
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('Mở bài viết gốc'),
                                ),
                                IconButton(
                                  tooltip: 'Sao chép liên kết',
                                  icon: const Icon(Icons.copy),
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: postLink),
                                    );
                                    ScaffoldMessenger.maybeOf(context)
                                        ?.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Đã sao chép liên kết bài viết'),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.bookmark_remove),
                        onPressed: onUnsave,
                        tooltip: 'Bỏ lưu',
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SavedPostThumbnail extends StatelessWidget {
  const _SavedPostThumbnail({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final media = post.media;
    if (media.isEmpty) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.image_not_supported),
      );
    }
    final first = media.first;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: first.type == PostMediaType.image
                ? Image.network(
                    first.url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image),
                    ),
                  )
                : (first.thumbnailUrl != null
                    ? Image.network(
                        first.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.black87,
                        ),
                      )
                    : Container(color: Colors.black87)),
          ),
          if (first.type == PostMediaType.video)
            const Positioned(
              right: 4,
              bottom: 4,
              child: Icon(
                Icons.videocam,
                size: 18,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptySavedState extends StatelessWidget {
  const _EmptySavedState({required this.onBrowseFeed});

  final VoidCallback onBrowseFeed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bookmark_border, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Bạn chưa lưu bài viết nào.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nhấn biểu tượng bookmark tại bài viết để lưu và xem lại tại đây.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onBrowseFeed,
              child: const Text('Trở về bảng tin'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedPostPreviewSheet extends StatelessWidget {
  const _SavedPostPreviewSheet({
    required this.post,
    this.author,
    required this.postLink,
    this.onOpenOriginal,
  });

  final Post post;
  final UserProfile? author;
  final String postLink;
  final VoidCallback? onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: author?.photoUrl != null
                        ? NetworkImage(author!.photoUrl!)
                        : null,
                    child: author?.photoUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _authorLabel(author, post.authorUid),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (author?.email != null)
                          Text(
                            author!.email!,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
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
              const SizedBox(height: 12),
              _PreviewMediaCarousel(post: post),
              if (post.caption.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(post.caption),
              ],
              const SizedBox(height: 12),
              Text(
                'Đã tạo lúc: ${post.createdAt?.toLocal()}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              _LinkSection(
                postLink: postLink,
                onOpenOriginal: onOpenOriginal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewMediaCarousel extends StatefulWidget {
  const _PreviewMediaCarousel({required this.post});

  final Post post;

  @override
  State<_PreviewMediaCarousel> createState() => _PreviewMediaCarouselState();
}

class _PreviewMediaCarouselState extends State<_PreviewMediaCarousel> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.post.media;
    if (media.isEmpty) {
      return Container(
        height: 300,
        color: Colors.grey.shade200,
        child: const Center(child: Icon(Icons.image_not_supported)),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 340,
          child: PageView.builder(
            controller: _controller,
            itemCount: media.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final item = media[index];
              if (item.type == PostMediaType.image) {
                return Image.network(
                  item.url,
                  fit: BoxFit.cover,
                );
              }
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PostVideoPage(videoUrl: item.url),
                  ),
                ),
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
                  ],
                ),
              );
            },
          ),
        ),
        if (media.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(media.length, (index) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == index
                        ? Colors.blue
                        : Colors.grey.shade400,
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

String _authorLabel(UserProfile? profile, String fallbackUid) {
  if (profile == null) return fallbackUid;
  if (profile.displayName?.isNotEmpty == true) return profile.displayName!;
  if (profile.email?.isNotEmpty == true) return profile.email!;
  return fallbackUid;
}

class _LinkSection extends StatelessWidget {
  const _LinkSection({
    required this.postLink,
    this.onOpenOriginal,
  });

  final String postLink;
  final VoidCallback? onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Liên kết bài viết',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SelectableText(
          postLink,
          style: const TextStyle(
            color: Colors.blueAccent,
            decoration: TextDecoration.underline,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onOpenOriginal,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Mở bài viết gốc'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: postLink));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã sao chép liên kết bài viết'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Sao chép'),
            ),
          ],
        ),
      ],
    );
  }
}

