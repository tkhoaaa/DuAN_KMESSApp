import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../avatar/story_avatar.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.avatarUrl,
    required this.username,
    required this.timeAgo,
    required this.media,
    this.caption,
    this.commentPreview,
    this.onLike,
    this.onComment,
    this.onShare,
    this.isLiked = false,
  });

  final String avatarUrl;
  final String username;
  final String timeAgo;
  final Widget media;
  final String? caption;
  final String? commentPreview;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final bool isLiked;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                StoryAvatar(imageUrl: avatarUrl, size: 44, isUnseen: false),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(timeAgo, style: AppTypography.small),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz, color: AppColors.primaryPink),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: media,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                IconButton(
                  onPressed: onLike,
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? AppColors.primaryPink : AppColors.primaryPink,
                  ),
                ),
                IconButton(
                  onPressed: onComment,
                  icon: const Icon(Icons.mode_comment_outlined, color: AppColors.primaryPink),
                ),
                IconButton(
                  onPressed: onShare,
                  icon: const Icon(Icons.send, color: AppColors.primaryPink),
                ),
              ],
            ),
          ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                caption!,
                style: AppTypography.body.copyWith(color: AppColors.textDark),
              ),
            ),
          if (commentPreview != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                commentPreview!,
                style: AppTypography.caption.copyWith(color: AppColors.textDark),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

