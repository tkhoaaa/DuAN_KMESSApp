import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../auth/auth_repository.dart';
import '../../profile/user_profile_repository.dart';
import '../models/story.dart';
import '../repositories/story_repository.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../posts/pages/post_video_page.dart';

class StoryArchivePage extends StatefulWidget {
  const StoryArchivePage({super.key});

  @override
  State<StoryArchivePage> createState() => _StoryArchivePageState();
}

class _StoryArchivePageState extends State<StoryArchivePage>
    with SingleTickerProviderStateMixin {
  final StoryRepository _storyRepository = StoryRepository();
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();

  String? get _uid => authRepository.currentUser()?.uid;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Bạn cần đăng nhập để xem kho lưu trữ.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Kho lưu trữ Story',
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryPink,
          ),
        ),
      ),
      body: StreamBuilder<List<Story>>(
        stream: _storyRepository.watchUserStoryArchive(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerLoading();
          }

          final stories = snapshot.data ?? [];
          if (stories.isEmpty) {
            return _buildEmptyState();
          }

          return StreamBuilder<UserProfile?>(
            stream: userProfileRepository.watchProfile(uid),
            builder: (context, profileSnap) {
              final profile = profileSnap.data;
              final pinned = profile?.pinnedStoryIds ?? const <String>[];

              return CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                  final story = stories[index];
                  final isPinned = pinned.contains(story.id);
                          return _buildStoryCard(
                            story: story,
                            index: index,
                            isPinned: isPinned,
                            uid: uid,
                          );
                        },
                        childCount: stories.length,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStoryCard({
    required Story story,
    required int index,
    required bool isPinned,
    required String uid,
  }) {
    final animationDelay = index * 0.1;
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          animationDelay.clamp(0.0, 0.8),
          1.0,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (animation.value * 0.2),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: _StoryCard(
        story: story,
        isPinned: isPinned,
        uid: uid,
        onRepost: () => _handleRepost(story, uid),
        onPin: () => _handlePin(story.id, uid, isPinned),
        onView: () => _handleView(story),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _ShimmerCard(),
              childCount: 6,
                                        ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.storyPinkGradient,
                                          ),
              child: const Icon(
                Icons.photo_library_outlined,
                size: 60,
                color: Colors.white,
              ),
                                      ),
                              ),
          const SizedBox(height: 24),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: child,
              );
            },
                                child: Column(
                                  children: [
                                    Text(
                  'Chưa có story trong kho lưu trữ',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                                    ),
                const SizedBox(height: 8),
                                    Text(
                  'Các story của bạn sẽ được lưu trữ ở đây',
                  style: AppTypography.small.copyWith(
                    color: AppColors.textLight,
                                    ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                                      ),
                                    );
                                  }

  Future<void> _handleRepost(Story story, String uid) async {
                                  try {
                                    await _storyRepository.repostStory(authorUid: uid, story: story);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã đăng lại story'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi đăng lại: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _handlePin(String storyId, String uid, bool isPinned) async {
    if (isPinned) return;
                                        try {
      await userProfileRepository.addPinnedStory(uid, storyId);
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã ghim story lên hồ sơ'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
                                          );
                                        } catch (e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi ghim: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
                                          );
                                        }
  }

  void _handleView(Story story) {
    if (story.type == StoryMediaType.video) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              PostVideoPage(videoUrl: story.mediaUrl),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => _ImageViewer(
            imageUrl: story.mediaUrl,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }
}

class _StoryCard extends StatefulWidget {
  const _StoryCard({
    required this.story,
    required this.isPinned,
    required this.uid,
    required this.onRepost,
    required this.onPin,
    required this.onView,
  });

  final Story story;
  final bool isPinned;
  final String uid;
  final VoidCallback onRepost;
  final VoidCallback onPin;
  final VoidCallback onView;

  @override
  State<_StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends State<_StoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final isExpired = widget.story.expiresAt.isBefore(DateTime.now());

    return GestureDetector(
      onTap: widget.onView,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        builder: (context, hoverValue, child) {
          return Transform.scale(
            scale: 1.0 + (hoverValue * 0.02),
            child: child,
          );
        },
        child: Card(
          elevation: _isHovered ? 8 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media content
              Hero(
                tag: 'story_${widget.story.id}',
                child: widget.story.type == StoryMediaType.image
                    ? Image.network(
                        widget.story.mediaUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.broken_image,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            widget.story.thumbnailUrl ?? widget.story.mediaUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.videocam,
                                size: 40,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                            ],
                              ),
                            ),
                          ),
                          const Center(
                            child: Icon(
                              Icons.play_circle_filled,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),

              // Gradient overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Text preview
                      if (widget.story.text?.isNotEmpty == true)
                        Text(
                          widget.story.text!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      const SizedBox(height: 6),
                      // Date
                      Text(
                        dateFormat.format(widget.story.createdAt),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Pinned badge
              if (widget.isPinned)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.push_pin,
                          size: 12,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Đã ghim',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Expired badge
              if (isExpired)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Đã hết hạn',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              // Action buttons overlay
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onView,
                    onLongPress: () => _showActionMenu(context),
                  ),
                ),
              ),
            ],
          ),
                      ),
                    ),
                  );
  }

  void _showActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.visibility, color: AppColors.primaryPink),
                title: const Text('Xem story'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onView();
                },
              ),
              ListTile(
                leading: const Icon(Icons.repeat, color: AppColors.primaryPink),
                title: const Text('Đăng lại'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onRepost();
                },
              ),
              if (!widget.isPinned)
                ListTile(
                  leading: const Icon(Icons.push_pin, color: AppColors.primaryPink),
                  title: const Text('Ghim lên hồ sơ'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onPin();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment(-1.0 - _controller.value * 2, 0.0),
              end: Alignment(1.0 - _controller.value * 2, 0.0),
              colors: [
                Colors.grey.shade200,
                Colors.grey.shade100,
                Colors.grey.shade200,
              ],
            ),
          ),
              );
            },
          );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Không tải được ảnh',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
