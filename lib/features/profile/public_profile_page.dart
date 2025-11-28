import 'package:flutter/material.dart';

import '../auth/auth_repository.dart';
import '../chat/pages/chat_detail_page.dart';
import '../chat/repositories/chat_repository.dart';
import '../follow/models/follow_state.dart';
import '../follow/services/follow_service.dart';
import '../safety/services/block_service.dart';
import '../safety/services/report_service.dart';
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
        actions: currentUid != null && currentUid != uid
            ? [
                _ProfileMoreMenu(
                  targetUid: uid,
                ),
              ]
            : null,
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

          String statusText;
          if (profile.isOnline) {
            statusText = 'Đang hoạt động';
          } else if (profile.lastSeen != null) {
            final diff = DateTime.now().difference(profile.lastSeen!);
            if (diff.inMinutes < 1) {
              statusText = 'Vừa mới hoạt động';
            } else if (diff.inHours < 1) {
              statusText = 'Hoạt động ${diff.inMinutes} phút trước';
            } else if (diff.inDays < 1) {
              statusText = 'Hoạt động ${diff.inHours} giờ trước';
            } else {
              statusText = 'Hoạt động ${diff.inDays} ngày trước';
            }
          } else {
            statusText = 'Ngoại tuyến';
          }

          final userUid = currentUid;
          final canCheckBlocking =
              userUid != null && userUid.isNotEmpty && userUid != uid;
          Stream<bool> createBlockedByMeStream() {
            final resolvedUid = userUid;
            if (!canCheckBlocking || resolvedUid == null) {
              return Stream<bool>.value(false);
            }
            return blockService.watchIsBlocked(
              blockerUid: resolvedUid,
              blockedUid: uid,
            );
          }

          Stream<bool> createBlockedMeStream() {
            final resolvedUid = userUid;
            if (!canCheckBlocking || resolvedUid == null) {
              return Stream<bool>.value(false);
            }
            return blockService.watchIsBlocked(
              blockerUid: uid,
              blockedUid: resolvedUid,
            );
          }

          final blockedByMeStream = createBlockedByMeStream();
          final blockedMeStream = createBlockedMeStream();

          return StreamBuilder<bool>(
            stream: blockedByMeStream,
            builder: (context, blockedByMeSnapshot) {
              final blockedByMe = blockedByMeSnapshot.data ?? false;
              return StreamBuilder<bool>(
                stream: blockedMeStream,
                builder: (context, blockedMeSnapshot) {
                  final blockedByTarget = blockedMeSnapshot.data ?? false;
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
                      const SizedBox(height: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (blockedByTarget)
                        _BlockedInfoBanner(
                          message:
                              '$displayName đã chặn bạn. Bạn không thể tương tác với tài khoản này.',
                        )
                      else if (blockedByMe)
                        _BlockedInfoBanner(
                          message:
                              'Bạn đã chặn $displayName. Bỏ chặn để tiếp tục theo dõi hoặc nhắn tin.',
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
                      if (currentUid == null)
                        const Text('Đăng nhập để theo dõi hoặc nhắn tin.')
                      else
                        _FollowActions(
                          currentUid: currentUid,
                          targetUid: uid,
                          isTargetPrivate: profile.isPrivate,
                          isBlockedByCurrent: blockedByMe,
                          isBlockedByTarget: blockedByTarget,
                        ),
                    ],
                  );
                },
              );
            },
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
    required this.isBlockedByCurrent,
    required this.isBlockedByTarget,
  });

  final String currentUid;
  final String targetUid;
  final bool isTargetPrivate;
  final bool isBlockedByCurrent;
  final bool isBlockedByTarget;

  @override
  State<_FollowActions> createState() => _FollowActionsState();
}

class _FollowActionsState extends State<_FollowActions> {
  late final FollowService _followService;
  late final ChatRepository _chatRepository;
  final BlockService _blockService = blockService;

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
    if (widget.isBlockedByCurrent) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const Text(
              'Bạn đang chặn người này.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _handleUnblock,
              child: const Text('Bỏ chặn'),
            ),
          ],
        ),
      );
    }
    if (widget.isBlockedByTarget) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Người này đã chặn bạn. Bạn không thể theo dõi hoặc nhắn tin.',
          textAlign: TextAlign.center,
        ),
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
                  final isBlocked = await _blockService.isEitherBlocked(
                    widget.currentUid,
                    widget.targetUid,
                  );
                  if (isBlocked) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Không thể nhắn tin vì đã bị chặn.'),
                      ),
                    );
                    return;
                  }
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

  Future<void> _handleUnblock() async {
    try {
      await _blockService.unblockUser(widget.targetUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã bỏ chặn người dùng.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể bỏ chặn: $e')),
      );
    }
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

class _ProfileMoreMenu extends StatelessWidget {
  const _ProfileMoreMenu({required this.targetUid});

  final String targetUid;

  @override
  Widget build(BuildContext context) {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null || currentUid == targetUid) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<bool>(
      stream: blockService.watchIsBlocked(
        blockerUid: currentUid,
        blockedUid: targetUid,
      ),
      builder: (context, snapshot) {
        final isBlocked = snapshot.data ?? false;
        return PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) => _handleSelection(context, value),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: isBlocked ? 'unblock' : 'block',
              child: Row(
                children: [
                  Icon(
                    isBlocked ? Icons.lock_open : Icons.block,
                    color: isBlocked ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(isBlocked ? 'Bỏ chặn' : 'Chặn'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.flag_outlined, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Báo cáo'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSelection(
    BuildContext context,
    String value,
  ) async {
    switch (value) {
      case 'block':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Chặn người dùng'),
            content: const Text(
              'Bạn sẽ không nhìn thấy nội dung và không thể tương tác với người dùng này. Tiếp tục?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Chặn'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          try {
            await blockService.blockUser(targetUid: targetUid);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã chặn người dùng.')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Không thể chặn: $e')),
              );
            }
          }
        }
        break;
      case 'unblock':
        try {
          await blockService.unblockUser(targetUid);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã bỏ chặn.')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Không thể bỏ chặn: $e')),
            );
          }
        }
        break;
      case 'report':
        await _showReportSheet(context);
        break;
    }
  }

  Future<void> _showReportSheet(BuildContext context) async {
    final reasons = [
      'Spam / Quảng cáo',
      'Giả mạo',
      'Quấy rối',
      'Nội dung không phù hợp',
      'Khác',
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons
              .map(
                (item) => ListTile(
                  title: Text(item),
                  onTap: () => Navigator.pop(context, item),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (reason == null) return;
    try {
      await reportService.reportUser(
        targetUid: targetUid,
        reason: reason,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi báo cáo.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể báo cáo: $e')),
        );
      }
    }
  }
}

class _BlockedInfoBanner extends StatelessWidget {
  const _BlockedInfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

