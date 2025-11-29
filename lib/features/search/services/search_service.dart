import '../../posts/models/post.dart';
import '../../posts/repositories/post_repository.dart';
import '../../profile/user_profile_repository.dart';
import '../models/user_search_filters.dart';

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

  /// Tìm kiếm users với filters
  Future<List<UserProfile>> searchUsersWithFilters({
    required String query,
    UserSearchFilters? filters,
    int limit = 20,
    Future<bool> Function(String)? checkFollowing,
  }) async {
    final normalized = normalizeQuery(query);
    if (normalized.isEmpty) return [];

    // Apply privacy filter
    bool? isPrivate;
    if (filters?.privacyFilter == PrivacyFilter.public) {
      isPrivate = false;
    } else if (filters?.privacyFilter == PrivacyFilter.private) {
      isPrivate = true;
    }

    // Get users with privacy filter
    final users = await _profileRepository.searchUsersWithFilters(
      query: normalized,
      limit: limit * 2, // Lấy nhiều hơn để filter follow status
      isPrivate: isPrivate,
    );

    // Apply follow status filter (client-side)
    if (filters?.followStatus != null && checkFollowing != null) {
      final followChecks = await Future.wait(
        users.map((user) => checkFollowing(user.uid)),
      );

      final filteredUsers = <UserProfile>[];
      for (int i = 0; i < users.length; i++) {
        final user = users[i];
        final isFollowing = followChecks[i];

        switch (filters!.followStatus) {
          case UserSearchFilter.all:
            filteredUsers.add(user);
            break;
          case UserSearchFilter.following:
            if (isFollowing) filteredUsers.add(user);
            break;
          case UserSearchFilter.notFollowing:
            if (!isFollowing) filteredUsers.add(user);
            break;
          case UserSearchFilter.followRequest:
            // TODO: Check follow request status
            filteredUsers.add(user);
            break;
        }
      }
      return filteredUsers.take(limit).toList();
    }

    return users.take(limit).toList();
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

