import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../profile/user_profile_repository.dart';
import '../models/story.dart';
import '../repositories/story_repository.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../posts/pages/post_video_page.dart';

class StoryArchivePage extends StatefulWidget {
  const StoryArchivePage({super.key});

  @override
  State<StoryArchivePage> createState() => _StoryArchivePageState();
}

class _StoryArchivePageState extends State<StoryArchivePage> {
  final StoryRepository _storyRepository = StoryRepository();

  String? get _uid => authRepository.currentUser()?.uid;

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Bạn cần đăng nhập để xem kho lưu trữ.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Kho lưu trữ Story',
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryPink,
          ),
        ),
      ),
      body: StreamBuilder<List<Story>>(
        stream: _storyRepository.watchUserStoryArchive(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final stories = snapshot.data ?? [];
          if (stories.isEmpty) {
            return const Center(child: Text('Chưa có story trong kho lưu trữ.'));
          }
          return StreamBuilder<UserProfile?>(
            stream: userProfileRepository.watchProfile(uid),
            builder: (context, profileSnap) {
              final profile = profileSnap.data;
              final pinned = profile?.pinnedStoryIds ?? const [];
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: stories.length,
                itemBuilder: (context, index) {
                  final story = stories[index];
                  final isPinned = pinned.contains(story.id);
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: story.type == StoryMediaType.image
                                    ? Image.network(
                                        story.mediaUrl,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey.shade200,
                                          child: const Icon(Icons.broken_image),
                                        ),
                                      )
                                    : Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Image.network(
                                            story.thumbnailUrl ?? story.mediaUrl,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              width: 80,
                                              height: 80,
                                              color: Colors.grey.shade200,
                                              child: const Icon(Icons.videocam),
                                            ),
                                          ),
                                          const Icon(Icons.play_circle_fill, color: Colors.white),
                                        ],
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      story.text?.isNotEmpty == true ? story.text! : '(Không có mô tả)',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Đăng lúc: ${story.createdAt}',
                                      style: AppTypography.small.copyWith(color: AppColors.textLight),
                                    ),
                                    Text(
                                      'Hết hạn: ${story.expiresAt}',
                                      style: AppTypography.small.copyWith(color: AppColors.textLight),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.visibility),
                                label: const Text('Xem'),
                                onPressed: () {
                                  if (story.type == StoryMediaType.video) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PostVideoPage(
                                          videoUrl: story.mediaUrl,
                                        ),
                                      ),
                                    );
                                  } else {
                                    showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        insetPadding: const EdgeInsets.all(16),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            story.mediaUrl,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => const Padding(
                                              padding: EdgeInsets.all(24),
                                              child: Text('Không tải được ảnh'),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.repeat),
                                label: const Text('Đăng lại'),
                                onPressed: () async {
                                  try {
                                    await _storyRepository.repostStory(authorUid: uid, story: story);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Đã đăng lại story')),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Lỗi đăng lại: $e')),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                                label: Text(isPinned ? 'Đã ghim' : 'Ghim lên hồ sơ'),
                                onPressed: isPinned
                                    ? null
                                    : () async {
                                        try {
                                          await userProfileRepository.addPinnedStory(uid, story.id);
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Đã ghim story lên hồ sơ')),
                                          );
                                        } catch (e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Lỗi ghim: $e')),
                                          );
                                        }
                                      },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

