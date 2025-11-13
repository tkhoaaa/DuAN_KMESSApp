import 'package:flutter/material.dart';

import '../auth/auth_repository.dart';
import '../chat/pages/chat_detail_page.dart';
import '../chat/repositories/chat_repository.dart';
import '../follow/models/follow_state.dart';
import '../follow/services/follow_service.dart';
import 'user_profile_repository.dart';

class PublicProfilePage extends StatelessWidget {
  const PublicProfilePage({
    required this.uid,
    super.key,
  });

  final String uid;

  @override
  Widget build(BuildContext context) {
    final currentUid = authRepository.currentUser()?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang cá nhân'),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: userProfileRepository.watchProfile(uid),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (profile == null) {
            return const Center(child: Text('Không tìm thấy người dùng.'));
          }

          final displayName = profile.displayName?.isNotEmpty == true
              ? profile.displayName!
              : (profile.email?.isNotEmpty == true
                  ? profile.email!
                  : profile.uid);

          return Column(
            children: [
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 48,
                backgroundImage: profile.photoUrl != null
                    ? NetworkImage(profile.photoUrl!)
                    : null,
                child: profile.photoUrl == null
                    ? const Icon(Icons.person, size: 48)
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (profile.bio?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    profile.bio!,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatTile(label: 'Người theo dõi', value: profile.followersCount),
                  _StatTile(label: 'Đang theo dõi', value: profile.followingCount),
                ],
              ),
              const SizedBox(height: 16),
              if (currentUid == null)
                const Text('Đăng nhập để theo dõi hoặc nhắn tin.')
              else
                _FollowActions(
                  currentUid: currentUid,
                  targetUid: uid,
                  isTargetPrivate: profile.isPrivate,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FollowActions extends StatefulWidget {
  const _FollowActions({
    required this.currentUid,
    required this.targetUid,
    required this.isTargetPrivate,
  });

  final String currentUid;
  final String targetUid;
  final bool isTargetPrivate;

  @override
  State<_FollowActions> createState() => _FollowActionsState();
}

class _FollowActionsState extends State<_FollowActions> {
  late final FollowService _followService;
  late final ChatRepository _chatRepository;

  @override
  void initState() {
    super.initState();
    _followService = FollowService();
    _chatRepository = ChatRepository();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUid == widget.targetUid) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Đây là tài khoản của bạn.'),
      );
    }
    return StreamBuilder<FollowState>(
      stream: _followService.watchFollowState(
        widget.currentUid,
        widget.targetUid,
      ),
      builder: (context, snapshot) {
        final state = snapshot.data ??
            FollowState(
              status: FollowStatus.none,
              isTargetPrivate: widget.isTargetPrivate,
            );
        final buttons = <Widget>[];

        switch (state.status) {
          case FollowStatus.self:
            buttons.add(const Text('Đây là bạn.'));
            break;
          case FollowStatus.following:
            buttons.add(
              FilledButton(
                onPressed: () =>
                    _followService.unfollow(widget.targetUid),
                child: const Text('Bỏ theo dõi'),
              ),
            );
            buttons.add(
              OutlinedButton(
                onPressed: () async {
                  final conversationId =
                      await _chatRepository.createOrGetDirectConversation(
                    currentUid: widget.currentUid,
                    otherUid: widget.targetUid,
                  );
                  if (!mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatDetailPage(
                        conversationId: conversationId,
                        otherUid: widget.targetUid,
                      ),
                    ),
                  );
                },
                child: const Text('Nhắn tin'),
              ),
            );
            break;
          case FollowStatus.requested:
            buttons.add(
              const Text('Đã gửi yêu cầu theo dõi'),
            );
            buttons.add(
              TextButton(
                onPressed: () => _followService.cancelRequest(widget.targetUid),
                child: const Text('Huỷ yêu cầu'),
              ),
            );
            break;
          case FollowStatus.none:
            buttons.add(
              FilledButton(
                onPressed: () => _followService.followUser(widget.targetUid),
                child: const Text('Theo dõi'),
              ),
            );
            break;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: buttons,
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}

