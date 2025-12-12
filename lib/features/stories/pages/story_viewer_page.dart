import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../auth/auth_repository.dart';
import '../../profile/user_profile_repository.dart';
import '../models/story.dart';
import '../repositories/story_repository.dart';
import '../../../theme/colors.dart';

/// Page hiển thị story với progress bar, video player, và swipe gestures
class StoryViewerPage extends StatefulWidget {
  const StoryViewerPage({
    super.key,
    required this.initialAuthorUid,
    this.userIdsWithStories,
  });

  /// UID của user có story đầu tiên được hiển thị
  final String initialAuthorUid;

  /// Danh sách UIDs của các users có story (bao gồm chính mình và người theo dõi)
  /// Nếu null, sẽ chỉ hiển thị story của initialAuthorUid
  final List<String>? userIdsWithStories;

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> {
  final StoryRepository _storyRepository = StoryRepository();
  final PageController _userPageController = PageController();
  final PageController _storyPageController = PageController();
  
  List<String> _userIds = [];
  int _currentUserIndex = 0;
  int _currentStoryIndex = 0;
  List<Story> _currentStories = [];
  
  VideoPlayerController? _videoController;
  Timer? _progressTimer;
  double _progress = 0.0;
  bool _isPaused = false;
  bool _isInitialized = false;

  static const Duration _storyDuration = Duration(seconds: 60); // 1 phút
  static const Duration _progressUpdateInterval = Duration(milliseconds: 50);

  @override
  void initState() {
    super.initState();
    _initializeUsers();
  }

  void _initializeUsers() {
    if (widget.userIdsWithStories != null) {
      _userIds = List.from(widget.userIdsWithStories!);
      // Đảm bảo initialAuthorUid ở đầu danh sách
      _userIds.remove(widget.initialAuthorUid);
      _userIds.insert(0, widget.initialAuthorUid);
    } else {
      _userIds = [widget.initialAuthorUid];
    }
    
    // Tìm index của initialAuthorUid
    _currentUserIndex = _userIds.indexOf(widget.initialAuthorUid);
    if (_currentUserIndex == -1) _currentUserIndex = 0;
    
    _loadStoriesForCurrentUser();
  }

  void _loadStoriesForCurrentUser() {
    if (_currentUserIndex >= _userIds.length) {
      // Đã hết tất cả users, đóng page
      _closeStoryViewer();
      return;
    }
    
    final currentUserId = _userIds[_currentUserIndex];
    _storyRepository.watchUserStories(currentUserId).listen((stories) {
      if (!mounted) return;
      
      setState(() {
        _currentStories = stories;
        if (_currentStoryIndex >= stories.length) {
          _currentStoryIndex = 0;
        }
      });
      
      if (stories.isNotEmpty && !_isInitialized) {
        _isInitialized = true;
        _loadCurrentStory();
      } else if (stories.isEmpty) {
        // Nếu user này không có story, chuyển sang user tiếp theo
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _nextUser();
        });
      }
    });
  }

  void _loadCurrentStory() {
    if (_currentStoryIndex >= _currentStories.length) {
      _nextStory();
      return;
    }

    final story = _currentStories[_currentStoryIndex];
    _disposeVideoController();
    _progress = 0.0;
    _isPaused = false;

    // Ghi nhận viewer
    final currentUser = authRepository.currentUser();
    if (currentUser != null) {
      _storyRepository
          .addViewer(
            authorUid: _userIds[_currentUserIndex],
            storyId: story.id,
            viewerUid: currentUser.uid,
          )
          .catchError((_) {});
    }

    if (story.type == StoryMediaType.video) {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(story.mediaUrl),
      );
      _videoController!.initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoController!.play();
          _startProgressTimer();
        }
      }).catchError((e) {
        debugPrint('Error loading video: $e');
        // Nếu video lỗi, tự động chuyển sang story tiếp theo sau 1 giây
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _nextStory();
        });
      });
    } else {
      // Ảnh: tự động chuyển sau 1 phút
      _startProgressTimer();
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(_progressUpdateInterval, (timer) {
      if (!mounted || _isPaused) return;

      setState(() {
        if (_videoController != null && _videoController!.value.isInitialized) {
          // Video: dùng duration thực tế của video hoặc 1 phút, tùy cái nào ngắn hơn
          final videoDuration = _videoController!.value.duration;
          final maxDuration = videoDuration < _storyDuration 
              ? videoDuration 
              : _storyDuration;
          final currentPosition = _videoController!.value.position;
          _progress = currentPosition.inMilliseconds / maxDuration.inMilliseconds;
          
          // Nếu video đã phát xong hoặc đạt 1 phút, chuyển story
          if (currentPosition >= maxDuration || 
              _videoController!.value.isCompleted) {
            timer.cancel();
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) _nextStory();
            });
            return;
          }
        } else {
          // Ảnh: tăng progress theo thời gian
          _progress += _progressUpdateInterval.inMilliseconds / _storyDuration.inMilliseconds;
          if (_progress >= 1.0) {
            timer.cancel();
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) _nextStory();
            });
            return;
          }
        }
      });
    });
  }

  void _nextStory() {
    if (!mounted) return;
    
    if (_currentStoryIndex < _currentStories.length - 1) {
      setState(() {
        _currentStoryIndex++;
      });
      _storyPageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _loadCurrentStory();
    } else {
      // Hết story của user hiện tại, chuyển sang user tiếp theo
      _nextUser();
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
      _storyPageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _loadCurrentStory();
    } else {
      _previousUser();
    }
  }

  void _nextUser() {
    if (!mounted) return;
    
    if (_currentUserIndex < _userIds.length - 1) {
      setState(() {
        _currentUserIndex++;
        _currentStoryIndex = 0;
        _isInitialized = false;
      });
      _userPageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _loadStoriesForCurrentUser();
    } else {
      // Đã hết tất cả users, đóng page và quay về feed
      _closeStoryViewer();
    }
  }
  
  void _closeStoryViewer() {
    if (!mounted) return;
    
    // Đảm bảo dispose tất cả resources trước khi đóng
    _progressTimer?.cancel();
    _progressTimer = null;
    _disposeVideoController();
    
    // Đảm bảo pop về feed
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _previousUser() {
    if (_currentUserIndex > 0) {
      setState(() {
        _currentUserIndex--;
        _currentStoryIndex = 0;
        _isInitialized = false;
      });
      _userPageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _loadStoriesForCurrentUser();
    } else {
      // Đã ở user đầu tiên, phát lại story đầu tiên
      setState(() {
        _currentStoryIndex = 0;
      });
      _storyPageController.jumpToPage(0);
      _loadCurrentStory();
    }
  }

  void _disposeVideoController() {
    _videoController?.dispose();
    _videoController = null;
  }

  @override
  void dispose() {
    // Đảm bảo dispose tất cả resources
    _progressTimer?.cancel();
    _progressTimer = null;
    _disposeVideoController();
    _userPageController.dispose();
    _storyPageController.dispose();
    super.dispose();
  }

  void _handleTap(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;
    
    if (tapX < screenWidth / 3) {
      // Tap bên trái: story trước hoặc user trước
      _previousStory();
    } else if (tapX > screenWidth * 2 / 3) {
      // Tap bên phải: story tiếp theo hoặc user tiếp theo
      _nextStory();
    } else {
      // Tap giữa: pause/resume
      setState(() {
        _isPaused = !_isPaused;
        if (_isPaused) {
          _videoController?.pause();
        } else {
          _videoController?.play();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userIds.isEmpty) {
    return Scaffold(
      backgroundColor: Colors.black,
        body: const Center(
                child: Text(
                  'Không có story nào',
                  style: TextStyle(color: Colors.white),
                ),
        ),
              );
            }

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.92),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Story content
            PageView.builder(
              controller: _userPageController,
              itemCount: _userIds.length,
              onPageChanged: (index) {
                setState(() {
                  _currentUserIndex = index;
                  _currentStoryIndex = 0;
                  _isInitialized = false;
                });
                _loadStoriesForCurrentUser();
              },
              itemBuilder: (context, userIndex) {
                if (userIndex != _currentUserIndex) {
                  // Preload stories cho user này
                  return const SizedBox.shrink();
                }
                
                if (_currentStories.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

            return PageView.builder(
                  controller: _storyPageController,
                  itemCount: _currentStories.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentStoryIndex = index;
                    });
                    _loadCurrentStory();
                  },
                  itemBuilder: (context, storyIndex) {
                    final story = _currentStories[storyIndex];
                    return GestureDetector(
                      onTapDown: _handleTap,
                      child: Stack(
                  fit: StackFit.expand,
                  children: [
                          // Media content
                    if (story.type == StoryMediaType.image)
                      Image.network(
                        story.mediaUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 48,
                            ),
                          );
                        },
                      )
                          else if (_videoController != null &&
                              _videoController!.value.isInitialized)
                      Center(
                              child: AspectRatio(
                                aspectRatio: _videoController!.value.aspectRatio,
                                child: VideoPlayer(_videoController!),
                              ),
                            )
                          else
                            const Center(
                              child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                            ),
                          
                          // Pause overlay
                          if (_isPaused)
                            Container(
                              color: Colors.black26,
                              child: const Center(
                                child: Icon(
                                  Icons.pause_circle_filled,
                                  color: Colors.white,
                                  size: 64,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            // Progress bars cho tất cả stories của user hiện tại
            if (_currentStories.isNotEmpty)
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Column(
                  children: [
                    Row(
                      children: List.generate(_currentStories.length, (index) {
                        return Expanded(
                          child: Container(
                            margin: EdgeInsets.only(
                              right: index < _currentStories.length - 1 ? 4 : 0,
                            ),
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.lightPink.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Stack(
                              children: [
                                if (index == _currentStoryIndex)
                                  FractionallySizedBox(
                                    widthFactor: _progress.clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: AppColors.storyPinkGradient,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  )
                                else if (index < _currentStoryIndex)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryPink,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    // User info
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            _closeStoryViewer();
                          },
                        ),
                        const SizedBox(width: 8),
                        FutureBuilder(
                          future: userProfileRepository.fetchProfile(
                            _userIds[_currentUserIndex],
                          ),
                          builder: (context, snapshot) {
                            final profile = snapshot.data;
                            return Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: profile?.photoUrl != null
                                      ? NetworkImage(profile!.photoUrl!)
                                      : null,
                                  child: profile?.photoUrl == null
                                      ? const Icon(Icons.person, size: 16)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  profile?.displayName ?? 
                                  _userIds[_currentUserIndex],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                      ),
                  ],
                ),
              ),

            // Text overlay (nếu có)
            if (_currentStories.isNotEmpty &&
                _currentStories[_currentStoryIndex].text != null &&
                _currentStories[_currentStoryIndex].text!.isNotEmpty)
                    Positioned(
                bottom: 32,
                      left: 16,
                      right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                            child: Text(
                    _currentStories[_currentStoryIndex].text!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
        ),
      ),
    );
  }
}
