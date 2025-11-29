import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/post.dart';
import '../models/post_media.dart';
import '../repositories/post_repository.dart';
import '../../share/services/share_service.dart';
import 'post_permalink_page.dart';
import 'post_video_page.dart';
import '../../profile/public_profile_page.dart';
import '../../profile/user_profile_repository.dart';

class HashtagPage extends StatefulWidget {
  const HashtagPage({
    super.key,
    required this.hashtag,
  });

  final String hashtag;

  @override
  State<HashtagPage> createState() => _HashtagPageState();
}

class _HashtagPageState extends State<HashtagPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PostRepository _postRepository = PostRepository();
  final List<Post> _recentPosts = [];
  final List<Post> _hotPosts = [];
  bool _isLoadingRecent = true;
  bool _isLoadingHot = true;
  bool _hasMoreRecent = true;
  bool _hasMoreHot = true;
  DocumentSnapshot<Map<String, dynamic>>? _lastDocRecent;
  DocumentSnapshot<Map<String, dynamic>>? _lastDocHot;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRecentPosts();
    _loadHotPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentPosts({bool reset = false}) async {
    if (!_hasMoreRecent && !reset) return;
    
    setState(() {
      _isLoadingRecent = true;
      if (reset) {
        _recentPosts.clear();
        _lastDocRecent = null;
        _hasMoreRecent = true;
      }
    });

    try {
      // Fetch posts với pagination
      final result = await _postRepository.fetchPostsByHashtag(
        widget.hashtag,
        limit: 20,
        startAfter: _lastDocRecent,
        sortBy: 'createdAt',
      );

      if (mounted) {
        final posts = result.docs.map((doc) => Post.fromDoc(doc)).toList();
        setState(() {
          if (reset) {
            _recentPosts.clear();
          }
          _recentPosts.addAll(posts);
          _lastDocRecent = result.lastDoc;
          _hasMoreRecent = result.hasMore;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải bài viết: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRecent = false;
        });
      }
    }
  }

  Future<void> _loadHotPosts({bool reset = false}) async {
    if (!_hasMoreHot && !reset) return;
    
    setState(() {
      _isLoadingHot = true;
      if (reset) {
        _hotPosts.clear();
        _lastDocHot = null;
        _hasMoreHot = true;
      }
    });

    try {
      final result = await _postRepository.fetchPostsByHashtag(
        widget.hashtag,
        limit: 20,
        startAfter: _lastDocHot,
        sortBy: 'hot',
      );

      if (mounted) {
        final posts = result.docs.map((doc) => Post.fromDoc(doc)).toList();
        setState(() {
          if (reset) {
            _hotPosts.clear();
          }
          _hotPosts.addAll(posts);
          _lastDocHot = result.lastDoc;
          _hasMoreHot = result.hasMore;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải bài viết: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHot = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('#${widget.hashtag}'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.share),
            onSelected: (value) async {
              if (value == 'share') {
                await ShareService.shareHashtag(hashtag: widget.hashtag);
              } else if (value == 'copy') {
                await ShareService.copyHashtagLink(widget.hashtag);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép link')),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('Chia sẻ'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 8),
                    Text('Sao chép link'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Mới nhất'),
            Tab(text: 'Nổi bật'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecentTab(),
          _buildHotTab(),
        ],
      ),
    );
  }

  Widget _buildRecentTab() {
    if (_isLoadingRecent && _recentPosts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recentPosts.isEmpty) {
      return const Center(
        child: Text('Chưa có bài viết nào với hashtag này.'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadRecentPosts(reset: true),
      child: ListView.builder(
        itemCount: _recentPosts.length + (_hasMoreRecent ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _recentPosts.length) {
            // Load more indicator
            if (!_isLoadingRecent) {
              _loadRecentPosts();
            }
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _buildPostCard(_recentPosts[index]);
        },
      ),
    );
  }

  Widget _buildHotTab() {
    if (_isLoadingHot && _hotPosts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hotPosts.isEmpty) {
      return const Center(
        child: Text('Chưa có bài viết nào với hashtag này.'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadHotPosts(reset: true),
      child: ListView.builder(
        itemCount: _hotPosts.length + (_hasMoreHot ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _hotPosts.length) {
            // Load more indicator
            if (!_isLoadingHot) {
              _loadHotPosts();
            }
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _buildPostCard(_hotPosts[index]);
        },
      ),
    );
  }

  Widget _buildPostCard(Post post) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PostPermalinkPage(postId: post.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author info
            StreamBuilder<UserProfile?>(
              stream: userProfileRepository.watchProfile(post.authorUid),
              builder: (context, snapshot) {
                final profile = snapshot.data;
                final authorName = profile?.displayName ??
                    profile?.email ??
                    post.authorUid;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: profile?.photoUrl != null
                        ? NetworkImage(profile!.photoUrl!)
                        : null,
                    child: profile?.photoUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(authorName),
                  subtitle: post.createdAt != null
                      ? Text(
                          '${post.createdAt!.toLocal()}',
                          style: const TextStyle(fontSize: 12),
                        )
                      : null,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            PublicProfilePage(uid: post.authorUid),
                      ),
                    );
                  },
                );
              },
            ),
            // Media preview
            if (post.media.isNotEmpty)
              AspectRatio(
                aspectRatio: 1,
                child: _buildMediaPreview(post.media.first),
              ),
            // Caption
            if (post.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  post.caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            // Stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.favorite, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('${post.likeCount}'),
                  const SizedBox(width: 16),
                  Icon(Icons.comment, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('${post.commentCount}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(PostMedia media) {
    if (media.type == PostMediaType.image) {
      return Image.network(
        media.url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade300,
            child: const Icon(Icons.broken_image),
          );
        },
      );
    } else {
      return GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PostVideoPage(videoUrl: media.url),
            ),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (media.thumbnailUrl != null)
              Image.network(
                media.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(color: Colors.black87);
                },
              )
            else
              Container(color: Colors.black87),
            const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white,
                size: 48,
              ),
            ),
          ],
        ),
      );
    }
  }
}

