import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'user_profile_repository.dart';
import '../admin/pages/admin_dashboard_page.dart';
import '../admin/repositories/admin_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_gate.dart';
import '../auth/auth_repository.dart';
import '../auth/login_screen.dart';
import '../auth/saved_accounts_repository.dart';
import '../auth/saved_credentials_repository.dart';
import '../follow/services/follow_service.dart';
import '../chat/pages/chat_detail_page.dart';
import '../chat/repositories/chat_repository.dart';
import '../profile/public_profile_page.dart';
import '../../services/cloudinary_service.dart';
import '../saved_posts/pages/saved_posts_page.dart';
import '../settings/pages/privacy_settings_page.dart';
import '../auth/pages/change_password_page.dart';
import '../stories/pages/story_create_page.dart';
import '../stories/pages/story_viewer_page.dart';
import '../stories/repositories/story_repository.dart';
import '../stories/models/story.dart';
import '../posts/pages/post_create_page.dart';
import '../posts/pages/post_permalink_page.dart';
import '../posts/repositories/post_repository.dart';
import '../posts/models/post.dart';
import 'widgets/profile_posts_widgets.dart';
import 'widgets/avatar_fullscreen_viewer.dart';
import 'pages/manage_highlight_stories_page.dart';
import '../../theme/colors.dart';

enum _ProfileMenuAction {
  personalInfo,
  privacySettings,
  privateAccount,
  highlightStories,
  savedPosts,
  changePassword,
  adminDashboard,
  logout,
}

enum _LogoutChoice {
  saveAndSignOut,
  signOutOnly,
}

enum _CreateAction { story, post }
enum _AccountMenuAction { switchAccount, logout }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController displayNameController = TextEditingController();
  final TextEditingController photoUrlController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final AdminRepository _adminRepository = AdminRepository();
  final PostRepository _postRepository = PostRepository();
  bool isSaving = false;
  bool isUploading = false;
  bool _loadedInitial = false;
  bool _isPrivate = false;
  String? _themeColor;
  List<ProfileLink> _links = [];
  bool _isAdmin = false;
  late final FollowService _followService;
  List<Post> _pinnedPosts = [];
  List<Post> _allPosts = [];
  bool _isLoadingPosts = false;

  @override
  void initState() {
    super.initState();
    _followService = FollowService();
    _checkAdminStatus();
    _loadPinnedPosts();
    _loadAllPosts();
  }

  Future<void> _loadPinnedPosts() async {
    try {
      final user = authRepository.currentUser();
      if (user == null) return;
      final profile = await userProfileRepository.fetchProfile(user.uid);
      if (profile == null || profile.pinnedPostIds.isEmpty) {
        if (mounted) {
          setState(() {
            _pinnedPosts = [];
          });
        }
        return;
      }

      final posts = <Post>[];
      for (final postId in profile.pinnedPostIds) {
        try {
          final post = await _postRepository.watchPost(postId).first;
          posts.add(post);
        } catch (_) {
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _pinnedPosts = posts;
        });
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadAllPosts() async {
    final user = authRepository.currentUser();
    if (user == null) return;

    setState(() {
      _isLoadingPosts = true;
    });

    try {
      final pageResult = await _postRepository.fetchPostsByAuthor(
        authorUid: user.uid,
        limit: 50,
      );

      final posts = pageResult.docs.map((doc) => Post.fromDoc(doc)).toList();

      if (mounted) {
        setState(() {
          _allPosts = posts;
          _isLoadingPosts = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
        });
      }
    }
  }

  Future<void> _checkAdminStatus() async {
    final user = authRepository.currentUser();
    if (user != null) {
      final isAdmin = await _adminRepository.isAdmin(user.uid);
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
        });
      }
    }
  }

  @override
  void dispose() {
    displayNameController.dispose();
    photoUrlController.dispose();
    bioController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile(String uid) async {
    setState(() {
      isSaving = true;
    });
    try {
      await userProfileRepository.updateProfile(
        uid,
        displayName: displayNameController.text.trim(),
        photoUrl: photoUrlController.text.trim().isEmpty
            ? null
            : photoUrlController.text.trim(),
        removePhoto: photoUrlController.text.trim().isEmpty,
        bio: bioController.text.trim(),
        note: noteController.text.trim(),
        isPrivate: _isPrivate,
        themeColor: _themeColor,
        links: _links,
      );
      _loadedInitial = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật hồ sơ.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  /// Chọn storage backend: 'firebase' hoặc 'cloudinary'
  /// Phải khớp với PostService.storageBackend
  static const String storageBackend = 'cloudinary'; // Thay đổi thành 'firebase' nếu muốn dùng Firebase Storage

  Future<void> _pickAndUploadImage(String uid, ImageSource source) async {
    setState(() {
      isUploading = true;
    });
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked == null) {
        setState(() {
          isUploading = false;
        });
        return;
      }

      String url;
      
      if (storageBackend == 'cloudinary') {
        // Dùng Cloudinary
        final result = await CloudinaryService.uploadImage(
          file: picked,
          folder: 'user_profiles/$uid',
          publicId: 'avatar',
        );
        url = result['url']!;
      } else {
        // Dùng Firebase Storage (code cũ)
        final storageRef =
            FirebaseStorage.instance.ref().child('user_profiles/$uid/avatar.jpg');

        if (kIsWeb) {
          final bytes = await picked.readAsBytes();
          await storageRef.putData(
            bytes,
            SettableMetadata(contentType: picked.mimeType ?? 'image/jpeg'),
          );
        } else {
          final file = File(picked.path);
          await storageRef.putFile(
            file,
            SettableMetadata(contentType: 'image/jpeg'),
          );
        }

        url = await storageRef.getDownloadURL();
      }

      await userProfileRepository.updateProfile(uid, photoUrl: url);
      _loadedInitial = false;
      if (mounted) {
        photoUrlController.text = url;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật ảnh đại diện.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải ảnh: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  Future<void> _removePhoto(String uid) async {
    setState(() {
      isUploading = true;
    });
    try {
      await userProfileRepository.updateProfile(
        uid,
        photoUrl: '',
        removePhoto: true,
      );
      _loadedInitial = false;
      if (mounted) {
        photoUrlController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xoá ảnh đại diện.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xoá ảnh: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  Future<void> _showCreateChooser() async {
    final action = await showModalBottomSheet<_CreateAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history_edu),
              title: const Text('Đăng story'),
              onTap: () => Navigator.pop(context, _CreateAction.story),
            ),
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_outlined),
              title: const Text('Thêm bài viết'),
              onTap: () => Navigator.pop(context, _CreateAction.post),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    switch (action) {
      case _CreateAction.story:
              Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StoryCreatePage()),
        );
        break;
      case _CreateAction.post:
              Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PostCreatePage()),
        );
        break;
    }
  }

  Future<void> _showAccountMenu() async {
    final action = await showModalBottomSheet<_AccountMenuAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.switch_account),
              title: const Text('Chuyển tài khoản'),
              onTap: () => Navigator.pop(context, _AccountMenuAction.switchAccount),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Đăng xuất'),
              onTap: () => Navigator.pop(context, _AccountMenuAction.logout),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    switch (action) {
      case _AccountMenuAction.switchAccount:
        await _showSwitchAccountSheet();
        break;
      case _AccountMenuAction.logout:
        await _confirmLogoutAndMaybeSave(
          currentUser: authRepository.currentUser(),
          forSwitchAccount: false,
        );
        break;
    }
  }

  Future<void> _confirmLogoutAndMaybeSave({
    User? currentUser,
    bool forSwitchAccount = false,
  }) async {
    final user = currentUser ?? authRepository.currentUser();
    if (user == null) return;

    final choice = await showDialog<_LogoutChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có muốn lưu tài khoản này để chuyển đổi nhanh sau này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _LogoutChoice.signOutOnly),
            child: const Text('Đăng xuất'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _LogoutChoice.saveAndSignOut),
            child: const Text('Lưu tài khoản'),
          ),
        ],
      ),
    );

    if (!mounted || choice == null) return;

    if (choice == _LogoutChoice.saveAndSignOut) {
      await SavedAccountsRepository.instance.saveAccountFromUser(user);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu tài khoản trên thiết bị.')),
      );
    } else {
      await SavedAccountsRepository.instance.removeAccount(user.uid);
      await SavedCredentialsRepository.instance.removePassword(user.uid);
    }

    await userProfileRepository.setPresence(user.uid, false);
    // Với flow đăng xuất bình thường: set offline + signOut để quay về màn hình login/AuthGate
    // Với flow chuyển đổi tài khoản: chỉ set offline, KHÔNG signOut, sẽ signIn tài khoản khác ngay sau đó
    if (!forSwitchAccount) {
      await authRepository.signOut();
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showSwitchAccountSheet() async {
    final accounts = await SavedAccountsRepository.instance.getAccounts();
    if (!mounted) return;

    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có tài khoản nào được lưu trên thiết bị.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<SavedAccount>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Chuyển đổi tài khoản',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...accounts.map(
              (acc) => ListTile(
                leading: CircleAvatar(
                  radius: 28,
                  backgroundImage:
                      acc.photoUrl != null && acc.photoUrl!.isNotEmpty 
                          ? NetworkImage(acc.photoUrl!) 
                          : null,
                  backgroundColor: acc.photoUrl == null || acc.photoUrl!.isEmpty
                      ? Theme.of(ctx).colorScheme.primaryContainer
                      : null,
                  child: acc.photoUrl == null || acc.photoUrl!.isEmpty
                      ? Icon(
                          Icons.person,
                          color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                          size: 28,
                        )
                      : null,
                ),
                title: Text(
                  acc.displayName ?? acc.email ?? acc.uid,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: acc.email != null && acc.email != acc.displayName
                    ? Text(
                        acc.email!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      )
                    : null,
                onTap: () => Navigator.pop(ctx, acc),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || selected == null) return;

    // Khi chọn tài khoản khác: hỏi có lưu tài khoản hiện tại không
    final current = authRepository.currentUser();
    if (current != null) {
      await _confirmLogoutAndMaybeSave(
        currentUser: current,
        forSwitchAccount: true,
      );
    }

    if (!mounted) return;

    // Thử đăng nhập nhanh vào tài khoản đã lưu
    final quickSuccess = await _quickSignInToSavedAccount(selected);

    if (!mounted) return;

    if (quickSuccess) {
      // Đảm bảo tài khoản được lưu sau khi đăng nhập thành công
      final currentUser = authRepository.currentUser();
      if (currentUser != null) {
        try {
          await SavedAccountsRepository.instance.saveAccountFromUser(currentUser);
        } catch (e) {
          debugPrint('Error saving account after quick sign in: $e');
        }
      }
      
      // Đợi một chút để đảm bảo auth state đã được cập nhật
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Kiểm tra lại auth state trước khi điều hướng
      final finalUser = authRepository.currentUser();
      if (finalUser == null) {
        // Nếu user vẫn null, có thể có vấn đề với auth state
        debugPrint('Warning: User is null after quick sign in, redirecting to login');
        if (mounted) {
          final identifier = selected.email ?? selected.displayName ?? selected.uid;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => LoginScreen(initialIdentifier: identifier),
            ),
            (route) => false,
          );
        }
        return;
      }
      
      // Điều hướng về AuthGate để toàn bộ app rebuild theo user mới
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const AuthGate(),
          ),
          (route) => false,
        );
      }
    } else {
      // Fallback: chuyển sang màn hình login với email được điền sẵn
      final identifier = selected.email ?? selected.displayName ?? selected.uid;
      
      // Hiển thị thông báo phù hợp với loại tài khoản
      String message;
      if (selected.providerId == 'google.com') {
        message = 'Vui lòng đăng nhập lại bằng Google.';
      } else if (selected.providerId == 'facebook.com') {
        message = 'Vui lòng đăng nhập lại bằng Facebook.';
      } else {
        message = 'Tài khoản này chưa lưu mật khẩu an toàn. Vui lòng đăng nhập lại một lần.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => LoginScreen(initialIdentifier: identifier),
          ),
          (route) => false,
        );
      }
    }
  }

  Future<void> _showFollowersSheet(BuildContext context, String uid) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FollowersFollowingSheet(
        uid: uid,
        isFollowers: true,
      ),
    );
  }

  Future<void> _showFollowingSheet(BuildContext context, String uid) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FollowersFollowingSheet(
        uid: uid,
        isFollowers: false,
      ),
    );
  }

  Future<bool> _quickSignInToSavedAccount(SavedAccount account) async {
    try {
      // Xử lý tài khoản đăng nhập bằng email/mật khẩu
      if (account.providerId == 'password' && account.email != null) {
        final password =
            await SavedCredentialsRepository.instance.getPassword(account.uid);
        if (password == null || password.isEmpty) {
          return false;
        }
        
        // SignIn vào tài khoản mới
        await authRepository.signInWithEmail(account.email!, password);
        
        // Đợi auth state thay đổi để đảm bảo signIn hoàn tất
        // Sử dụng Stream để đợi auth state change hoặc timeout sau 3 giây
        final completer = Completer<bool>();
        StreamSubscription<User?>? subscription;
        Timer? timeoutTimer;
        
        subscription = authRepository.authState().listen((user) {
          if (user != null && user.uid == account.uid) {
            subscription?.cancel();
            timeoutTimer?.cancel();
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          }
        });
        
        // Timeout sau 3 giây nếu không nhận được auth state change
        timeoutTimer = Timer(const Duration(seconds: 3), () {
          subscription?.cancel();
          final currentUser = authRepository.currentUser();
          final success = currentUser != null && currentUser.uid == account.uid;
          if (!completer.isCompleted) {
            completer.complete(success);
          }
        });
        
        // Đợi kết quả
        final result = await completer.future;
        subscription.cancel();
        timeoutTimer.cancel();
        
        return result;
      }
      
      // Xử lý tài khoản Google Sign-In
      if (account.providerId == 'google.com') {
        try {
          // Gọi Google Sign-In (user sẽ chọn account)
          await authRepository.signInWithGoogle();
          
          // Đợi auth state thay đổi để đảm bảo signIn hoàn tất
          final completer = Completer<bool>();
          StreamSubscription<User?>? subscription;
          Timer? timeoutTimer;
          
          subscription = authRepository.authState().listen((user) async {
            if (user != null) {
              subscription?.cancel();
              timeoutTimer?.cancel();
              // Lưu tài khoản sau khi đăng nhập thành công
              try {
                await SavedAccountsRepository.instance.saveAccountFromUser(user);
              } catch (e) {
                debugPrint('Error saving account after Google sign in: $e');
              }
              if (!completer.isCompleted) {
                completer.complete(true);
              }
            }
          });
          
          // Timeout sau 5 giây (Google Sign-In có thể mất thời gian hơn)
          timeoutTimer = Timer(const Duration(seconds: 5), () async {
            subscription?.cancel();
            final currentUser = authRepository.currentUser();
            final success = currentUser != null;
            if (success && currentUser != null) {
              // Lưu tài khoản sau khi đăng nhập thành công
              try {
                await SavedAccountsRepository.instance.saveAccountFromUser(currentUser);
              } catch (e) {
                debugPrint('Error saving account after Google sign in timeout: $e');
              }
            }
            if (!completer.isCompleted) {
              completer.complete(success);
            }
          });
          
          // Đợi kết quả
          final result = await completer.future;
          subscription.cancel();
          timeoutTimer.cancel();
          
          return result;
        } catch (e) {
          // Nếu user cancel hoặc có lỗi, return false để chuyển về login screen
          debugPrint('Google Sign-In error during account switch: $e');
          return false;
        }
      }
      
      // Các provider khác (Facebook, etc.) hiện tại không auto-login
      return false;
    } catch (e) {
      debugPrint('Error in _quickSignInToSavedAccount: $e');
      return false;
    }
  }

  /// Hiển thị bottom sheet khi chạm avatar trên trang hồ sơ
  /// - Nếu người dùng có story (kể cả đã xem hết): thêm hành động "Xem tin"
  /// - Dù có story hay không, luôn có tuỳ chọn "Xem ảnh đại diện" (nếu có ảnh)
  void _handleAvatarTap(String uid, StoryRingStatus ringStatus) {
    final hasStory = ringStatus != StoryRingStatus.none;

    if (!hasStory) {
      // Không có story -> dùng sheet ảnh đại diện (vẫn có Xem ảnh đại diện)
      _showAvatarOptions(uid);
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history_edu),
              title: const Text('Xem tin'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StoryViewerPage(
                      initialAuthorUid: uid,
                      userIdsWithStories: [uid],
                    ),
                  ),
                );
              },
            ),
            if (photoUrlController.text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.remove_red_eye),
                title: const Text('Xem ảnh đại diện'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AvatarFullscreenViewer(
                        photoUrl: photoUrlController.text,
                      ),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn ảnh từ thư viện'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(uid, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(uid, ImageSource.camera);
              },
            ),
            if (photoUrlController.text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Xoá ảnh đại diện',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removePhoto(uid);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showAvatarOptions(String uid) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (photoUrlController.text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.remove_red_eye),
                title: const Text('Xem ảnh đại diện'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AvatarFullscreenViewer(
                        photoUrl: photoUrlController.text,
                      ),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn ảnh từ thư viện'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(uid, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(uid, ImageSource.camera);
              },
            ),
            if (photoUrlController.text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Xoá ảnh đại diện', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removePhoto(uid);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) {
      return 'Vừa mới hoạt động';
    } else if (diff.inHours < 1) {
      return 'Hoạt động ${diff.inMinutes} phút trước';
    } else if (diff.inDays < 1) {
      return 'Hoạt động ${diff.inHours} giờ trước';
    } else {
      return 'Hoạt động ${diff.inDays} ngày trước';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = authRepository.currentUser();
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Không tìm thấy người dùng.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hồ sơ của bạn',
          style: TextStyle(color: AppColors.primaryPink),
        ),
        iconTheme: const IconThemeData(color: AppColors.primaryPink),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _showProfileOptionsSheet(user);
            },
          ),
        ],
      ),
      body: StreamBuilder<UserProfile?>(
        stream: userProfileRepository.watchProfile(user.uid),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          if (!_loadedInitial && profile != null) {
            displayNameController.text = profile.displayName ?? '';
            photoUrlController.text = profile.photoUrl ?? '';
            bioController.text = profile.bio ?? '';
          noteController.text = profile.note ?? '';
            _isPrivate = profile.isPrivate;
            _themeColor = profile.themeColor;
            _links = List<ProfileLink>.from(profile.links);
            _loadedInitial = true;
          }

          final themeColor = _themeColor != null ? _parseColor(_themeColor!) : null;
          final displayName = displayNameController.text.isNotEmpty
              ? displayNameController.text
              : (user.email ?? user.uid);
          final statusText = profile?.isOnline == true
              ? 'Đang hoạt động'
              : profile?.lastSeen != null
                  ? _formatLastSeen(profile!.lastSeen!)
                  : 'Ngoại tuyến';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FutureBuilder<StoryRingStatus>(
                  future: StoryRepository().fetchStoryRingStatus(
                    ownerUid: user.uid,
                    viewerUid: user.uid,
                  ),
                  builder: (context, ringSnapshot) {
                    final ringStatus =
                        ringSnapshot.data ?? StoryRingStatus.none;
                    final hasActiveStory =
                        ringStatus != StoryRingStatus.none;
                    Color? ringColor;
                    if (ringStatus == StoryRingStatus.unseen) {
                      ringColor = AppColors.primaryPink;
                    } else if (ringStatus == StoryRingStatus.allSeen) {
                      // Vòng tròn xám đậm hơn để dễ thấy khi đã xem hết story
                      ringColor = Colors.grey.shade600;
                    }

                    return _EditProfileHeader(
                      displayName: displayName,
                      photoUrl: photoUrlController.text,
                      statusText: statusText,
                      themeColor: themeColor,
                      isUploading: isUploading,
                      hasActiveStory: hasActiveStory,
                      storyRingColor: ringColor,
                      onAddPressed: _showCreateChooser,
                      onAccountMenuPressed: _showAccountMenu,
                      // Khi chạm avatar: mở sheet mới với tuỳ chọn xem tin + đổi ảnh
                      onAvatarTap: () => _handleAvatarTap(user.uid, ringStatus),
                      note: noteController.text,
                      onNoteTap: () => _showEditNoteDialog(user.uid),
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (profile != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatChip(
                        label: 'Người theo dõi',
                        value: profile.followersCount,
                        onTap: () => _showFollowersSheet(context, user.uid),
                      ),
                      _StatChip(
                        label: 'Đang theo dõi',
                        value: profile.followingCount,
                        onTap: () => _showFollowingSheet(context, user.uid),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                // Highlight Stories section
                StreamBuilder<UserProfile?>(
                  stream: userProfileRepository.watchProfile(user.uid),
                  builder: (context, profileSnapshot) {
                    final profile = profileSnapshot.data;
                    final highlightedStories = profile?.highlightedStories ?? [];
                    if (highlightedStories.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return StreamBuilder<List<Story>>(
                      stream: StoryRepository().fetchStoriesByAuthor(user.uid),
                      builder: (context, storiesSnapshot) {
                        final allStories = storiesSnapshot.data ?? [];
                        
                        // Filter highlights để chỉ hiển thị những highlight có ít nhất 1 story tồn tại
                        final validHighlights = highlightedStories
                            .where((h) => h.storyIds.any((id) =>
                                allStories.any((s) => s.id == id)))
                            .toList();
                        
                        if (validHighlights.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.auto_awesome, size: 20, color: Colors.purple),
                                  SizedBox(width: 8),
                                  Text(
                                    'Tin nổi bật',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                itemCount: validHighlights.length,
                                itemBuilder: (context, index) {
                                  final highlight = validHighlights[index];
                                  final highlightStories = allStories
                                      .where((s) => highlight.storyIds.contains(s.id))
                                      .toList();
                                  if (highlightStories.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return _HighlightStoryBubble(
                                    highlight: highlight,
                                    firstStory: highlightStories.first,
                                    authorUid: user.uid,
                                    onTap: () {
                                      // Navigate to story viewer với stories của highlight
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => StoryViewerPage(
                                            initialAuthorUid: user.uid,
                                            userIdsWithStories: [user.uid],
                                            initialStoryIds: highlight.storyIds,
                                            highlightId: highlight.id,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    );
                  },
                ),
                // Pinned posts section
                if (_pinnedPosts.isNotEmpty) ...[
                const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Icon(Icons.push_pin, size: 20, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Bài viết đã ghim',
                  style: TextStyle(
                            fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      itemCount: _pinnedPosts.length,
                      itemBuilder: (context, index) {
                        final post = _pinnedPosts[index];
                        return ProfilePinnedPostItem(
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
                  const SizedBox(height: 16),
                ],
                // Posts grid section
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Icon(Icons.grid_on, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Bài viết',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_isLoadingPosts)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_allPosts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Chưa có bài viết nào',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: _allPosts.length,
                    itemBuilder: (context, index) {
                      final post = _allPosts[index];
                      return ProfilePostGridItem(
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
                // Follow requests section
                if (profile != null && _isPrivate)
                  StreamBuilder<List<FollowRequestEntry>>(
                    stream: _followService.watchIncomingRequestEntries(user.uid),
                    builder: (context, requestSnapshot) {
                      final requests = requestSnapshot.data ?? [];
                      if (requests.isEmpty) {
                          return const SizedBox.shrink();
                        }
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                              Row(
                                children: [
                                  const Icon(Icons.person_add, color: AppColors.primaryPink),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Yêu cầu theo dõi (${requests.length})',
                                    style: const TextStyle(
                              fontSize: 16,
                                      fontWeight: FontWeight.bold,
                            ),
                          ),
                                ],
                              ),
                              const SizedBox(height: 12),
                          ...requests.map(
                            (entry) => Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                      backgroundImage: entry.profile?.photoUrl != null
                                      ? NetworkImage(entry.profile!.photoUrl!)
                                      : null,
                                  child: entry.profile?.photoUrl == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(
                                      entry.profile?.displayName?.isNotEmpty == true
                                      ? entry.profile!.displayName!
                                          : (entry.profile?.email?.isNotEmpty == true
                                          ? entry.profile!.email!
                                          : entry.uid),
                                ),
                                subtitle: entry.createdAt != null
                                        ? Text('Yêu cầu lúc ${entry.createdAt}')
                                    : null,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                          onPressed: () => _followService.acceptRequest(entry.uid),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.green,
                                          ),
                                      child: const Text('Chấp nhận'),
                                    ),
                                    TextButton(
                                          onPressed: () => _followService.declineRequest(entry.uid),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                      child: const Text('Từ chối'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  void _showColorPicker(BuildContext context) {
    final presetColors = [
      '#FF5733', '#33FF57', '#3357FF', '#FF33F5', '#F5FF33',
      '#33FFF5', '#FF8C33', '#8C33FF', '#33FF8C', '#FF3333',
      '#33FF33', '#3333FF', '#FFFF33', '#FF33FF', '#33FFFF',
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn màu chủ đạo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // Preset colors
                ...presetColors.map((color) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _themeColor = color;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _parseColor(color),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                  );
                }),
                // Custom color picker (simple text input)
                GestureDetector(
                  onTap: () => _showCustomColorDialog(context),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Icon(Icons.tune),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _themeColor = null;
                });
                Navigator.pop(context);
              },
              child: const Text('Xóa màu'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomColorDialog(BuildContext context) {
    final controller = TextEditingController(text: _themeColor ?? '#');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Màu tùy chỉnh'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Mã màu hex (ví dụ: #FF5733)',
            hintText: '#FF5733',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final color = controller.text.trim();
              if (color.isNotEmpty && color.startsWith('#')) {
                try {
                  _parseColor(color); // Validate
                  setState(() {
                    _themeColor = color;
                  });
                  Navigator.pop(context);
                  Navigator.pop(context); // Close color picker too
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mã màu không hợp lệ')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mã màu phải bắt đầu bằng #')),
                );
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showAddLinkDialog(BuildContext context) {
    final labelController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm liên kết'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: 'Nhãn (ví dụ: Website, Instagram)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com',
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final label = labelController.text.trim();
              final url = urlController.text.trim();
              if (label.isEmpty || url.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')),
                );
                return;
              }
              if (!url.startsWith('http://') && !url.startsWith('https://')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL phải bắt đầu bằng http:// hoặc https://')),
                );
                return;
              }
              setState(() {
                _links.add(ProfileLink(url: url, label: label));
              });
              Navigator.pop(context);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditNoteDialog(String uid) async {
    final controller = TextEditingController(text: noteController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cập nhật ghi chú'),
        content: TextField(
          controller: controller,
          maxLength: 50,
          decoration: const InputDecoration(
            hintText: 'Nhập ghi chú (tối đa 50 ký tự)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.length > 50) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ghi chú tối đa 50 ký tự'),
                  ),
                );
                return;
              }
              Navigator.pop(context, text);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      await userProfileRepository.updateProfile(uid, note: result);
      setState(() {
        noteController.text = result;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật ghi chú.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật ghi chú: $e')),
      );
    }
  }

  Future<void> _handleMenuAction(_ProfileMenuAction action) async {
    final user = authRepository.currentUser();
    if (user == null) return;

    switch (action) {
      case _ProfileMenuAction.personalInfo:
        await _showPersonalInfoModal(user.uid);
        break;
      case _ProfileMenuAction.privateAccount:
        await _togglePrivateAccount(user.uid);
        break;
      case _ProfileMenuAction.highlightStories:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ManageHighlightStoriesPage(uid: user.uid),
          ),
        );
        break;
      case _ProfileMenuAction.privacySettings:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PrivacySettingsPage()),
        );
        break;
      case _ProfileMenuAction.savedPosts:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SavedPostsPage()),
        );
        break;
      case _ProfileMenuAction.changePassword:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
        );
        break;
      case _ProfileMenuAction.adminDashboard:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
        );
        break;
      case _ProfileMenuAction.logout:
        await _confirmLogoutAndMaybeSave(currentUser: user);
        break;
    }
  }

  Future<void> _showPersonalInfoModal(String uid) async {
    final displayNameCtrl = TextEditingController(text: displayNameController.text);
    final bioCtrl = TextEditingController(text: bioController.text);
    final photoUrlCtrl = TextEditingController(text: photoUrlController.text);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thông tin cá nhân'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: displayNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên hiển thị',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bioCtrl,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Tiểu sử (bio)',
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: photoUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ảnh đại diện (URL)',
                  prefixIcon: Icon(Icons.image),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showAvatarOptions(uid);
                },
                icon: const Icon(Icons.photo_library),
                label: const Text('Chọn ảnh từ thiết bị'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              displayNameController.text = displayNameCtrl.text;
              bioController.text = bioCtrl.text;
              photoUrlController.text = photoUrlCtrl.text;
              await _saveProfile(uid);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePrivateAccount(String uid) async {
    final newValue = !_isPrivate;
    setState(() {
      _isPrivate = newValue;
    });
    try {
      await userProfileRepository.updateProfile(uid, isPrivate: newValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue
                  ? 'Đã bật tài khoản riêng tư'
                  : 'Đã tắt tài khoản riêng tư',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isPrivate = !newValue;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật: $e')),
        );
      }
    }
  }

  Future<void> _showCustomizationModal(String uid) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tùy biến'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Màu chủ đạo'),
                subtitle: Text(_themeColor ?? 'Chưa chọn màu'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_themeColor != null)
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _parseColor(_themeColor!),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.color_lens, color: AppColors.primaryPink),
                      onPressed: () {
                        Navigator.pop(context);
                        _showColorPicker(context);
                      },
                    ),
                    if (_themeColor != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _themeColor = null;
                          });
                          Navigator.pop(context);
                          _saveProfile(uid);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Liên kết ngoài',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_links.isEmpty)
                const Text(
                  'Chưa có liên kết nào',
                  style: TextStyle(color: Colors.grey),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _links.asMap().entries.map((entry) {
                    final index = entry.key;
                    final link = entry.value;
                    return Chip(
                      label: Text(link.label),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {
                        setState(() {
                          _links.removeAt(index);
                        });
                        _saveProfile(uid);
                      },
                    );
                  }).toList(),
                ),
              if (_links.length < 5) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showAddLinkDialog(context);
                  },
                  icon: const Icon(Icons.add, color: AppColors.primaryPink),
                  label: const Text('Thêm liên kết'),
                ),
              ],
            ],
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

  void _showProfileOptionsSheet(User user) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Tùy chọn tài khoản',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person, color: AppColors.primaryPink),
              title: const Text('Thông tin cá nhân'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _handleMenuAction(_ProfileMenuAction.personalInfo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline, color: AppColors.primaryPink),
              title: const Text('Tài khoản riêng tư'),
              trailing: StreamBuilder<UserProfile?>(
                stream: userProfileRepository.watchProfile(user.uid),
                builder: (context, snapshot) {
                  final isPrivate = snapshot.data?.isPrivate ?? false;
                  return Switch(
                    value: isPrivate,
                    onChanged: (value) {
                      Navigator.pop(context);
                      _handleMenuAction(_ProfileMenuAction.privateAccount);
                    },
                  );
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: AppColors.primaryPink),
              title: const Text('Highlight Stories'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _handleMenuAction(_ProfileMenuAction.highlightStories);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.privacy_tip, color: AppColors.primaryPink),
              title: const Text('Quyền riêng tư'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _handleMenuAction(_ProfileMenuAction.privacySettings);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark, color: AppColors.primaryPink),
              title: const Text('Đã lưu'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _handleMenuAction(_ProfileMenuAction.savedPosts);
              },
            ),
            if (user.email != null &&
                user.providerData.any((p) => p.providerId == 'password'))
              ListTile(
                leading: const Icon(Icons.lock, color: AppColors.primaryPink),
                title: const Text('Đổi mật khẩu'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  _handleMenuAction(_ProfileMenuAction.changePassword);
                },
              ),
            if (_isAdmin)
              ListTile(
                leading:
                    const Icon(Icons.admin_panel_settings, color: AppColors.primaryPink),
                title: const Text('Admin Dashboard'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  _handleMenuAction(_ProfileMenuAction.adminDashboard);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _FollowersFollowingSheet extends StatefulWidget {
  const _FollowersFollowingSheet({
    required this.uid,
    required this.isFollowers,
  });

  final String uid;
  final bool isFollowers;

  @override
  State<_FollowersFollowingSheet> createState() => _FollowersFollowingSheetState();
}

class _FollowersFollowingSheetState extends State<_FollowersFollowingSheet> {
  final FollowService _followService = FollowService();
  final ChatRepository _chatRepository = ChatRepository();
  final authRepository = FirebaseAuthRepository();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.isFollowers ? 'Người theo dõi' : 'Đang theo dõi',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              // List
              Expanded(
                child: StreamBuilder<List<FollowEntry>>(
                  stream: widget.isFollowers
                      ? _followService.watchFollowersEntries(widget.uid)
                      : _followService.watchFollowingEntries(widget.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Lỗi: ${snapshot.error}'),
                      );
                    }
                    final entries = snapshot.data ?? [];
                    if (entries.isEmpty) {
                      return Center(
                        child: Text(
                          widget.isFollowers
                              ? 'Chưa có người theo dõi'
                              : 'Chưa theo dõi ai',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final profile = entry.profile;
                        if (profile == null) {
                          return const SizedBox.shrink();
                        }
                        return _FollowListItem(
                          profile: profile,
                          isMutual: entry.isMutual,
                          onAvatarTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PublicProfilePage(
                                  uid: entry.uid,
                                ),
                              ),
                            );
                          },
                          onMessageTap: () async {
                            final currentUid = authRepository.currentUser()?.uid;
                            if (currentUid == null) return;
                            try {
                              final conversationId =
                                  await _chatRepository.createOrGetDirectConversation(
                                currentUid: currentUid,
                                otherUid: entry.uid,
                              );
                              if (!mounted) return;
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatDetailPage(
                                    conversationId: conversationId,
                                    otherUid: entry.uid,
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Lỗi: ${e.toString()}'),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FollowListItem extends StatelessWidget {
  const _FollowListItem({
    required this.profile,
    required this.isMutual,
    required this.onAvatarTap,
    required this.onMessageTap,
  });

  final UserProfile profile;
  final bool isMutual;
  final VoidCallback onAvatarTap;
  final VoidCallback onMessageTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: GestureDetector(
        onTap: onAvatarTap,
        child: CircleAvatar(
          radius: 28,
          backgroundImage: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
              ? NetworkImage(profile.photoUrl!)
              : null,
          backgroundColor: profile.photoUrl == null || profile.photoUrl!.isEmpty
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: profile.photoUrl == null || profile.photoUrl!.isEmpty
              ? Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 28,
                )
              : null,
        ),
      ),
      title: Text(
        profile.displayName ?? profile.email ?? profile.uid,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: profile.email != null && profile.email != profile.displayName
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    profile.email!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isMutual)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Bạn bè',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            )
          : isMutual
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Theo dõi lại',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : null,
      trailing: IconButton(
        icon: const Icon(Icons.message),
        onPressed: onMessageTap,
        tooltip: 'Nhắn tin',
      ),
    );
  }
}

class _EditProfileHeader extends StatelessWidget {
  const _EditProfileHeader({
    required this.displayName,
    required this.photoUrl,
    required this.statusText,
    required this.onAddPressed,
    required this.onAccountMenuPressed,
    required this.onAvatarTap,
    required this.note,
    required this.onNoteTap,
    required this.hasActiveStory,
    required this.storyRingColor,
    this.themeColor,
    this.isUploading = false,
  });

  final String displayName;
  final String photoUrl;
  final String statusText;
  final String note;
  final Color? themeColor;
  final bool isUploading;
  final VoidCallback onAddPressed;
  final VoidCallback onAccountMenuPressed;
  final VoidCallback onAvatarTap;
  final VoidCallback onNoteTap;
  final bool hasActiveStory;
  final Color? storyRingColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon ảo bên trái để cân đối layout, không nhận tương tác
              IgnorePointer(
                child: Opacity(
                  opacity: 0,
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.keyboard_arrow_down, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: onAccountMenuPressed,
                icon: const Icon(Icons.keyboard_arrow_down, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Avatar (tap để đổi ảnh) + vòng story (hồng/xám)
              GestureDetector(
                onTap: onAvatarTap,
                child: Hero(
                  tag: 'profile_avatar_fullscreen',
                child: Container(
                  decoration: hasActiveStory && storyRingColor != null
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: storyRingColor!,
                              width: 3.5,
                          ),
                        )
                      : null,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage:
                        photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty
                        ? const Icon(Icons.person, size: 48)
                        : isUploading
                            ? Container(
                                color: Colors.black54,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                  ),
                                ),
                              )
                            : null,
                    ),
                  ),
                ),
              ),
              // Nút + đăng story/post
              Positioned(
                right: -6,
                bottom: -6,
                child: GestureDetector(
                  // Dấu + để đăng story / post
                  onTap: onAddPressed,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryPink,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ),
              // Bong bóng ghi chú đè lên avatar
              Positioned(
                top: 6,
                left: 0,
                right: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: onNoteTap,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.95, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Transform.scale(scale: value, child: child);
                    },
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          note.isNotEmpty ? note : 'Thêm ghi chú...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            displayName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            statusText,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _HighlightStoryBubble extends StatelessWidget {
  const _HighlightStoryBubble({
    required this.highlight,
    required this.firstStory,
    required this.authorUid,
    required this.onTap,
  });

  final HighlightStory highlight;
  final Story firstStory;
  final String authorUid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.purple, width: 2.5),
              ),
              child: ClipOval(
                child: firstStory.thumbnailUrl != null
                    ? Image.network(
                        firstStory.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : firstStory.type == StoryMediaType.image
                        ? Image.network(
                            firstStory.mediaUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              highlight.name,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Icon(
        firstStory.type == StoryMediaType.video ? Icons.videocam : Icons.image,
        color: Colors.grey[600],
        size: 30,
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primaryPink.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryPink.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryPink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primaryPink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


