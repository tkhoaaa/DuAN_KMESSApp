import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../follow/services/follow_service.dart';
import '../services/conversation_service.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ConversationService _conversationService = ConversationService();
  final FollowService _followService = FollowService();
  final Set<String> _selectedUids = <String>{};
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final user = authRepository.currentUser();
    if (user == null) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên nhóm.')),
      );
      return;
    }
    if (_selectedUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 1 thành viên.')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      await _conversationService.createGroup(
        ownerUid: user.uid,
        memberIds: _selectedUids.toList(),
        name: name,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tạo nhóm: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = authRepository.currentUser();
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Bạn cần đăng nhập để tạo nhóm.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo nhóm mới'),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createGroup,
            child: _isCreating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Tạo'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên nhóm',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả (tuỳ chọn)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Chọn thành viên (từ danh sách bạn đang theo dõi):',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: StreamBuilder<List<FollowEntry>>(
              stream: _followService.watchFollowingEntries(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = snapshot.data ?? [];
                if (entries.isEmpty) {
                  return const Center(
                    child: Text('Bạn chưa theo dõi ai để thêm vào nhóm.'),
                  );
                }
                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final profile = entry.profile;
                    final uid = entry.uid;
                    final title = profile?.displayName?.isNotEmpty == true
                        ? profile!.displayName!
                        : (profile?.email?.isNotEmpty == true
                            ? profile!.email!
                            : uid);
                    final avatarUrl = profile?.photoUrl;
                    final selected = _selectedUids.contains(uid);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedUids.add(uid);
                          } else {
                            _selectedUids.remove(uid);
                          }
                        });
                      },
                      title: Text(title),
                      secondary: CircleAvatar(
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


