import '../../posts/models/post.dart';
import '../../posts/repositories/post_repository.dart';
import '../../profile/user_profile_repository.dart';

class SearchService {
  SearchService({
    UserProfileRepository? profileRepository,
    PostRepository? postRepository,
  })  : _profileRepository = profileRepository ?? userProfileRepository,
        _postRepository = postRepository ?? PostRepository();

  final UserProfileRepository _profileRepository;
  final PostRepository _postRepository;

  /// Chuẩn hóa input search (trim, lowercase)
  String normalizeQuery(String query) {
    return query.trim().toLowerCase();
  }

  /// Tìm kiếm users
  Future<List<UserProfile>> searchUsers({
    required String query,
    int limit = 20,
  }) async {
    final normalized = normalizeQuery(query);
    if (normalized.isEmpty) return [];
    return _profileRepository.searchUsers(query: normalized, limit: limit);
  }

  /// Tìm kiếm posts
  Future<List<Post>> searchPosts({
    required String query,
    int limit = 20,
  }) async {
    final normalized = normalizeQuery(query);
    if (normalized.isEmpty) return [];
    return _postRepository.searchPosts(query: normalized, limit: limit);
  }
}

