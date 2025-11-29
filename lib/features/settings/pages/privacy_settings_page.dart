import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../profile/user_profile_repository.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  final UserProfileRepository _profileRepository = userProfileRepository;
  String? _currentUid;
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isSaving = false;

  bool _showOnlineStatus = true;
  LastSeenVisibility _lastSeenVisibility = LastSeenVisibility.everyone;
  MessagePermission _messagePermission = MessagePermission.everyone;

  @override
  void initState() {
    super.initState();
    _currentUid = authRepository.currentUser()?.uid;
    if (_currentUid != null) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    if (_currentUid == null) return;

    try {
      final profile = await _profileRepository.fetchProfile(_currentUid!);
      if (profile != null && mounted) {
        setState(() {
          _profile = profile;
          _showOnlineStatus = profile.showOnlineStatus;
          _lastSeenVisibility = profile.lastSeenVisibility;
          _messagePermission = profile.messagePermission;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải cài đặt: $e')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_currentUid == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _profileRepository.updatePrivacySettings(
        _currentUid!,
        showOnlineStatus: _showOnlineStatus,
        lastSeenVisibility: _lastSeenVisibility,
        messagePermission: _messagePermission,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu cài đặt riêng tư'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu cài đặt: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUid == null) {
      return const Scaffold(
        body: Center(child: Text('Bạn cần đăng nhập.')),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quyền riêng tư'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveSettings,
              child: const Text('Lưu'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section: Trạng thái hoạt động
            _buildSectionHeader(
              title: 'Trạng thái hoạt động',
              icon: Icons.access_time,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _showOnlineStatus,
              onChanged: (value) {
                setState(() {
                  _showOnlineStatus = value;
                });
              },
              title: const Text('Hiển thị trạng thái online'),
              subtitle: const Text(
                'Khi tắt, mọi người sẽ không thấy bạn đang online',
              ),
            ),
            const SizedBox(height: 8),
            _buildSubSectionTitle('Ai có thể xem last seen'),
            RadioListTile<LastSeenVisibility>(
              value: LastSeenVisibility.everyone,
              groupValue: _lastSeenVisibility,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _lastSeenVisibility = value;
                  });
                }
              },
              title: const Text('Mọi người'),
              subtitle: const Text('Tất cả người dùng có thể xem'),
            ),
            RadioListTile<LastSeenVisibility>(
              value: LastSeenVisibility.followers,
              groupValue: _lastSeenVisibility,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _lastSeenVisibility = value;
                  });
                }
              },
              title: const Text('Chỉ người theo dõi'),
              subtitle: const Text('Chỉ những người đang theo dõi bạn'),
            ),
            RadioListTile<LastSeenVisibility>(
              value: LastSeenVisibility.nobody,
              groupValue: _lastSeenVisibility,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _lastSeenVisibility = value;
                  });
                }
              },
              title: const Text('Không ai'),
              subtitle: const Text('Không ai có thể xem last seen'),
            ),

            const SizedBox(height: 32),

            // Section: Tin nhắn
            _buildSectionHeader(
              title: 'Tin nhắn',
              icon: Icons.chat,
            ),
            const SizedBox(height: 8),
            _buildSubSectionTitle('Ai có thể nhắn tin cho bạn'),
            RadioListTile<MessagePermission>(
              value: MessagePermission.everyone,
              groupValue: _messagePermission,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _messagePermission = value;
                  });
                }
              },
              title: const Text('Mọi người'),
              subtitle: const Text('Tất cả người dùng có thể nhắn tin'),
            ),
            RadioListTile<MessagePermission>(
              value: MessagePermission.followers,
              groupValue: _messagePermission,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _messagePermission = value;
                  });
                }
              },
              title: const Text('Chỉ người theo dõi'),
              subtitle: const Text('Chỉ những người đang theo dõi bạn'),
            ),
            RadioListTile<MessagePermission>(
              value: MessagePermission.nobody,
              groupValue: _messagePermission,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _messagePermission = value;
                  });
                }
              },
              title: const Text('Không ai'),
              subtitle: const Text('Không ai có thể nhắn tin cho bạn'),
            ),

            const SizedBox(height: 32),

            // Section: Giải thích
            _buildSectionHeader(
              title: 'Giải thích',
              icon: Icons.info_outline,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoItem(
                      'Trạng thái online',
                      'Hiển thị dấu chấm xanh khi bạn đang hoạt động trong app',
                    ),
                    const SizedBox(height: 16),
                    _buildInfoItem(
                      'Last seen',
                      'Thời gian bạn hoạt động lần cuối (ví dụ: "Hoạt động 5 phút trước")',
                    ),
                    const SizedBox(height: 16),
                    _buildInfoItem(
                      'Quyền nhắn tin',
                      'Kiểm soát ai có thể bắt đầu cuộc trò chuyện với bạn',
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

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildSubSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

