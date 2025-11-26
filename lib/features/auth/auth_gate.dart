import 'auth_repository.dart';
import 'email_verification_screen.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../notifications/pages/notification_center_page.dart';
import '../notifications/services/notification_service.dart';
import '../profile/user_profile_repository.dart';
import '../profile/profile_screen.dart';
import '../contacts/pages/contacts_page.dart';
import '../chat/pages/conversations_page.dart';
import '../posts/pages/post_feed_page.dart';

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
    }
  }

  @override
  void dispose() {
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

