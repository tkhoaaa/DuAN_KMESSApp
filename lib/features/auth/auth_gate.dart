import 'dart:async';
import 'auth_repository.dart';
import 'email_verification_screen.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../admin/pages/user_ban_screen.dart';
import '../profile/user_profile_repository.dart';
import '../profile/profile_screen.dart';
import '../contacts/pages/contacts_page.dart';
import '../chat/pages/conversations_page.dart';
import '../posts/pages/post_feed_page.dart';
import '../posts/services/post_scheduling_service.dart';
import '../search/pages/search_page.dart';
import '../share/models/deep_link.dart';
import '../share/services/deep_link_service.dart';
import '../call/models/call.dart';
import '../call/services/call_service.dart';
import '../call/widgets/incoming_call_dialog.dart';
import '../chat/repositories/chat_repository.dart';
import '../follow/repositories/follow_repository.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'pages/add_phone_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authRepository.authState(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (user == null) {
          return const LoginScreen();
        }
        if (_needsEmailVerification(user)) {
          return EmailVerificationScreen(
            onVerified: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
                (route) => false,
              );
            },
          );
        }
        return const _SignedInHomeWithBanCheck();
      },
    );
  }
}

bool _needsEmailVerification(User user) {
  final hasEmail = user.email?.isNotEmpty ?? false;
  if (!hasEmail || user.emailVerified) return false;

  final providerIds = user.providerData.map((p) => p.providerId).toList();
  final hasPasswordProvider =
      providerIds.contains('password') || providerIds.isEmpty;

  return hasPasswordProvider;
}

class _SignedInHomeWithBanCheck extends StatelessWidget {
  const _SignedInHomeWithBanCheck();

  @override
  Widget build(BuildContext context) {
    final user = authRepository.currentUser();
    if (user == null) {
      return const _SignedInHome();
    }

    // Kiểm tra trạng thái ban dựa trên user_profiles (nguồn sự thật duy nhất)
    return StreamBuilder<UserProfile?>(
      stream: userProfileRepository.watchProfile(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = snapshot.data;
        if (profile != null) {
          final now = DateTime.now();
          final isBanned = profile.banStatus != BanStatus.none &&
              (profile.banStatus == BanStatus.permanent ||
                  (profile.banExpiresAt != null &&
                      now.isBefore(profile.banExpiresAt!)));

          if (isBanned) {
            return const UserBanScreen();
          }
        }

        return const _SignedInHome();
      },
    );
  }
}

class _SignedInHome extends StatefulWidget {
  const _SignedInHome();

  @override
  State<_SignedInHome> createState() => _SignedInHomeState();
}

class _SignedInHomeState extends State<_SignedInHome> {
  final PostSchedulingService _schedulingService = PostSchedulingService();
  final CallService _callService = CallService();
  final ChatRepository _chatRepository = ChatRepository();
  final FollowRepository _followRepository = FollowRepository();
  Timer? _scheduledPostsTimer;
  final MethodChannel _methodChannel = const MethodChannel('app.channel.deeplink');
  StreamSubscription<List<Call>>? _activeCallsSub;
  Call? _currentIncomingCall;
  bool _isShowingDialog = false;
  bool _phonePromptShown = false;
  StreamSubscription<UserProfile?>? _profileSub;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    final user = authRepository.currentUser();
    if (user != null) {
      userProfileRepository.ensureProfile(
        uid: user.uid,
        email: user.email,
        phoneNumber: user.phoneNumber,
        displayName: user.displayName,
        photoUrl: user.photoURL,
      );
      userProfileRepository.setPresence(user.uid, true);
      _listenProfilePhoneMissing();
      // Check và publish scheduled posts khi app mở
      _checkScheduledPosts();
      // Check định kỳ mỗi phút để auto-publish scheduled posts
      _scheduledPostsTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _checkScheduledPosts(),
      );
      
      // Listen incoming calls globally
      _listenIncomingCalls();
    }
    
    // Listen deep links
    _initDeepLinkListener();
  }
  
  void _listenIncomingCalls() {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) return;
    
    _activeCallsSub?.cancel();
    _activeCallsSub = _callService.watchActiveCalls(currentUid).listen((calls) {
      if (!mounted) return;
      
      // Tìm incoming call đang ringing
      final incomingCall = calls.firstWhere(
        (call) =>
            call.calleeUid == currentUid &&
            call.status == CallStatus.ringing,
        orElse: () => Call(
          id: '',
          callerUid: '',
          calleeUid: '',
          type: CallType.voice,
          status: CallStatus.ringing,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      // Nếu có incoming call mới và chưa hiển thị dialog
      if (incomingCall.id.isNotEmpty && 
          incomingCall.id != _currentIncomingCall?.id &&
          !_isShowingDialog) {
        _currentIncomingCall = incomingCall;
        _showIncomingCallDialog(incomingCall);
      } else if (incomingCall.id.isEmpty && _currentIncomingCall != null) {
        // Nếu không còn incoming call, reset
        _currentIncomingCall = null;
        _isShowingDialog = false;
      }
    });
  }
  
  void _showIncomingCallDialog(Call call) {
    // Kiểm tra xem dialog đã được hiển thị chưa
    if (_isShowingDialog) return;
    
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return;
    
    // Sử dụng SchedulerBinding để đảm bảo context sẵn sàng
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isShowingDialog) return;
      
      // Kiểm tra lại xem call vẫn còn ringing không
      if (_currentIncomingCall?.id != call.id) return;
      
      _isShowingDialog = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => IncomingCallDialog(
          callId: call.id,
          callerUid: call.callerUid,
          callType: call.type,
        ),
      ).then((_) {
        // Reset khi dialog đóng
        _isShowingDialog = false;
        if (_currentIncomingCall?.id == call.id) {
          _currentIncomingCall = null;
        }
      });
    });
  }

  void _initDeepLinkListener() {
    // Listen for deep links when app is opened from terminated state
    _methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink' && mounted) {
        final url = call.arguments as String?;
        if (url != null) {
          _handleDeepLink(url);
        }
      }
    });
    
    // Try to get initial link (when app opened from link)
    _getInitialLink();
  }

  Future<void> _getInitialLink() async {
    try {
      final initialLink = await _methodChannel.invokeMethod<String>('getInitialLink');
      if (initialLink != null && mounted) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }
  }

  void _handleDeepLink(String url) {
    if (!mounted) return;
    
    final link = DeepLink.fromUrl(url);
    if (link.type != DeepLinkType.unknown) {
      // Delay navigation để đảm bảo context sẵn sàng
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          DeepLinkService.handleDeepLink(context, link);
        }
      });
    }
  }

  Future<void> _checkScheduledPosts() async {
    try {
      final publishedCount = await _schedulingService.checkAndPublishScheduledPosts();
      if (publishedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã đăng tự động $publishedCount bài viết đã hẹn giờ'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Silently fail, không làm gián đoạn app
      debugPrint('Error checking scheduled posts: $e');
    }
  }

  @override
  void dispose() {
    _scheduledPostsTimer?.cancel();
    _activeCallsSub?.cancel();
    final user = authRepository.currentUser();
    if (user != null) {
      userProfileRepository.setPresence(user.uid, false);
    }
    _profileSub?.cancel();
    super.dispose();
  }

  void _listenProfilePhoneMissing() {
    final uid = authRepository.currentUser()?.uid;
    if (uid == null) return;
    
    _profileSub?.cancel();
    _profileSub = userProfileRepository.watchProfile(uid).listen((profile) {
      if (!mounted || _phonePromptShown) return;
      if (profile != null && (profile.phoneNumber == null || profile.phoneNumber!.isEmpty)) {
        _phonePromptShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Thêm số điện thoại'),
              content: const Text('Bạn chưa thêm số điện thoại. Thêm số để đăng nhập/khôi phục mật khẩu bằng SĐT.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Để sau'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddPhonePage()),
                    );
                  },
                  child: const Text('Thêm ngay'),
                ),
              ],
            ),
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = authRepository.currentUser();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'KMESS',
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryPink,
          ),
        ),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: user != null
            ? userProfileRepository.watchProfile(user.uid)
            : Stream<UserProfile?>.empty(),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final displayName = profile?.displayName?.isNotEmpty == true
              ? profile!.displayName!
              : (user?.email ?? 'Người dùng');
          final avatarUrl = profile?.photoUrl;
          final posts = profile?.postsCount ?? 0;
          final following = profile?.followingCount ?? 0;
          final followers = profile?.followersCount ?? 0;
          final isOnline = profile?.isOnline == true;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryPink.withOpacity(0.15),
                        AppColors.lightPink.withOpacity(0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.lightPink.withOpacity(0.6),
                        backgroundImage:
                            avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? Text(
                                displayName.isNotEmpty ? displayName.characters.first.toUpperCase() : 'K',
                                style: AppTypography.headline.copyWith(
                                  color: AppColors.backgroundWhite,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        displayName,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'UID: ${user?.uid ?? "-"}',
                        style: AppTypography.small.copyWith(color: AppColors.textLight),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isOnline ? AppColors.primaryPink.withOpacity(0.12) : AppColors.borderGrey,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOnline ? Icons.circle : Icons.schedule,
                              size: 12,
                              color: isOnline ? AppColors.primaryPink : AppColors.textLight,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOnline
                                  ? 'Đang hoạt động'
                                  : (profile?.lastSeen != null
                                      ? 'Hoạt động: ${profile!.lastSeen}'
                                      : 'Ngoại tuyến'),
                              style: AppTypography.small.copyWith(
                                color: isOnline ? AppColors.primaryPink : AppColors.textLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  color: AppColors.backgroundWhite,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatChip(label: 'Bài đăng', value: posts),
                        _StatChip(label: 'Đang theo dõi', value: following),
                        _StatChip(label: 'Người theo dõi', value: followers),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _handleNavTap(0),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Vào Bảng tin'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleNavTap(4),
                        icon: const Icon(Icons.person_outline, color: AppColors.primaryPink),
                        label: const Text('Hồ sơ'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryPink,
                          side: const BorderSide(color: AppColors.primaryPink),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (profile != null && (profile.phoneNumber == null || profile.phoneNumber!.isEmpty))
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AddPhonePage()),
                      );
                    },
                    icon: const Icon(Icons.phone_iphone, color: AppColors.primaryPink),
                    label: const Text('Thêm số điện thoại để khôi phục'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryPink,
                      side: const BorderSide(color: AppColors.primaryPink),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: StreamBuilder<int>(
        stream: user != null ? _chatRepository.watchUnreadCount(user.uid) : null,
        initialData: 0,
        builder: (context, chatSnap) {
          final unreadChat = chatSnap.data ?? 0;
          return StreamBuilder<UserProfile?>(
            stream: user != null
                ? userProfileRepository.watchProfile(user.uid)
                : Stream<UserProfile?>.empty(),
            builder: (context, profileSnap) {
              final profile = profileSnap.data;
              final isPrivate = profile?.isPrivate ?? false;
              final pendingStream = (user != null && isPrivate)
                  ? _followRepository
                      .watchIncomingRequests(user.uid)
                      .map((snap) => snap.size)
                  : Stream<int>.value(0);
              return StreamBuilder<int>(
                stream: pendingStream,
                initialData: 0,
                builder: (context, followSnap) {
                  final pendingFollow = followSnap.data ?? 0;
                  return _BottomNavBar(
                    currentIndex: _navIndex,
                    onTap: _handleNavTap,
                    unreadChatCount: unreadChat,
                    followerRequestCount: pendingFollow,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _handleNavTap(int index) async {
    setState(() {
      _navIndex = index;
    });
    switch (index) {
      case 0: // Bảng tin (Feed)
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PostFeedPage()),
        );
        break;
      case 1: // Tìm kiếm
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SearchPage()),
        );
        break;
      case 2: // Chat
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ConversationsPage()),
        );
        break;
      case 3: // Người theo dõi (Contacts)
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ContactsPage()),
        );
        break;
      case 4: // Hồ sơ (có chứa logout trong trang)
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
        break;
    }
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.onTap,
    this.unreadChatCount = 0,
    this.followerRequestCount = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final int unreadChatCount;
  final int followerRequestCount;

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem('Bảng tin', Icons.photo_library_outlined),
      _NavItem('Tìm kiếm', Icons.search),
      _NavItem('Tin nhắn', Icons.chat_outlined,
          badge: unreadChatCount > 0 ? unreadChatCount : null),
      _NavItem('Người theo dõi', Icons.people_outline,
          badge: followerRequestCount > 0 ? followerRequestCount : null),
      _NavItem('Hồ sơ', Icons.person_outline),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: AppColors.borderGrey),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isActive = index == currentIndex;
            final color = isActive ? AppColors.primaryPink : Colors.grey[600];

            return Expanded(
              child: InkResponse(
                onTap: () => onTap(index),
                radius: 28,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(item.icon, color: color),
                          if (item.badge != null)
                            Positioned(
                              right: -10,
                              top: -6,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPink,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                constraints: const BoxConstraints(minWidth: 18),
                                child: Text(
                                  item.badge! > 99 ? '99+' : '${item.badge}',
                                  style: AppTypography.small.copyWith(
                                    color: AppColors.backgroundWhite,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: AppTypography.small.copyWith(
                          color: color,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTypography.small.copyWith(color: AppColors.textLight),
        ),
      ],
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, {this.badge});
  final String label;
  final IconData icon;
  final int? badge;
}

