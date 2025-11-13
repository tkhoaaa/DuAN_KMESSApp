import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'user_profile_repository.dart';
import '../auth/auth_repository.dart';
import '../follow/services/follow_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController displayNameController = TextEditingController();
  final TextEditingController photoUrlController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool isSaving = false;
  bool isUploading = false;
  bool _loadedInitial = false;
  bool _isPrivate = false;
  late final FollowService _followService;

  @override
  void initState() {
    super.initState();
    _followService = FollowService();
  }

  @override
  void dispose() {
    displayNameController.dispose();
    photoUrlController.dispose();
    bioController.dispose();
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
        isPrivate: _isPrivate,
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

      final url = await storageRef.getDownloadURL();
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
        title: const Text('Hồ sơ của bạn'),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: userProfileRepository.watchProfile(user.uid),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          if (!_loadedInitial && profile != null) {
            displayNameController.text = profile.displayName ?? '';
            photoUrlController.text = profile.photoUrl ?? '';
            bioController.text = profile.bio ?? '';
            _isPrivate = profile.isPrivate;
            _loadedInitial = true;
          }

          final isBusy = isSaving || isUploading;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage: (photoUrlController.text.isNotEmpty)
                        ? NetworkImage(photoUrlController.text)
                        : null,
                    child: photoUrlController.text.isEmpty
                        ? const Icon(Icons.person, size: 48)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: isBusy
                          ? null
                          : () => _pickAndUploadImage(
                                user.uid,
                                ImageSource.gallery,
                              ),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Chọn ảnh'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: isBusy
                          ? null
                          : () =>
                              _pickAndUploadImage(user.uid, ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Chụp ảnh'),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: isBusy || photoUrlController.text.isEmpty
                      ? null
                      : () => _removePhoto(user.uid),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Xoá ảnh đại diện'),
                ),
                const SizedBox(height: 16),
                if (profile != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatTile(
                        label: 'Người theo dõi',
                        value: profile.followersCount,
                      ),
                      _StatTile(
                        label: 'Đang theo dõi',
                        value: profile.followingCount,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: displayNameController,
                  decoration: const InputDecoration(labelText: 'Tên hiển thị'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: photoUrlController,
                  decoration:
                      const InputDecoration(labelText: 'Ảnh đại diện (URL)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Tiểu sử (bio)'),
                ),
                SwitchListTile(
                  value: _isPrivate,
                  onChanged: (value) {
                    setState(() {
                      _isPrivate = value;
                    });
                  },
                  title: const Text('Tài khoản riêng tư'),
                  subtitle: const Text(
                      'Yêu cầu theo dõi cần được bạn chấp nhận.'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isBusy ? null : () => _saveProfile(user.uid),
                  child: isBusy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Lưu thay đổi'),
                ),
                const SizedBox(height: 24),
                if (profile != null) ...[
                  Text('Email: ${user.email ?? "(không có)"}'),
                  Text(
                    'Số điện thoại: ${profile.phoneNumber?.isNotEmpty == true ? profile.phoneNumber : "(không có)"}',
                  ),
                  if (profile.bio?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text('Bio: ${profile.bio}'),
                  ],
                  const SizedBox(height: 16),
                  StreamBuilder<List<FollowRequestEntry>>(
                    stream:
                        _followService.watchIncomingRequestEntries(user.uid),
                    builder: (context, requestSnapshot) {
                      final requests = requestSnapshot.data ?? [];
                      if (requests.isEmpty) {
                        if (!_isPrivate) {
                          return const SizedBox.shrink();
                        }
                        return const Text(
                          'Không có yêu cầu theo dõi đang chờ.',
                          style: TextStyle(color: Colors.grey),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Yêu cầu theo dõi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...requests.map(
                            (entry) => Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: entry.profile?.photoUrl !=
                                          null
                                      ? NetworkImage(entry.profile!.photoUrl!)
                                      : null,
                                  child: entry.profile?.photoUrl == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(
                                  entry.profile?.displayName?.isNotEmpty ==
                                          true
                                      ? entry.profile!.displayName!
                                      : (entry.profile?.email?.isNotEmpty ==
                                              true
                                          ? entry.profile!.email!
                                          : entry.uid),
                                ),
                                subtitle: entry.createdAt != null
                                    ? Text(
                                        'Yêu cầu lúc ${entry.createdAt}',
                                      )
                                    : null,
                                trailing: Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: () =>
                                          _followService.acceptRequest(
                                              entry.uid),
                                      child: const Text('Chấp nhận'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          _followService.declineRequest(
                                              entry.uid),
                                      child: const Text('Từ chối'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}

