import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_repository.dart';
import '../chat/pages/chat_detail_page.dart';
import '../chat/repositories/chat_repository.dart';
import '../follow/models/follow_state.dart';
import '../follow/services/follow_service.dart';
import '../safety/services/block_service.dart';
import '../safety/services/report_service.dart';
import '../share/services/share_service.dart';
import '../posts/repositories/post_repository.dart';
import '../posts/models/post.dart';
import '../posts/models/post_media.dart';
import '../posts/pages/post_permalink_page.dart';
import 'user_profile_repository.dart';

class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({
    required this.uid,
    super.key,
  });

  final String uid;

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  final PostRepository _postRepository = PostRepository();
  final FollowService _followService = FollowService();
  List<Post> _pinnedPosts = [];
  List<Post> _allPosts = [];
  bool _isLoadingPosts = false;
  bool _isLoadingPinned = false;
  bool? _isFollowing;

  @override
  void initState() {
    super.initState();
    _loadPinnedPosts();
    _loadAllPosts();
  }

  Future<void> _loadPinnedPosts() async {
    setState(() {
      _isLoadingPinned = true;
    });

    try {
      final profile = await userProfileRepository.fetchProfile(widget.uid);
      if (profile == null || profile.pinnedPostIds.isEmpty) {
        setState(() {
          _pinnedPosts = [];
          _isLoadingPinned = false;
        });
        return;
      }

      final posts = <Post>[];
      for (final postId in profile.pinnedPostIds) {
        try {
          final post = await _postRepository.watchPost(postId).first;
          posts.add(post);
        } catch (e) {
          continue;
        }
      }

      setState(() {
        _pinnedPosts = posts;
        _isLoadingPinned = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPinned = false;
      });
    }
  }

  Future<void> _loadAllPosts() async {
    setState(() {
      _isLoadingPosts = true;
    });

    try {
      final pageResult = await _postRepository.fetchPostsByAuthor(
        authorUid: widget.uid,
        limit: 50,
      );

      final posts = pageResult.docs.map((doc) => Post.fromDoc(doc)).toList();

      setState(() {
        _allPosts = posts;
        _isLoadingPosts = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPosts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = authRepository.currentUser()?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang cá nhân'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final profile = await userProfileRepository.fetchProfile(widget.uid);
              final displayName = profile?.displayName ?? 'người dùng này';
              await ShareService.shareProfile(
                uid: widget.uid,
                displayName: displayName,
              );
            },
            tooltip: 'Chia sẻ profile',
          ),
          if (currentUid != null && currentUid != widget.uid)
            _ProfileMoreMenu(
              targetUid: widget.uid,
            ),
        ],
      ),
      body: StreamBuilder<UserProfile?>(
        stream: userProfileRepository.watchProfile(widget.uid),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (profile == null) {
            return const Center(child: Text('Không tìm thấy người dùng.'));
          }

          final now = DateTime.now();
          final isBanned = profile.banStatus != BanStatus.none &&
              (profile.banStatus == BanStatus.permanent ||
                  (profile.banExpiresAt != null &&
                      now.isBefore(profile.banExpiresAt!)));

          final displayName = profile.displayName?.isNotEmpty == true
              ? profile.displayName!
              : (profile.email?.isNotEmpty == true
                  ? profile.email!
                  : profile.uid);

          // Kiểm tra privacy settings để hiển thị status
          String statusText = 'Ngoại tuyến';
          final isViewer = currentUid == widget.uid;
          
          // Nếu là chính mình, luôn hiển thị status
          if (isViewer) {
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
            }
          } else if (currentUid != null) {
            // Kiểm tra privacy settings
            // Online status
            if (profile.showOnlineStatus && profile.isOnline) {
              statusText = 'Đang hoạt động';
            } else if (profile.lastSeen != null) {
              // Last seen visibility - cần check follow status
              // Sẽ được xử lý trong nested StreamBuilder
            }
          }

          final userUid = currentUid;
          final canCheckBlocking =
              userUid != null && userUid.isNotEmpty && userUid != widget.uid;
          Stream<bool> createBlockedByMeStream() {
            final resolvedUid = userUid;
            if (!canCheckBlocking || resolvedUid == null) {
              return Stream<bool>.value(false);
            }
            return blockService.watchIsBlocked(
              blockerUid: resolvedUid,
              blockedUid: widget.uid,
            );
          }

          Stream<bool> createBlockedMeStream() {
            final resolvedUid = userUid;
            if (!canCheckBlocking || resolvedUid == null) {
              return Stream<bool>.value(false);
            }
            return blockService.watchIsBlocked(
              blockerUid: widget.uid,
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
                  final themeColor = profile.themeColor != null
                      ? _parseColor(profile.themeColor!)
                      : null;

                  return Column(
                    children: [
                      const SizedBox(height: 24),
                      // Avatar with theme color border
                      Container(
                        decoration: themeColor != null
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: themeColor,
                                  width: 3,
                                ),
                              )
                            : null,
                        child: CircleAvatar(
                          radius: 48,
                          backgroundImage: profile.photoUrl != null
                              ? NetworkImage(profile.photoUrl!)
                              : null,
                          child: profile.photoUrl == null
                              ? const Icon(Icons.person, size: 48)
                              : null,
                        ),
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
                      // Hiển thị status với privacy check
                      if (currentUid == widget.uid)
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        )
                      else if (currentUid != null)
                        StreamBuilder<FollowState>(
                          stream: _followService.watchFollowState(
                            currentUid,
                            widget.uid,
                          ),
                          builder: (context, followSnapshot) {
                            final followState = followSnapshot.data ??
                                const FollowState(
                                  status: FollowStatus.none,
                                  isTargetPrivate: false,
                                );
                            final isFollowing =
                                followState.status == FollowStatus.following;

                            // Tính toán statusText dựa trên privacy settings
                            String displayStatus = 'Ngoại tuyến';
                            if (profile.showOnlineStatus && profile.isOnline) {
                              displayStatus = 'Đang hoạt động';
                            } else if (profile.lastSeen != null) {
                              bool canViewLastSeen = false;
                              switch (profile.lastSeenVisibility) {
                                case LastSeenVisibility.everyone:
                                  canViewLastSeen = true;
                                  break;
                                case LastSeenVisibility.followers:
                                  canViewLastSeen = isFollowing;
                                  break;
                                case LastSeenVisibility.nobody:
                                  canViewLastSeen = false;
                                  break;
                              }

                              if (canViewLastSeen) {
                                final diff =
                                    DateTime.now().difference(profile.lastSeen!);
                                if (diff.inMinutes < 1) {
                                  displayStatus = 'Vừa mới hoạt động';
                                } else if (diff.inHours < 1) {
                                  displayStatus =
                                      'Hoạt động ${diff.inMinutes} phút trước';
                                } else if (diff.inDays < 1) {
                                  displayStatus =
                                      'Hoạt động ${diff.inHours} giờ trước';
                                } else {
                                  displayStatus =
                                      'Hoạt động ${diff.inDays} ngày trước';
                                }
                              }
                            }

                            return Text(
                              displayStatus,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            );
                          },
                        )
                      else
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
                      if (isBanned) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.redAccent),
                            ),
                            child: const Text(
                              'Tài khoản này đã bị khóa. Bạn không thể xem nội dung hoặc tương tác với tài khoản này.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ] else if (profile.bio?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            profile.bio!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      // Links section
                      if (profile.links.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Liên kết',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: profile.links.map((link) {
                                  return _LinkChip(
                                    link: link,
                                    themeColor: themeColor,
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (!isBanned) ...[
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
                            targetUid: widget.uid,
                            isTargetPrivate: profile.isPrivate,
                            isBlockedByCurrent: blockedByMe,
                            isBlockedByTarget: blockedByTarget,
                            themeColor: themeColor,
                          ),
                        const SizedBox(height: 24),
                      ],
                      // Pinned Posts Section
                      if (!isBanned && _pinnedPosts.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: _pinnedPosts.length,
                            itemBuilder: (context, index) {
                              final post = _pinnedPosts[index];
                              return _PinnedPostItem(
                                post: post,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PostPermalinkPage(
                                        postId: post.id,
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
                      // Posts Grid Section
                      if (!isBanned) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
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
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                            ),
                            itemCount: _allPosts.length,
                            itemBuilder: (context, index) {
                              final post = _allPosts[index];
                              return _PostGridItem(
                                post: post,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PostPermalinkPage(
                                        postId: post.id,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                      ],
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
    this.themeColor,
  });

  final String currentUid;
  final String targetUid;
  final bool isTargetPrivate;
  final bool isBlockedByCurrent;
  final bool isBlockedByTarget;
  final Color? themeColor;

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
                style: widget.themeColor != null
                    ? FilledButton.styleFrom(
                        backgroundColor: widget.themeColor,
                      )
                    : null,
                onPressed: () =>
                    _followService.unfollow(widget.targetUid),
                child: const Text('Bỏ theo dõi'),
              ),
            );
            buttons.add(
              StreamBuilder<UserProfile?>(
                stream: userProfileRepository.watchProfile(widget.targetUid),
                builder: (context, profileSnapshot) {
                  final targetProfile = profileSnapshot.data;
                  final canMessage = targetProfile != null &&
                      userProfileRepository.canSendMessage(
                        senderUid: widget.currentUid,
                        receiverUid: widget.targetUid,
                        isFollowing: state.status == FollowStatus.following,
                        messagePermission: targetProfile.messagePermission,
                      );

                  return OutlinedButton(
                    onPressed: canMessage
                        ? () async {
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
                          }
                        : null,
                    child: const Text('Nhắn tin'),
                  );
                },
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
                style: widget.themeColor != null
                    ? FilledButton.styleFrom(
                        backgroundColor: widget.themeColor,
                      )
                    : null,
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

Color _parseColor(String hexColor) {
  try {
    return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
  } catch (e) {
    return Colors.blue;
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.link,
    this.themeColor,
  });

  final ProfileLink link;
  final Color? themeColor;

  IconData _getIconForUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('instagram')) return Icons.camera_alt;
    if (lower.contains('facebook')) return Icons.facebook;
    if (lower.contains('twitter') || lower.contains('x.com')) return Icons.alternate_email;
    if (lower.contains('youtube')) return Icons.play_circle;
    if (lower.contains('linkedin')) return Icons.business;
    if (lower.contains('github')) return Icons.code;
    return Icons.link;
  }

  Future<void> _launchUrl() async {
    final uri = Uri.parse(link.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        _getIconForUrl(link.url),
        size: 18,
        color: themeColor,
      ),
      label: Text(link.label),
      onPressed: _launchUrl,
      backgroundColor: themeColor?.withOpacity(0.1),
      side: themeColor != null
          ? BorderSide(color: themeColor!)
          : null,
    );
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

class _PinnedPostItem extends StatelessWidget {
  const _PinnedPostItem({
    required this.post,
    required this.onTap,
  });

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final firstMedia = post.media.isNotEmpty ? post.media.first : null;
    final isImage = firstMedia?.type == PostMediaType.image;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange, width: 2),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: firstMedia != null
                  ? (isImage
                      ? Image.network(
                          firstMedia.url,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 120,
                            height: 120,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image),
                          ),
                        )
                      : Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey[300],
                          child: const Icon(Icons.videocam, size: 32),
                        ))
                  : Container(
                      width: 120,
                      height: 120,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, size: 32),
                    ),
            ),
            const Positioned(
              top: 4,
              right: 4,
              child: Icon(
                Icons.push_pin,
                size: 16,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostGridItem extends StatelessWidget {
  const _PostGridItem({
    required this.post,
    required this.onTap,
  });

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (post.media.isEmpty) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          color: Colors.grey[300],
          child: const Icon(Icons.image, size: 48),
        ),
      );
    }

    final firstMedia = post.media.first;
    final isVideo = firstMedia.type == PostMediaType.video;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            firstMedia.thumbnailUrl ?? firstMedia.url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image),
              );
            },
          ),
          if (isVideo)
            const Positioned(
              bottom: 4,
              right: 4,
              child: Icon(
                Icons.play_circle_filled,
                color: Colors.white,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }
}

