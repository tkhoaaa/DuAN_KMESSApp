import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../models/story.dart';
import '../repositories/story_repository.dart';

class StoryViewerPage extends StatelessWidget {
  const StoryViewerPage({
    super.key,
    required this.authorUid,
  });

  final String authorUid;

  @override
  Widget build(BuildContext context) {
    final repo = StoryRepository();
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: StreamBuilder<List<Story>>(
          stream: repo.watchUserStories(authorUid),
          builder: (context, snapshot) {
            final stories = snapshot.data ?? [];
            if (stories.isEmpty) {
              return const Center(
                child: Text(
                  'Không có story nào',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }
            return PageView.builder(
              itemCount: stories.length,
              itemBuilder: (context, index) {
                final story = stories[index];
                // Ghi nhận viewer
                final current = authRepository.currentUser();
                if (current != null) {
                  repo
                      .addViewer(
                        authorUid: authorUid,
                        storyId: story.id,
                        viewerUid: current.uid,
                      )
                      .catchError((_) {});
                }
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (story.type == StoryMediaType.image)
                      Image.network(
                        story.mediaUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 48,
                            ),
                          );
                        },
                      )
                    else
                      Center(
                        child: IconButton(
                          iconSize: 64,
                          icon: const Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            // Tạm thời chỉ hiển thị icon, có thể mở trang video riêng sau
                          },
                        ),
                      ),
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Row(
                        children: [
                          const BackButton(color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              story.text ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}


