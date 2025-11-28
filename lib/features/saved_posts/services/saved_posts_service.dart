import '../../auth/auth_repository.dart';
import '../models/saved_post.dart';
import '../repositories/saved_posts_repository.dart';

class SavedPostsService {
  SavedPostsService({SavedPostsRepository? repository})
      : _repository = repository ?? SavedPostsRepository();

  final SavedPostsRepository _repository;

  String? _currentUid() => authRepository.currentUser()?.uid;

  Stream<List<SavedPost>> watchMySavedPosts({int limit = 50}) {
    final uid = _currentUid();
    if (uid == null) return const Stream<List<SavedPost>>.empty();
    return _repository.watchSavedPosts(uid: uid, limit: limit);
  }

  Stream<bool> watchIsPostSaved(String postId) {
    final uid = _currentUid();
    if (uid == null) return const Stream<bool>.empty();
    return _repository.watchIsSaved(uid: uid, postId: postId);
  }

  Future<bool> isPostSaved(String postId) async {
    final uid = _currentUid();
    if (uid == null) return false;
    return _repository.isSaved(uid: uid, postId: postId);
  }

  static const String _postLinkScheme = 'kmessapp://posts';

  static String buildPostLink(String postId) {
    if (postId.isEmpty) return _postLinkScheme;
    return '$_postLinkScheme/$postId';
  }

  Future<void> savePost({
    required String postId,
    required String postOwnerUid,
    String? postUrl,
  }) async {
    final uid = _currentUid();
    if (uid == null) {
      throw StateError('Bạn cần đăng nhập để lưu bài viết.');
    }
    await _repository.savePost(
      uid: uid,
      postId: postId,
      postOwnerUid: postOwnerUid,
      postUrl: postUrl ?? buildPostLink(postId),
    );
  }

  Future<void> unsavePost(String postId) async {
    final uid = _currentUid();
    if (uid == null) {
      throw StateError('Bạn cần đăng nhập để bỏ lưu bài viết.');
    }
    await _repository.unsavePost(uid: uid, postId: postId);
  }

  Future<bool> toggleSaved({
    required String postId,
    required String postOwnerUid,
    String? postUrl,
  }) async {
    final uid = _currentUid();
    if (uid == null) {
      throw StateError('Bạn cần đăng nhập để lưu bài viết.');
    }
    final isSaved = await _repository.isSaved(uid: uid, postId: postId);
    if (isSaved) {
      await _repository.unsavePost(uid: uid, postId: postId);
      return false;
    } else {
      await _repository.savePost(
        uid: uid,
        postId: postId,
        postOwnerUid: postOwnerUid,
        postUrl: postUrl ?? buildPostLink(postId),
      );
      return true;
    }
  }

  Future<List<SavedPost>> fetchMySavedPosts({int limit = 20}) async {
    final uid = _currentUid();
    if (uid == null) return [];
    return _repository.fetchSavedPosts(uid: uid, limit: limit);
  }
}

final SavedPostsService savedPostsService = SavedPostsService();

