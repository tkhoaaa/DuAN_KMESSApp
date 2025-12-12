import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../follow/models/follow_state.dart';
import '../../follow/services/follow_service.dart';
import '../../posts/models/post.dart';
import '../../posts/models/post_media.dart';
import '../../posts/models/feed_filters.dart';
import '../../posts/pages/post_permalink_page.dart';
import '../../profile/public_profile_page.dart';
import '../../profile/user_profile_repository.dart';
import '../services/search_service.dart';
import '../models/user_search_filters.dart';
import '../models/search_history.dart';
import '../repositories/search_history_repository.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/inputs/rounded_text_field.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  final SearchService _searchService = SearchService();
  final FollowService _followService = FollowService();
  final SearchHistoryRepository _searchHistoryRepository =
      SearchHistoryRepository();
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;

  Timer? _debounceTimer;
  List<UserProfile> _userResults = [];
  List<Post> _postResults = [];
  bool _isSearchingUsers = false;
  bool _isSearchingPosts = false;
  String _currentQuery = '';
  UserSearchFilters _userFilters = UserSearchFilters();
  FeedFilters _postFilters = FeedFilters();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _userResults = [];
        _postResults = [];
        _currentQuery = '';
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _currentQuery = query;
      _isSearchingUsers = true;
      _isSearchingPosts = true;
    });

    final currentUid = authRepository.currentUser()?.uid;

    // Tìm kiếm users với filters
    final userResults = await _searchService.searchUsersWithFilters(
      query: query,
      filters: _userFilters.isDefault ? null : _userFilters,
      limit: 20,
      checkFollowing: currentUid != null
          ? (uid) async {
              try {
                final state = await _followService.watchFollowState(currentUid, uid).first;
                return state.status == FollowStatus.following;
              } catch (e) {
                return false;
              }
            }
          : null,
    );

    // Tìm kiếm posts với filters
    List<Post> postResults = [];
    if (_postFilters.isDefault) {
      postResults = await _searchService.searchPosts(query: query, limit: 20);
    } else {
      // Apply filters cho posts search (client-side filter)
      final allPosts = await _searchService.searchPosts(query: query, limit: 50);
      postResults = _applyPostFilters(allPosts);
    }

    if (!mounted) return;

    setState(() {
      _userResults = userResults;
      _postResults = postResults;
      _isSearchingUsers = false;
      _isSearchingPosts = false;
    });

    // Lưu lịch sử tìm kiếm
    if (currentUid != null && query.trim().isNotEmpty) {
      // Lưu lịch sử cho cả user và post search
      _searchHistoryRepository.saveSearchHistory(
        uid: currentUid,
        query: query,
        searchType: 'user',
      );
      _searchHistoryRepository.saveSearchHistory(
        uid: currentUid,
        query: query,
        searchType: 'post',
      );
    }
  }

  List<Post> _applyPostFilters(List<Post> posts) {
    var filtered = posts;

    // Apply media filter
    switch (_postFilters.mediaFilter) {
      case PostMediaFilter.all:
        break;
      case PostMediaFilter.images:
        filtered = filtered.where((p) => p.media.any((m) => m.type == PostMediaType.image)).toList();
        break;
      case PostMediaFilter.videos:
        filtered = filtered.where((p) => p.media.any((m) => m.type == PostMediaType.video)).toList();
        break;
    }

    // Apply time filter
    final startDate = _postFilters.getStartDate();
    if (startDate != null) {
      filtered = filtered.where((p) {
        if (p.createdAt == null) return false;
        return p.createdAt!.isAfter(startDate) || p.createdAt!.isAtSameMomentAs(startDate);
      }).toList();
    }

    // Apply sort
    switch (_postFilters.sortOption) {
      case PostSortOption.newest:
        filtered.sort((a, b) {
          final aTime = a.createdAt ?? DateTime(1970);
          final bTime = b.createdAt ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });
        break;
      case PostSortOption.mostLiked:
        filtered.sort((a, b) => b.likeCount.compareTo(a.likeCount));
        break;
      case PostSortOption.mostCommented:
        filtered.sort((a, b) => b.commentCount.compareTo(a.commentCount));
        break;
    }

    return filtered.take(20).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: RoundedTextField(
            controller: _searchController,
            hintText: 'Tìm kiếm người dùng hoặc bài viết...',
            prefixIcon: const Icon(Icons.search, color: AppColors.primaryPink),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                _performSearch(value.trim());
              }
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: AppColors.primaryPink),
            tooltip: 'Lọc',
            onPressed: () {
              _showFilterDialog();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryPink,
          labelColor: AppColors.primaryPink,
          unselectedLabelColor: AppColors.textLight,
          labelStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Người dùng'),
            Tab(text: 'Bài viết'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersTab(),
          _buildPostsTab(),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_currentQuery.isEmpty) {
      return _buildSearchHistory(searchType: 'user');
    }

    return Column(
      children: [
        if (!_userFilters.isDefault)
          _buildUserFilterChips(),
        Expanded(
          child: _isSearchingUsers
              ? const Center(child: CircularProgressIndicator())
              : _userResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_search, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'Không tìm thấy người dùng nào với từ khóa "$_currentQuery"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _userResults.length,
                      itemBuilder: (context, index) {
                        final profile = _userResults[index];
                        return _UserResultTile(
                          profile: profile,
                          followService: _followService,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PublicProfilePage(uid: profile.uid),
                              ),
                            );
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildPostsTab() {
    if (_currentQuery.isEmpty) {
      return _buildSearchHistory(searchType: 'post');
    }

    return Column(
      children: [
        if (!_postFilters.isDefault)
          _buildPostFilterChips(),
        Expanded(
          child: _isSearchingPosts
              ? const Center(child: CircularProgressIndicator())
              : _postResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'Không tìm thấy bài viết nào với từ khóa "$_currentQuery"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: _postResults.length,
                      itemBuilder: (context, index) {
                        final post = _postResults[index];
                        return _PostGridItem(
                          post: post,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PostPermalinkPage(postId: post.id),
                              ),
                            );
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildUserFilterChips() {
    final chips = <Widget>[];
    if (_userFilters.followStatus != UserSearchFilter.all) {
      chips.add(_buildFilterChip(
        label: _userFilters.getFollowStatusName(),
        onDeleted: () {
          setState(() {
            _userFilters = _userFilters.copyWith(followStatus: UserSearchFilter.all);
          });
          if (_currentQuery.isNotEmpty) {
            _performSearch(_currentQuery);
          }
        },
      ));
    }
    if (_userFilters.privacyFilter != PrivacyFilter.all) {
      chips.add(_buildFilterChip(
        label: _userFilters.getPrivacyFilterName(),
        onDeleted: () {
          setState(() {
            _userFilters = _userFilters.copyWith(privacyFilter: PrivacyFilter.all);
          });
          if (_currentQuery.isNotEmpty) {
            _performSearch(_currentQuery);
          }
        },
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: chips),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _userFilters = _userFilters.reset();
              });
              if (_currentQuery.isNotEmpty) {
                _performSearch(_currentQuery);
              }
            },
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );
  }

  Widget _buildPostFilterChips() {
    final chips = <Widget>[];
    if (_postFilters.mediaFilter != PostMediaFilter.all) {
      chips.add(_buildFilterChip(
        label: _postFilters.getMediaFilterName(),
        onDeleted: () {
          setState(() {
            _postFilters = _postFilters.copyWith(mediaFilter: PostMediaFilter.all);
          });
          if (_currentQuery.isNotEmpty) {
            _performSearch(_currentQuery);
          }
        },
      ));
    }
    if (_postFilters.timeFilter != TimeFilter.all) {
      chips.add(_buildFilterChip(
        label: _postFilters.getTimeFilterName(),
        onDeleted: () {
          setState(() {
            _postFilters = _postFilters.copyWith(timeFilter: TimeFilter.all);
          });
          if (_currentQuery.isNotEmpty) {
            _performSearch(_currentQuery);
          }
        },
      ));
    }
    if (_postFilters.sortOption != PostSortOption.newest) {
      chips.add(_buildFilterChip(
        label: _postFilters.getSortOptionName(),
        onDeleted: () {
          setState(() {
            _postFilters = _postFilters.copyWith(sortOption: PostSortOption.newest);
          });
          if (_currentQuery.isNotEmpty) {
            _performSearch(_currentQuery);
          }
        },
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: chips),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _postFilters = _postFilters.reset();
              });
              if (_currentQuery.isNotEmpty) {
                _performSearch(_currentQuery);
              }
            },
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onDeleted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(label),
        onDeleted: onDeleted,
        deleteIcon: const Icon(Icons.close, size: 18),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lọc kết quả'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (_tabController.index == 0) ...[
                // User filters
                const Text('Trạng thái follow:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...UserSearchFilter.values.map((filter) {
                  return RadioListTile<UserSearchFilter>(
                    title: Text(_getUserFilterName(filter)),
                    value: filter,
                    groupValue: _userFilters.followStatus,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _userFilters = _userFilters.copyWith(followStatus: value);
                        });
                      }
                    },
                  );
                }),
                const SizedBox(height: 16),
                const Text('Quyền riêng tư:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...PrivacyFilter.values.map((filter) {
                  return RadioListTile<PrivacyFilter>(
                    title: Text(_getPrivacyFilterName(filter)),
                    value: filter,
                    groupValue: _userFilters.privacyFilter,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _userFilters = _userFilters.copyWith(privacyFilter: value);
                        });
                      }
                    },
                  );
                }),
              ] else ...[
                // Post filters
                const Text('Loại media:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...PostMediaFilter.values.map((filter) {
                  return RadioListTile<PostMediaFilter>(
                    title: Text(_getPostMediaFilterName(filter)),
                    value: filter,
                    groupValue: _postFilters.mediaFilter,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _postFilters = _postFilters.copyWith(mediaFilter: value);
                        });
                      }
                    },
                  );
                }),
                const SizedBox(height: 16),
                const Text('Sắp xếp:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...PostSortOption.values.map((option) {
                  return RadioListTile<PostSortOption>(
                    title: Text(_getPostSortOptionName(option)),
                    value: option,
                    groupValue: _postFilters.sortOption,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _postFilters = _postFilters.copyWith(sortOption: value);
                        });
                      }
                    },
                  );
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                if (_tabController.index == 0) {
                  _userFilters = _userFilters.reset();
                } else {
                  _postFilters = _postFilters.reset();
                }
              });
              Navigator.of(context).pop();
              if (_currentQuery.isNotEmpty) {
                _performSearch(_currentQuery);
              }
            },
            child: const Text('Đặt lại'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (_currentQuery.isNotEmpty) {
                _performSearch(_currentQuery);
              }
            },
            child: const Text('Áp dụng'),
          ),
        ],
      ),
    );
  }

  String _getUserFilterName(UserSearchFilter filter) {
    switch (filter) {
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

  String _getPrivacyFilterName(PrivacyFilter filter) {
    switch (filter) {
      case PrivacyFilter.all:
        return 'Tất cả';
      case PrivacyFilter.public:
        return 'Công khai';
      case PrivacyFilter.private:
        return 'Riêng tư';
    }
  }

  String _getPostMediaFilterName(PostMediaFilter filter) {
    switch (filter) {
      case PostMediaFilter.all:
        return 'Tất cả';
      case PostMediaFilter.images:
        return 'Chỉ ảnh';
      case PostMediaFilter.videos:
        return 'Chỉ video';
    }
  }

  String _getPostSortOptionName(PostSortOption option) {
    switch (option) {
      case PostSortOption.newest:
        return 'Mới nhất';
      case PostSortOption.mostLiked:
        return 'Nhiều like nhất';
      case PostSortOption.mostCommented:
        return 'Nhiều comment nhất';
    }
  }

  Widget _buildSearchHistory({required String searchType}) {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) {
      return const Center(
        child: Text('Vui lòng đăng nhập để xem lịch sử tìm kiếm'),
      );
    }

    return StreamBuilder<List<SearchHistory>>(
      stream: _searchHistoryRepository.watchSearchHistory(
        uid: currentUid,
        searchType: searchType,
        limit: 20,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  searchType == 'user'
                      ? Icons.person_search
                      : Icons.search_off,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  searchType == 'user'
                      ? 'Nhập từ khóa để tìm kiếm người dùng...'
                      : 'Nhập từ khóa để tìm kiếm bài viết...',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lịch sử tìm kiếm',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _searchHistoryRepository.clearSearchHistory(
                        uid: currentUid,
                        searchType: searchType,
                      );
                    },
                    child: const Text('Xóa tất cả'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  return ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(item.query),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () async {
                        await _searchHistoryRepository.deleteSearchHistory(
                          uid: currentUid,
                          historyId: item.id,
                        );
                      },
                    ),
                    onTap: () {
                      _searchController.text = item.query;
                      _performSearch(item.query);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UserResultTile extends StatelessWidget {
  const _UserResultTile({
    required this.profile,
    required this.followService,
    required this.onTap,
  });

  final UserProfile profile;
  final FollowService followService;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = profile.displayName?.isNotEmpty == true
        ? profile.displayName!
        : (profile.email?.isNotEmpty == true ? profile.email! : profile.uid);

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: profile.photoUrl != null
            ? NetworkImage(profile.photoUrl!)
            : null,
        child: profile.photoUrl == null
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(displayName),
      subtitle: profile.email != null && profile.email != displayName
          ? Text(profile.email!)
          : null,
      trailing: _buildFollowButton(context),
      onTap: onTap,
    );
  }

  Widget _buildFollowButton(BuildContext context) {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null || currentUid == profile.uid) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<FollowState>(
      stream: followService.watchFollowState(currentUid, profile.uid),
      builder: (context, snapshot) {
        final state = snapshot.data ??
            const FollowState(status: FollowStatus.none, isTargetPrivate: false);
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final status = state.status;

        if (status == FollowStatus.following) {
          return OutlinedButton(
            onPressed: isLoading
                ? null
                : () async {
                    try {
                      await followService.unfollow(profile.uid);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi: $e')),
                        );
                      }
                    }
                  },
            child: const Text('Đang theo dõi'),
          );
        } else if (status == FollowStatus.requested) {
          return OutlinedButton(
            onPressed: null,
            child: const Text('Đã gửi yêu cầu'),
          );
        } else {
          return FilledButton(
            onPressed: isLoading
                ? null
                : () async {
                    try {
                      final result =
                          await followService.followUser(profile.uid);
                      if (!context.mounted) return;
                      switch (result) {
                        case FollowStatus.requested:
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Đã gửi yêu cầu theo dõi. Chờ phê duyệt.'),
                            ),
                          );
                          break;
                        case FollowStatus.following:
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đang theo dõi người này.'),
                            ),
                          );
                          break;
                        case FollowStatus.self:
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đây là tài khoản của bạn.'),
                            ),
                          );
                          break;
                        case FollowStatus.none:
                          break;
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi: $e')),
                        );
                      }
                    }
                  },
            child: const Text('Theo dõi'),
          );
        }
      },
    );
  }
}

class _PostGridItem extends StatelessWidget {
  const _PostGridItem({
    required this.post,
    required this.onTap,
  });

  final Post post;
  final VoidCallback onTap;

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

