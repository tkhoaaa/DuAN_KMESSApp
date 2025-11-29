enum PostMediaFilter {
  all,
  images,
  videos,
}

enum TimeFilter {
  all,
  today,
  thisWeek,
  thisMonth,
}

enum PostSortOption {
  newest,
  mostLiked,
  mostCommented,
}

class FeedFilters {
  FeedFilters({
    this.mediaFilter = PostMediaFilter.all,
    this.timeFilter = TimeFilter.all,
    this.sortOption = PostSortOption.newest,
  });

  final PostMediaFilter mediaFilter;
  final TimeFilter timeFilter;
  final PostSortOption sortOption;

  /// Check if filters are at default values (no filters applied)
  bool get isDefault =>
      mediaFilter == PostMediaFilter.all &&
      timeFilter == TimeFilter.all &&
      sortOption == PostSortOption.newest;

  /// Create a copy with updated values
  FeedFilters copyWith({
    PostMediaFilter? mediaFilter,
    TimeFilter? timeFilter,
    PostSortOption? sortOption,
  }) {
    return FeedFilters(
      mediaFilter: mediaFilter ?? this.mediaFilter,
      timeFilter: timeFilter ?? this.timeFilter,
      sortOption: sortOption ?? this.sortOption,
    );
  }

  /// Reset to default values
  FeedFilters reset() {
    return FeedFilters();
  }

  /// Get start date for time filter
  DateTime? getStartDate() {
    final now = DateTime.now();
    switch (timeFilter) {
      case TimeFilter.all:
        return null;
      case TimeFilter.today:
        return DateTime(now.year, now.month, now.day);
      case TimeFilter.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(weekStart.year, weekStart.month, weekStart.day);
      case TimeFilter.thisMonth:
        return DateTime(now.year, now.month, 1);
    }
  }

  /// Get end date for time filter (always now)
  DateTime getEndDate() {
    return DateTime.now();
  }

  /// Get display name for media filter
  String getMediaFilterName() {
    switch (mediaFilter) {
      case PostMediaFilter.all:
        return 'Tất cả';
      case PostMediaFilter.images:
        return 'Chỉ ảnh';
      case PostMediaFilter.videos:
        return 'Chỉ video';
    }
  }

  /// Get display name for time filter
  String getTimeFilterName() {
    switch (timeFilter) {
      case TimeFilter.all:
        return 'Tất cả';
      case TimeFilter.today:
        return 'Hôm nay';
      case TimeFilter.thisWeek:
        return 'Tuần này';
      case TimeFilter.thisMonth:
        return 'Tháng này';
    }
  }

  /// Get display name for sort option
  String getSortOptionName() {
    switch (sortOption) {
      case PostSortOption.newest:
        return 'Mới nhất';
      case PostSortOption.mostLiked:
        return 'Nhiều like nhất';
      case PostSortOption.mostCommented:
        return 'Nhiều comment nhất';
    }
  }
}

