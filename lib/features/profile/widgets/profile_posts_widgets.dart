import 'package:flutter/material.dart';

import '../../posts/models/post.dart';
import '../../posts/models/post_media.dart';
import '../../posts/pages/post_video_page.dart';

typedef PostTapCallback = void Function();

class ProfilePinnedPostItem extends StatelessWidget {
  const ProfilePinnedPostItem({
    super.key,
    required this.post,
    required this.onTap,
  });

  final Post post;
  final PostTapCallback onTap;

  @override
  Widget build(BuildContext context) {
    final firstMedia = post.media.isNotEmpty ? post.media.first : null;
    final isImage = firstMedia?.type == PostMediaType.image;
    final isVideo = firstMedia?.type == PostMediaType.video;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        if (isVideo == true && firstMedia != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostVideoPage(videoUrl: firstMedia.url),
            ),
          );
        }
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange, width: 2),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: firstMedia != null
                  ? (isImage
                      ? Image.network(
                          firstMedia.url,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 120,
                            height: 120,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image),
                          ),
                        )
                      : Image.network(
                          firstMedia.thumbnailUrl ?? firstMedia.url,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 120,
                            height: 120,
                            color: Colors.grey[300],
                            child: const Icon(Icons.videocam, size: 32),
                          ),
                        ))
                  : Container(
                      width: 120,
                      height: 120,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, size: 32),
                    ),
            ),
            if (isVideo == true)
              const Positioned(
                bottom: 4,
                right: 4,
                child: Icon(
                  Icons.play_circle_filled,
                  color: Colors.white,
                  size: 24,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ProfilePostGridItem extends StatelessWidget {
  const ProfilePostGridItem({
    super.key,
    required this.post,
    required this.onTap,
  });

  final Post post;
  final PostTapCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (post.media.isEmpty) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          color: Colors.grey[300],
          child: const Icon(Icons.image, size: 48),
        ),
      );
    }

    final firstMedia = post.media.first;
    final isVideo = firstMedia.type == PostMediaType.video;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        if (isVideo) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostVideoPage(videoUrl: firstMedia.url),
            ),
          );
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            firstMedia.thumbnailUrl ?? firstMedia.url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image),
              );
            },
          ),
          if (isVideo)
            const Positioned(
              bottom: 4,
              right: 4,
              child: Icon(
                Icons.play_circle_filled,
                color: Colors.white,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }
}


