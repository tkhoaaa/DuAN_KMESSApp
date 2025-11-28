import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'user_profile_repository.dart';
import '../auth/auth_repository.dart';
import '../follow/services/follow_service.dart';
import '../../services/cloudinary_service.dart';
import '../saved_posts/pages/saved_posts_page.dart';

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
  String? _themeColor;
  List<ProfileLink> _links = [];
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
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark),
            tooltip: 'Bài viết đã lưu',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SavedPostsPage(),
                ),
              );
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
            _isPrivate = profile.isPrivate;
            _themeColor = profile.themeColor;
            _links = List<ProfileLink>.from(profile.links);
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
                // Tùy biến section
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Tùy biến',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Theme Color
                ListTile(
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
                        icon: const Icon(Icons.color_lens),
                        onPressed: () => _showColorPicker(context),
                      ),
                      if (_themeColor != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _themeColor = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Links
                const Text(
                  'Liên kết ngoài',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ..._links.asMap().entries.map((entry) {
                  final index = entry.key;
                  final link = entry.value;
                  return Card(
                    child: ListTile(
                      title: Text(link.label),
                      subtitle: Text(link.url),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _links.removeAt(index);
                          });
                        },
                      ),
                    ),
                  );
                }),
                if (_links.length < 5)
                  OutlinedButton.icon(
                    onPressed: () => _showAddLinkDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm liên kết'),
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

