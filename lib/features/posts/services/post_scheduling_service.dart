import '../../auth/auth_repository.dart';
import '../repositories/post_repository.dart';

class PostSchedulingService {
  PostSchedulingService({PostRepository? repository})
      : _repository = repository ?? PostRepository();

  final PostRepository _repository;

  /// Kiểm tra và publish các scheduled posts đã đến giờ
  Future<int> checkAndPublishScheduledPosts() async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) return 0;

    try {
      // Fetch scheduled posts của user
      final scheduledPosts = await _repository.fetchScheduledPosts(
        authorUid: currentUid,
        limit: 100, // Giới hạn để tránh quá nhiều
      );

      final now = DateTime.now();
      int publishedCount = 0;

      for (final post in scheduledPosts) {
        // Chỉ publish nếu scheduledAt đã đến hoặc đã qua
        if (post.scheduledAt != null && post.scheduledAt!.isBefore(now)) {
          try {
            await _repository.publishScheduledPost(
              postId: post.id,
              authorUid: currentUid,
            );
            publishedCount++;
          } catch (e) {
            // Log error nhưng tiếp tục với các posts khác
            print('Error publishing post ${post.id}: $e');
          }
        }
      }

      return publishedCount;
    } catch (e) {
      print('Error checking scheduled posts: $e');
      return 0;
    }
  }
}

