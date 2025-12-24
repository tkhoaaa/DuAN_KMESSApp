import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../notifications/services/notification_service.dart';
import '../../chat/pages/chat_detail_page.dart';

import '../../auth/auth_repository.dart';
import '../../profile/user_profile_repository.dart';
import '../../profile/pages/manage_highlight_stories_page.dart';
import '../../follow/services/follow_service.dart';
import '../../chat/repositories/chat_repository.dart';
import '../../chat/models/message_attachment.dart';
import '../models/story.dart';
import '../repositories/story_repository.dart';
import '../pages/story_create_page.dart';
import '../../../theme/colors.dart';

/// Page hiển thị story với progress bar, video player, và swipe gestures
class StoryViewerPage extends StatefulWidget {
  const StoryViewerPage({
    super.key,
    required this.initialAuthorUid,
    this.userIdsWithStories,
    this.initialStoryIds,
    this.highlightId,
  });

  /// UID của user có story đầu tiên được hiển thị
  final String initialAuthorUid;

  /// Danh sách UIDs của các users có story (bao gồm chính mình và người theo dõi)
  /// Nếu null, sẽ chỉ hiển thị story của initialAuthorUid
  final List<String>? userIdsWithStories;

  /// Danh sách story IDs để hiển thị (dùng cho highlight stories)
  final List<String>? initialStoryIds;

  /// ID của highlight story (nếu đang xem từ highlight)
  final String? highlightId;

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> {
  final StoryRepository _storyRepository = StoryRepository();
  final ChatRepository _chatRepository = ChatRepository();
  final NotificationService _notificationService = NotificationService();
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
  StreamSubscription<List<Story>>? _storiesSub;
  bool _isCurrentStoryLiked = false;

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
    // Hủy subscription cũ nếu có để tránh nhiều listener gây lag
    _storiesSub?.cancel();

    // Nếu đang xem từ Highlight (chỉ 1 user), dùng kho lưu trữ (bao gồm cả story đã hết hạn)
    final Stream<List<Story>> stream;
    if (widget.initialStoryIds != null && currentUserId == widget.initialAuthorUid) {
      stream = _storyRepository.watchUserStoryArchive(currentUserId);
    } else {
      // Mặc định: chỉ xem stories còn hạn
      stream = _storyRepository.watchUserStories(currentUserId);
    }

    _storiesSub = stream.listen((stories) {
      if (!mounted) return;
      
      // Filter stories theo initialStoryIds nếu có (dùng cho highlight stories)
      List<Story> filteredStories;
      if (widget.initialStoryIds != null && currentUserId == widget.initialAuthorUid) {
        // Giữ đúng thứ tự theo storyIds trong Highlight
        final byId = {for (final s in stories) s.id: s};
        filteredStories = widget.initialStoryIds!
            .map((id) => byId[id])
            .whereType<Story>()
            .toList();
      } else {
        filteredStories = stories;
      }
      
      setState(() {
        _currentStories = filteredStories;
        if (_currentStoryIndex >= filteredStories.length) {
          _currentStoryIndex = 0;
        }
      });
      
      if (filteredStories.isNotEmpty && !_isInitialized) {
        _isInitialized = true;
        _loadCurrentStory();
      } else if (filteredStories.isEmpty) {
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
          _updateLikeStateForCurrentStory();
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
      _updateLikeStateForCurrentStory();
    }
  }

  Future<void> _updateLikeStateForCurrentStory() async {
    final currentUser = authRepository.currentUser();
    if (currentUser == null || _currentStories.isEmpty) return;

    final story = _currentStories[_currentStoryIndex];
    // Cho phép tác giả tự tim story của mình
    try {
      final liked = await _storyRepository.isStoryLikedByUser(
        authorUid: story.authorUid,
        storyId: story.id,
        viewerUid: currentUser.uid,
      );
      if (mounted) {
        setState(() {
          _isCurrentStoryLiked = liked;
        });
      }
    } catch (e) {
      // Nếu lỗi thì bỏ qua, không chặn UI
      debugPrint('Error loading story like state: $e');
    }
  }

  Future<void> _toggleLikeCurrentStory() async {
    if (_currentStories.isEmpty) return;
    final currentUser = authRepository.currentUser();
    if (currentUser == null) return;

    final story = _currentStories[_currentStoryIndex];

    // Cho phép tác giả tự tim story của mình
    final previous = _isCurrentStoryLiked;
    setState(() {
      _isCurrentStoryLiked = !previous;
    });

    try {
      await _storyRepository.toggleStoryLike(
        authorUid: story.authorUid,
        storyId: story.id,
        likerUid: currentUser.uid,
      );

      // Chỉ tạo notification khi chuyển từ chưa tim -> tim và không phải story của chính mình
      if (!previous && _isCurrentStoryLiked && story.authorUid != currentUser.uid) {
        await _notificationService.createStoryLikeNotification(
          storyId: story.id,
          storyAuthorUid: story.authorUid,
          likerUid: currentUser.uid,
        );
      }
    } catch (e) {
      // Revert state nếu lỗi để tránh sai lệch với server
      if (mounted) {
        setState(() {
          _isCurrentStoryLiked = previous;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tim story, vui lòng thử lại.'),
          ),
        );
      }
      debugPrint('Error toggling story like: $e');
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
      // Hết story của user hiện tại
      if (_userIds.length <= 1) {
        // Chỉ có 1 user (ví dụ xem từ highlight hoặc chỉ mình) -> đóng viewer
        _closeStoryViewer();
      } else {
        // Nhiều user: chuyển sang user tiếp theo
        _nextUser();
      }
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
      // Đã ở user đầu tiên: nếu chỉ có 1 user thì đóng luôn, tránh vòng lặp
      if (_userIds.length <= 1) {
        _closeStoryViewer();
      } else {
        // Nhiều user: quay lại user cuối cùng
        setState(() {
          _currentUserIndex = _userIds.length - 1;
          _currentStoryIndex = 0;
          _isInitialized = false;
        });
        _userPageController.jumpToPage(_currentUserIndex);
        _loadStoriesForCurrentUser();
      }
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
    _storiesSub?.cancel();
    _disposeVideoController();
    _userPageController.dispose();
    _storyPageController.dispose();
    super.dispose();
  }

  String _timeAgo(DateTime createdAt) {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
    if (diff.inHours < 24) return '${diff.inHours} giờ';
    final days = diff.inDays;
    return '$days ngày';
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
                    // User info + thời gian đăng story
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
                            final currentStory = _currentStories.isNotEmpty
                                ? _currentStories[_currentStoryIndex]
                                : null;
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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile?.displayName ??
                                          _userIds[_currentUserIndex],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (currentStory != null)
                                      Text(
                                        _timeAgo(currentStory.createdAt),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
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
                bottom: 100,
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

            // Navigation bar ở dưới cùng
            if (_currentStories.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Icon người: xem viewers (chỉ hiển thị cho story của chính mình)
                      if (_userIds[_currentUserIndex] == authRepository.currentUser()?.uid)
                        IconButton(
                          icon: const Icon(Icons.person, color: Colors.white),
                          onPressed: () => _showViewersDialog(),
                        ),
                      // Icon tim: like/unlike story (cho story của người khác)
                      IconButton(
                        icon: Icon(
                          _isCurrentStoryLiked ? Icons.favorite : Icons.favorite_border,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _toggleLikeCurrentStory(),
                      ),
                      // Icon gửi: gửi story đến bạn bè
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: () => _showSendStoryDialog(),
                      ),
                      // Icon 3 chấm: menu (cho story của chính mình)
                      if (_userIds[_currentUserIndex] == authRepository.currentUser()?.uid)
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onPressed: () {
                            if (widget.highlightId != null) {
                              _showHighlightMenu();
                            } else {
                              _showStoryMenu();
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
                        ],
        ),
      ),
    );
  }

  Future<void> _showViewersDialog() async {
    if (_currentStories.isEmpty) return;
    final story = _currentStories[_currentStoryIndex];
    final currentUserId = _userIds[_currentUserIndex];
    
    final viewerEntries = await _storyRepository.fetchViewerEntries(
      authorUid: currentUserId,
      storyId: story.id,
    );
    
    if (!mounted) return;
    
    final profiles = await Future.wait(
      viewerEntries.map((e) => userProfileRepository.fetchProfile(e.uid)),
    );
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Người đã xem'),
        content: SizedBox(
          width: double.maxFinite,
          child: viewerEntries.isEmpty
              ? const Text('Chưa có ai xem story này')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: viewerEntries.length,
                  itemBuilder: (context, index) {
                    final entry = viewerEntries[index];
                    final profile = profiles[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: profile?.photoUrl != null
                            ? NetworkImage(profile!.photoUrl!)
                            : null,
                        child: profile?.photoUrl == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(
                        profile?.displayName ?? entry.uid,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (entry.liked)
                            const Icon(
                              Icons.favorite,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                          IconButton(
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              size: 20,
                            ),
                            tooltip: 'Trả lời tin',
                            onPressed: () =>
                                _replyToStoryViewer(entry.uid),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _replyToStoryViewer(String viewerUid) async {
    if (_currentStories.isEmpty) return;
    final currentUser = authRepository.currentUser();
    if (currentUser == null) return;

    final story = _currentStories[_currentStoryIndex];

    try {
      // Đóng dialog danh sách viewers trước
      Navigator.of(context).pop();

      final conversationId =
          await _chatRepository.createOrGetDirectConversation(
        currentUid: currentUser.uid,
        otherUid: viewerUid,
      );

      final attachment = MessageAttachment(
        url: story.mediaUrl,
        name: 'story_${story.id}',
        size: 0,
        mimeType:
            story.type == StoryMediaType.image ? 'image/*' : 'video/*',
        type: story.type == StoryMediaType.image
            ? 'image'
            : 'video_message',
        thumbnailUrl: story.thumbnailUrl,
      );

      if (story.type == StoryMediaType.image) {
        await _chatRepository.sendImageMessage(
          conversationId: conversationId,
          senderId: currentUser.uid,
          attachments: [attachment],
          text: '💬 Trả lời tin của bạn',
        );
      } else {
        await _chatRepository.sendVideoMessage(
          conversationId: conversationId,
          senderId: currentUser.uid,
          attachments: [attachment],
          text: '💬 Trả lời tin của bạn',
        );
      }

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailPage(
            conversationId: conversationId,
            otherUid: viewerUid,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể trả lời story: $e'),
          ),
        );
      }
    }
  }

  Future<void> _showSendStoryDialog() async {
    if (_currentStories.isEmpty) return;
    final story = _currentStories[_currentStoryIndex];
    final currentUser = authRepository.currentUser();
    if (currentUser == null) return;
    
    // Lấy danh sách bạn bè (người đang follow)
    final followService = FollowService();
    List<FollowEntry> following;
    try {
      following = await followService
          .watchFollowingEntries(currentUser.uid)
          .first
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải danh sách bạn bè: $e')),
      );
      return;
    }
    
    if (!mounted) return;
    
    final selectedUids = <String>{};
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gửi story'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SizedBox(
              width: double.maxFinite,
              child: following.isEmpty
                  ? const Text('Bạn chưa theo dõi ai')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: following.length,
                      itemBuilder: (context, index) {
                        final entry = following[index];
                        final profile = entry.profile;
                        final isSelected = selectedUids.contains(entry.uid);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                selectedUids.add(entry.uid);
                              } else {
                                selectedUids.remove(entry.uid);
                              }
                            });
                          },
                          title: Text(
                            profile?.displayName ?? entry.uid,
                          ),
                          secondary: CircleAvatar(
                            backgroundImage: profile?.photoUrl != null
                                ? NetworkImage(profile!.photoUrl!)
                                : null,
                            child: profile?.photoUrl == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                        );
                      },
                    ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (selectedUids.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng chọn ít nhất 1 người')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
    
    if (result == true && selectedUids.isNotEmpty) {
      if (!mounted) return;

      // Gửi story cho từng người đã chọn
      int successCount = 0;
      int failCount = 0;

      // Tạm thời pause story khi gửi để giảm tải GPU/decoder
      final wasPaused = _isPaused;
      setState(() {
        _isPaused = true;
        _videoController?.pause();
      });

      for (final uid in selectedUids) {
        try {
          // Tạo hoặc lấy conversation 1-1
          final conversationId = await _chatRepository.createOrGetDirectConversation(
            currentUid: currentUser.uid,
            otherUid: uid,
          );

          final isVideo = story.type == StoryMediaType.video;

          final attachment = MessageAttachment(
            url: story.mediaUrl,
            name: 'Story',
            size: 0,
            mimeType: isVideo ? 'video/mp4' : 'image/jpeg',
            type: isVideo ? 'video_message' : 'image',
            durationMs: null,
            thumbnailUrl: isVideo ? story.thumbnailUrl : null,
          );

          if (isVideo) {
            await _chatRepository.sendVideoMessage(
              conversationId: conversationId,
              senderId: currentUser.uid,
              attachments: [attachment],
              text: '',
            );
          } else {
            await _chatRepository.sendImageMessage(
              conversationId: conversationId,
              senderId: currentUser.uid,
              attachments: [attachment],
              text: '',
            );
          }

          successCount++;
        } catch (e) {
          debugPrint('Error sending story to $uid: $e');
          failCount++;
        }
      }

      // Khôi phục trạng thái play/pause ban đầu của story
      if (!wasPaused) {
        setState(() {
          _isPaused = false;
          _videoController?.play();
        });
      }

      if (!mounted) return;

      final message = failCount == 0
          ? 'Đã gửi story đến $successCount người'
          : 'Đã gửi thành công cho $successCount người, lỗi với $failCount người';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _showStoryMenu() async {
    if (_currentStories.isEmpty) return;
    final currentUserId = _userIds[_currentUserIndex];
    final currentUser = authRepository.currentUser();
    if (currentUser == null || currentUserId != currentUser.uid) return;
    
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Xóa story'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    
    if (result == 'delete') {
      await _deleteCurrentStory();
    }
  }

  Future<void> _showHighlightMenu() async {
    if (_currentStories.isEmpty || widget.highlightId == null) return;
    final currentUserId = _userIds[_currentUserIndex];
    final currentUser = authRepository.currentUser();
    if (currentUser == null || currentUserId != currentUser.uid) return;
    
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Thêm story mới vào highlight'),
              onTap: () => Navigator.pop(context, 'add'),
            ),
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('Lựa chọn story'),
              onTap: () => Navigator.pop(context, 'select'),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Xóa story'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    
    if (result == 'add') {
      // Navigate to story create page
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const StoryCreatePage(),
        ),
      );
    } else if (result == 'select') {
      // Navigate to manage highlight stories page
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ManageHighlightStoriesPage(
            uid: currentUser.uid,
            initialHighlightId: widget.highlightId,
          ),
        ),
      );
    } else if (result == 'delete') {
      await _deleteCurrentStory();
    }
  }

  Future<void> _deleteCurrentStory() async {
    if (_currentStories.isEmpty) return;
    final currentUserId = _userIds[_currentUserIndex];
    final currentUser = authRepository.currentUser();
    if (currentUser == null || currentUserId != currentUser.uid) return;

    final story = _currentStories[_currentStoryIndex];
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa story'),
        content: const Text('Bạn có chắc chắn muốn xóa story này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _storyRepository.deleteStory(
          authorUid: currentUserId,
          storyId: story.id,
        );
        
        // Xóa story khỏi danh sách local
        setState(() {
          _currentStories.removeAt(_currentStoryIndex);
          if (_currentStoryIndex >= _currentStories.length) {
            _currentStoryIndex = _currentStories.length > 0 
                ? _currentStories.length - 1 
                : 0;
          }
        });

        if (mounted) {
          if (_currentStories.isEmpty) {
            // Không còn story nào, chuyển sang user tiếp theo hoặc đóng
            _nextUser();
          } else {
            // Load story mới
            _loadCurrentStory();
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa story')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể xóa story: $e')),
          );
        }
        debugPrint('Error deleting story: $e');
      }
    }
  }
}
