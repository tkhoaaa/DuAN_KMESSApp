enum UserSearchFilter {
  all,
  following,
  notFollowing,
  followRequest,
}

enum PrivacyFilter {
  all,
  public,
  private,
}

class UserSearchFilters {
  UserSearchFilters({
    this.followStatus = UserSearchFilter.all,
    this.privacyFilter = PrivacyFilter.all,
  });

  final UserSearchFilter followStatus;
  final PrivacyFilter privacyFilter;

  /// Check if filters are at default values (no filters applied)
  bool get isDefault =>
      followStatus == UserSearchFilter.all &&
      privacyFilter == PrivacyFilter.all;

  /// Create a copy with updated values
  UserSearchFilters copyWith({
    UserSearchFilter? followStatus,
    PrivacyFilter? privacyFilter,
  }) {
    return UserSearchFilters(
      followStatus: followStatus ?? this.followStatus,
      privacyFilter: privacyFilter ?? this.privacyFilter,
    );
  }

  /// Reset to default values
  UserSearchFilters reset() {
    return UserSearchFilters();
  }

  /// Get display name for follow status filter
  String getFollowStatusName() {
    switch (followStatus) {
      case UserSearchFilter.all:
        return 'Tất cả';
      case UserSearchFilter.following:
        return 'Đang follow';
      case UserSearchFilter.notFollowing:
        return 'Chưa follow';
      case UserSearchFilter.followRequest:
        return 'Follow request';
    }
  }

  /// Get display name for privacy filter
  String getPrivacyFilterName() {
    switch (privacyFilter) {
      case PrivacyFilter.all:
        return 'Tất cả';
      case PrivacyFilter.public:
        return 'Công khai';
      case PrivacyFilter.private:
        return 'Riêng tư';
    }
  }
}

