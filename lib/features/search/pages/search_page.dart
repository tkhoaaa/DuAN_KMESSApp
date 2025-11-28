import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../follow/models/follow_state.dart';
import '../../follow/models/follow_state.dart' as follow_models;
import '../../follow/services/follow_service.dart';
import '../../posts/models/post.dart';
import '../../posts/models/post_media.dart';
import '../../posts/pages/post_permalink_page.dart';
import '../../profile/public_profile_page.dart';
import '../../profile/user_profile_repository.dart';
import '../services/search_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  final SearchService _searchService = SearchService();
  final FollowService _followService = FollowService();
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;

  Timer? _debounceTimer;
  List<UserProfile> _userResults = [];
  List<Post> _postResults = [];
  bool _isSearchingUsers = false;
  bool _isSearchingPosts = false;
  String _currentQuery = '';

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

    // Tìm kiếm users và posts song song
    final results = await Future.wait([
      _searchService.searchUsers(query: query, limit: 20),
      _searchService.searchPosts(query: query, limit: 20),
    ]);

    if (!mounted) return;

    setState(() {
      _userResults = results[0] as List<UserProfile>;
      _postResults = results[1] as List<Post>;
      _isSearchingUsers = false;
      _isSearchingPosts = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Tìm kiếm người dùng hoặc bài viết...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              _performSearch(value.trim());
            }
          },
        ),
        bottom: TabBar(
          controller: _tabController,
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
      return const Center(
        child: Text('Nhập từ khóa để tìm kiếm người dùng...'),
      );
    }

    if (_isSearchingUsers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userResults.isEmpty) {
      return Center(
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
      );
    }

    return ListView.builder(
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
    );
  }

  Widget _buildPostsTab() {
    if (_currentQuery.isEmpty) {
      return const Center(
        child: Text('Nhập từ khóa để tìm kiếm bài viết...'),
      );
    }

    if (_isSearchingPosts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_postResults.isEmpty) {
      return Center(
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
      );
    }

    return GridView.builder(
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

