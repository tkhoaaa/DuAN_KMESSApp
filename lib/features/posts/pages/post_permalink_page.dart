import 'package:flutter/material.dart';

import '../../profile/public_profile_page.dart';
import '../../profile/user_profile_repository.dart';
import '../models/post.dart';
import '../models/post_media.dart';
import '../repositories/post_repository.dart';
import 'post_video_page.dart';

class PostPermalinkPage extends StatelessWidget {
  PostPermalinkPage({super.key, required this.postId})
      : _postRepository = PostRepository();

  final String postId;
  final PostRepository _postRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bài viết'),
      ),
      body: StreamBuilder<Post>(
        stream: _postRepository.watchPost(postId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(
              child: Text('Không tìm thấy bài viết. Có thể đã bị xóa.'),
            );
          }
          final post = snapshot.data!;
          return StreamBuilder<UserProfile?>(
            stream: userProfileRepository.watchProfile(post.authorUid),
            builder: (context, profileSnapshot) {
              final profile = profileSnapshot.data;
              final authorName = _authorLabel(profile, post.authorUid);
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: profile?.photoUrl != null
                              ? NetworkImage(profile!.photoUrl!)
                              : null,
                          child: profile?.photoUrl == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authorName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (profile?.email?.isNotEmpty == true)
                                Text(
                                  profile!.email!,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              if (post.createdAt != null)
                                Text(
                                  'Đăng lúc: ${post.createdAt!.toLocal()}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PublicProfilePage(uid: post.authorUid),
                              ),
                            );
                          },
                          child: const Text('Xem trang'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _PermalinkMediaCarousel(post: post),
                    if (post.caption.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        post.caption,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PermalinkMediaCarousel extends StatefulWidget {
  const _PermalinkMediaCarousel({required this.post});

  final Post post;

  @override
  State<_PermalinkMediaCarousel> createState() => _PermalinkMediaCarouselState();
}

class _PermalinkMediaCarouselState extends State<_PermalinkMediaCarousel> {
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
        height: 340,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Icon(Icons.image_not_supported)),
      );
    }
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 360,
            child: PageView.builder(
              controller: _controller,
              itemCount: media.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
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

