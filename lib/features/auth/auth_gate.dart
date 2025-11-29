import 'dart:async';

import 'auth_repository.dart';
import 'email_verification_screen.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../notifications/pages/notification_center_page.dart';
import '../notifications/services/notification_service.dart';
import '../profile/user_profile_repository.dart';
import '../profile/profile_screen.dart';
import '../contacts/pages/contacts_page.dart';
import '../chat/pages/conversations_page.dart';
import '../posts/pages/post_feed_page.dart';
import '../posts/services/post_scheduling_service.dart';
import '../search/pages/search_page.dart';
import '../share/models/deep_link.dart';
import '../share/services/deep_link_service.dart';

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
        return const _SignedInHome();
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

class _SignedInHome extends StatefulWidget {
  const _SignedInHome();

  @override
  State<_SignedInHome> createState() => _SignedInHomeState();
}

class _SignedInHomeState extends State<_SignedInHome> {
  final PostSchedulingService _schedulingService = PostSchedulingService();
  Timer? _scheduledPostsTimer;
  final MethodChannel _methodChannel = const MethodChannel('app.channel.deeplink');

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
      // Check và publish scheduled posts khi app mở
      _checkScheduledPosts();
      // Check định kỳ mỗi phút để auto-publish scheduled posts
      _scheduledPostsTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _checkScheduledPosts(),
      );
    }
    
    // Listen deep links
    _initDeepLinkListener();
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
    final user = authRepository.currentUser();
    if (user != null) {
      userProfileRepository.setPresence(user.uid, false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = authRepository.currentUser();
    return Scaffold(
      appBar: AppBar(
        title: const Text('KMESS'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchPage()),
              );
            },
            icon: const Icon(Icons.search),
            tooltip: 'Tìm kiếm',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ContactsPage()),
              );
            },
            icon: const Icon(Icons.people_outline),
            tooltip: 'Danh bạ',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PostFeedPage()),
              );
            },
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Bảng tin',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConversationsPage()),
              );
            },
            icon: const Icon(Icons.chat_outlined),
            tooltip: 'Hội thoại',
          ),
          StreamBuilder<int>(
            stream: user != null
                ? NotificationService().watchUnreadCount(user.uid)
                : Stream<int>.value(0),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationCenterPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'Thông báo',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            icon: const Icon(Icons.person),
            tooltip: 'Quản lý hồ sơ',
          ),
          IconButton(
            onPressed: () async {
              final current = authRepository.currentUser();
              if (current != null) {
                await userProfileRepository.setPresence(current.uid, false);
              }
              await authRepository.signOut();
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: StreamBuilder<UserProfile?>(
        stream: user != null
            ? userProfileRepository.watchProfile(user.uid)
            : Stream<UserProfile?>.empty(),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user, size: 72),
                const SizedBox(height: 16),
                Text('Signed in as: ${user?.uid ?? "-"}'),
                if (profile != null) ...[
                  const SizedBox(height: 8),
                  Text('Tên hiển thị: ${profile.displayName?.isNotEmpty == true ? profile.displayName : "(chưa có)"}'),
                  Text(
                    profile.isOnline
                        ? 'Trạng thái: Online'
                        : (profile.lastSeen != null
                            ? 'Hoạt động lần cuối: ${profile.lastSeen}'
                            : 'Trạng thái: Offline'),
                  ),
                  const SizedBox(height: 8),
                  Text('Bài đăng: ${profile.postsCount}'),
                  Text('Đang theo dõi: ${profile.followingCount}'),
                  Text('Người theo dõi: ${profile.followersCount}'),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

