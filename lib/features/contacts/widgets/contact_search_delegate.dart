import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../profile/user_profile_repository.dart';
import '../../follow/services/follow_service.dart';
import '../../follow/models/follow_state.dart';
import '../../profile/public_profile_page.dart';

class ContactSearchDelegate extends SearchDelegate<void> {
  ContactSearchDelegate({
    required FollowService service,
  }) : _service = service;

  final FollowService _service;
  final _history = <String>[];

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(child: Text('Nhập email hoặc tên người dùng để tìm.'));
    }
    _history.remove(query);
    _history.insert(0, query);
    return _buildResultList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty && _history.isNotEmpty) {
      return ListView(
        children: _history
            .map(
              (item) => ListTile(
                leading: const Icon(Icons.history),
                title: Text(item),
                onTap: () {
                  query = item;
                  showResults(context);
                },
              ),
            )
            .toList(),
      );
    }
    return Container();
  }

  Widget _buildResultList(BuildContext context) {
    return FutureBuilder<List<UserProfile>>(
      future: _service.searchUsers(keyword: query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }
        final profiles = snapshot.data ?? [];
        if (profiles.isEmpty) {
          return const Center(child: Text('Không tìm thấy người dùng.'));
        }
        final currentUid = authRepository.currentUser()?.uid;
        return ListView.separated(
          itemCount: profiles.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (context, index) {
            final profile = profiles[index];
            final isSelf = currentUid == profile.uid;
            return FutureBuilder<FollowStatus>(
              future: currentUid == null
                  ? Future.value(FollowStatus.none)
                  : _service.fetchFollowStatus(currentUid, profile.uid),
              builder: (context, statusSnapshot) {
                final status = statusSnapshot.data ?? FollowStatus.none;
                final subtitle = _statusLabel(status, profile.isPrivate, isSelf);
                final action = _actionButton(
                  context,
                  profile,
                  status,
                  isSelf,
                );
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: profile.photoUrl != null
                        ? NetworkImage(profile.photoUrl!)
                        : null,
                    child: profile.photoUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(
                    profile.displayName?.isNotEmpty == true
                        ? profile.displayName!
                        : (profile.email?.isNotEmpty == true
                            ? profile.email!
                            : profile.uid),
                  ),
                  subtitle: subtitle != null ? Text(subtitle) : null,
                  trailing: action,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PublicProfilePage(uid: profile.uid),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String? _statusLabel(
    FollowStatus status,
    bool isPrivate,
    bool isSelf,
  ) {
    if (isSelf) return 'Đây là bạn';
    switch (status) {
      case FollowStatus.self:
        return 'Đây là bạn';
      case FollowStatus.following:
        return 'Đang theo dõi';
      case FollowStatus.requested:
        return 'Đã gửi yêu cầu';
      case FollowStatus.none:
        return isPrivate ? 'Tài khoản riêng tư' : null;
    }
  }

  Widget? _actionButton(
    BuildContext context,
    UserProfile profile,
    FollowStatus status,
    bool isSelf,
  ) {
    if (isSelf) return null;
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) {
      return const Text('Đăng nhập');
    }

    switch (status) {
      case FollowStatus.self:
        return null;
      case FollowStatus.none:
        return TextButton(
          onPressed: () async {
            try {
              await _service.followUser(profile.uid);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã gửi yêu cầu theo dõi.')),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi: $e')),
              );
            }
          },
          child: const Text('Theo dõi'),
        );
      case FollowStatus.requested:
        return TextButton(
          onPressed: () => _service.cancelRequest(profile.uid),
          child: const Text('Huỷ yêu cầu'),
        );
      case FollowStatus.following:
        return TextButton(
          onPressed: () => _service.unfollow(profile.uid),
          child: const Text('Bỏ theo dõi'),
        );
    }
  }
}

