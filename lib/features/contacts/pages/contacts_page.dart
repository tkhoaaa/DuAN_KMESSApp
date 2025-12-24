import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/auth_repository.dart';
import '../../../theme/colors.dart';
import '../../chat/pages/chat_detail_page.dart';
import '../../chat/repositories/chat_repository.dart';
import '../../follow/services/follow_service.dart';
import '../../profile/public_profile_page.dart';
import '../widgets/contact_search_delegate.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage>
    with SingleTickerProviderStateMixin {
  late final FollowService _followService;
  late final ChatRepository _chatRepository;
  late final TabController _tabController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _followService = FollowService();
    _chatRepository = ChatRepository();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentUid => authRepository.currentUser()?.uid ?? '';

  void _showError(Object error) {
    final message = error.toString();
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _currentUid;
    if (uid.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Bạn chưa đăng nhập.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kết nối',
          style: TextStyle(color: AppColors.primaryPink),
        ),
        iconTheme: const IconThemeData(color: AppColors.primaryPink),
        actions: [
          _AnimatedSearchButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              showSearch(
                context: context,
                delegate: ContactSearchDelegate(service: _followService),
              );
            },
          ),
        ],
        bottom: _ModernTabBar(
          controller: _tabController,
        ),
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ModernFollowList(
                  stream: _followService.watchFollowingEntries(uid),
                  emptyLabel: 'Bạn chưa theo dõi ai.',
                  actionBuilder: (entry) => [
                    _ModernActionButton(
                      icon: Icons.chat_bubble_outline,
                      tooltip: 'Nhắn tin',
                      onPressed: () async {
                        try {
                          final conversationId =
                              await _chatRepository.createOrGetDirectConversation(
                            currentUid: uid,
                            otherUid: entry.uid,
                          );
                          if (!mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatDetailPage(
                                conversationId: conversationId,
                                otherUid: entry.uid,
                              ),
                            ),
                          );
                        } catch (e) {
                          _showError(e);
                        }
                      },
                    ),
                    _ModernActionButton(
                      icon: Icons.person,
                      tooltip: 'Xem trang cá nhân',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PublicProfilePage(uid: entry.uid),
                          ),
                        );
                      },
                    ),
                    _ModernTextButton(
                      label: 'Bỏ theo dõi',
                      onPressed: () async {
                        try {
                          await _followService.unfollow(entry.uid);
                        } catch (e) {
                          _showError(e);
                        }
                      },
                    ),
                  ],
                ),
                _ModernFollowList(
                  stream: _followService.watchFollowersEntries(uid),
                  emptyLabel: 'Chưa có người theo dõi.',
                  actionBuilder: (entry) => [
                    _ModernActionButton(
                      icon: Icons.chat_bubble_outline,
                      tooltip: 'Nhắn tin',
                      onPressed: () async {
                        try {
                          final conversationId =
                              await _chatRepository.createOrGetDirectConversation(
                            currentUid: uid,
                            otherUid: entry.uid,
                          );
                          if (!mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatDetailPage(
                                conversationId: conversationId,
                                otherUid: entry.uid,
                              ),
                            ),
                          );
                        } catch (e) {
                          _showError(e);
                        }
                      },
                    ),
                    _ModernActionButton(
                      icon: Icons.person,
                      tooltip: 'Xem trang cá nhân',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PublicProfilePage(uid: entry.uid),
                          ),
                        );
                      },
                    ),
                    if (!entry.isMutual)
                      _ModernTextButton(
                        label: 'Theo dõi lại',
                        onPressed: () async {
                          try {
                            await _followService.followUser(entry.uid);
                          } catch (e) {
                            _showError(e);
                          }
                        },
                      )
                    else
                      _ModernTextButton(
                        label: 'Bỏ theo dõi',
                        onPressed: () async {
                          try {
                            await _followService.unfollow(entry.uid);
                          } catch (e) {
                            _showError(e);
                          }
                        },
                      ),
                  ],
                ),
                _ModernFollowRequestList(
                  stream: _followService.watchIncomingRequestEntries(uid),
                  emptyLabel: 'Không có yêu cầu theo dõi.',
                  onAccept: (otherUid) async {
                    try {
                      await _followService.acceptRequest(otherUid);
                    } catch (e) {
                      _showError(e);
                    }
                  },
                  onDecline: (otherUid) async {
                    try {
                      await _followService.declineRequest(otherUid);
                    } catch (e) {
                      _showError(e);
                    }
                  },
                ),
                _ModernFollowRequestList(
                  stream: _followService.watchSentRequestEntries(uid),
                  emptyLabel: 'Không có yêu cầu đã gửi.',
                  onAccept: (_) async {},
                  onDecline: (otherUid) async {
                    try {
                      await _followService.cancelRequest(otherUid);
                    } catch (e) {
                      _showError(e);
                    }
                  },
                  acceptLabel: '',
                  declineLabel: 'Huỷ yêu cầu',
                  showAcceptButton: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernFollowList extends StatelessWidget {
  const _ModernFollowList({
    required this.stream,
    required this.emptyLabel,
    required this.actionBuilder,
  });

  final Stream<List<FollowEntry>> stream;
  final String emptyLabel;
  final List<Widget> Function(FollowEntry) actionBuilder;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 500));
      },
      color: AppColors.primaryPink,
      child: StreamBuilder<List<FollowEntry>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
            return _ShimmerLoadingList();
        }
        if (snapshot.hasError) {
          return _FirestoreIndexErrorView(error: snapshot.error);
        }
        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
            return _EmptyStateView(label: emptyLabel);
        }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
              return _AnimatedFollowItem(
                key: ValueKey(entry.uid),
                entry: entry,
                index: index,
                actionBuilder: actionBuilder,
            );
          },
        );
      },
      ),
    );
  }
}

class _ModernFollowRequestList extends StatelessWidget {
  const _ModernFollowRequestList({
    required this.stream,
    required this.emptyLabel,
    required this.onAccept,
    required this.onDecline,
    this.acceptLabel = 'Chấp nhận',
    this.declineLabel = 'Từ chối',
    this.showAcceptButton = true,
  });

  final Stream<List<FollowRequestEntry>> stream;
  final String emptyLabel;
  final Future<void> Function(String) onAccept;
  final Future<void> Function(String) onDecline;
  final String acceptLabel;
  final String declineLabel;
  final bool showAcceptButton;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 500));
      },
      color: AppColors.primaryPink,
      child: StreamBuilder<List<FollowRequestEntry>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
            return _ShimmerLoadingList();
        }
        if (snapshot.hasError) {
          return _FirestoreIndexErrorView(error: snapshot.error);
        }
        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
            return _EmptyStateView(label: emptyLabel);
        }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
              return _AnimatedFollowRequestItem(
                key: ValueKey(entry.uid),
                entry: entry,
                index: index,
                onAccept: onAccept,
                onDecline: onDecline,
                acceptLabel: acceptLabel,
                declineLabel: declineLabel,
                showAcceptButton: showAcceptButton,
            );
          },
        );
      },
      ),
    );
  }
}

class _FirestoreIndexErrorView extends StatelessWidget {
  const _FirestoreIndexErrorView({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final firebaseError =
        error is FirebaseException ? error as FirebaseException : null;
    if (firebaseError != null &&
        firebaseError.code == 'failed-precondition' &&
        (firebaseError.message?.contains('https://') ?? false)) {
      final url = _extractUrl(firebaseError.message!);
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.amber, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Thiếu Firestore index cho truy vấn này.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Nhấn vào liên kết bên dưới để mở Firebase Console và tạo index. '
              'Đợi vài phút sau khi tạo rồi tải lại trang.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (url != null)
              SelectableText(
                url,
                style: const TextStyle(color: Colors.blue),
                textAlign: TextAlign.center,
              )
            else
              Text(firebaseError.message ?? '',
                  textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return Center(
      child: Text('Lỗi: $error'),
    );
  }

  String? _extractUrl(String message) {
    final regex = RegExp(r'https://[^\s]+');
    final match = regex.firstMatch(message);
    return match?.group(0);
  }
}

// Shimmer Loading Widget
class _ShimmerLoadingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return _ShimmerItem(delay: Duration(milliseconds: index * 100));
      },
    );
  }
}

class _ShimmerItem extends StatefulWidget {
  const _ShimmerItem({required this.delay});

  final Duration delay;

  @override
  State<_ShimmerItem> createState() => _ShimmerItemState();
}

class _ShimmerItemState extends State<_ShimmerItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + (_controller.value * 0.4),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Empty State Widget
class _EmptyStateView extends StatefulWidget {
  const _EmptyStateView({required this.label});

  final String label;

  @override
  State<_EmptyStateView> createState() => _EmptyStateViewState();
}

class _EmptyStateViewState extends State<_EmptyStateView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPink.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.people_outline,
                    size: 80,
                    color: AppColors.primaryPink.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Animated Follow Item
class _AnimatedFollowItem extends StatefulWidget {
  const _AnimatedFollowItem({
    required Key key,
    required this.entry,
    required this.index,
    required this.actionBuilder,
  }) : super(key: key);

  final FollowEntry entry;
  final int index;
  final List<Widget> Function(FollowEntry) actionBuilder;

  @override
  State<_AnimatedFollowItem> createState() => _AnimatedFollowItemState();
}

class _AnimatedFollowItemState extends State<_AnimatedFollowItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.entry.profile;
    final title = profile?.displayName?.isNotEmpty == true
        ? profile!.displayName!
        : (profile?.email?.isNotEmpty == true
            ? profile!.email!
            : widget.entry.uid);
    final avatarUrl = profile?.photoUrl;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1.0).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
          ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PublicProfilePage(uid: widget.entry.uid),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Card(
                  color: AppColors.primaryPink.withOpacity(0.04),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: AppColors.primaryPink.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ModernAvatar(
                        avatarUrl: avatarUrl,
                        uid: widget.entry.uid,
                      ),
                        const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Hero(
                          tag: 'contact_title_${widget.entry.uid}',
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            softWrap: true,
                          ),
                        ),
                              const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                                runSpacing: 4,
                        children: widget.actionBuilder(widget.entry),
                      ),
                    ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Animated Follow Request Item
class _AnimatedFollowRequestItem extends StatefulWidget {
  const _AnimatedFollowRequestItem({
    required Key key,
    required this.entry,
    required this.index,
    required this.onAccept,
    required this.onDecline,
    required this.acceptLabel,
    required this.declineLabel,
    required this.showAcceptButton,
  }) : super(key: key);

  final FollowRequestEntry entry;
  final int index;
  final Future<void> Function(String) onAccept;
  final Future<void> Function(String) onDecline;
  final String acceptLabel;
  final String declineLabel;
  final bool showAcceptButton;

  @override
  State<_AnimatedFollowRequestItem> createState() =>
      _AnimatedFollowRequestItemState();
}

class _AnimatedFollowRequestItemState
    extends State<_AnimatedFollowRequestItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.entry.profile;
    final title = profile?.displayName?.isNotEmpty == true
        ? profile!.displayName!
        : (profile?.email?.isNotEmpty == true
            ? profile!.email!
            : widget.entry.uid);
    final avatarUrl = profile?.photoUrl;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _ModernAvatar(
                    avatarUrl: avatarUrl,
                    uid: widget.entry.uid,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Hero(
                          tag: 'request_title_${widget.entry.uid}',
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.entry.createdAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Gửi lúc ${widget.entry.createdAt}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (widget.showAcceptButton)
                        _ModernTextButton(
                          label: widget.acceptLabel,
                          isPrimary: true,
                          onPressed: () => widget.onAccept(widget.entry.uid),
                        ),
                      _ModernTextButton(
                        label: widget.declineLabel,
                        onPressed: () => widget.onDecline(widget.entry.uid),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Modern Avatar
class _ModernAvatar extends StatelessWidget {
  const _ModernAvatar({
    required this.avatarUrl,
    required this.uid,
  });

  final String? avatarUrl;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'contact_avatar_$uid',
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              AppColors.primaryPink,
              AppColors.primaryPink.withOpacity(0.6),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryPink.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(2),
        child: CircleAvatar(
          radius: 28,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
          child: avatarUrl == null
              ? const Icon(Icons.person, color: AppColors.primaryPink)
              : null,
        ),
      ),
    );
  }
}


// Modern Tab Bar
class _ModernTabBar extends StatelessWidget implements PreferredSizeWidget {
  const _ModernTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            AppColors.primaryPink.withOpacity(0.05),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: TabBar(
        controller: controller,
        labelColor: AppColors.primaryPink,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AppColors.primaryPink,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'Đang theo dõi'),
          Tab(text: 'Người theo dõi'),
          Tab(text: 'Yêu cầu đến'),
          Tab(text: 'Yêu cầu đã gửi'),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(48);
}

// Animated Search Button
class _AnimatedSearchButton extends StatefulWidget {
  const _AnimatedSearchButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_AnimatedSearchButton> createState() => _AnimatedSearchButtonState();
}

class _AnimatedSearchButtonState extends State<_AnimatedSearchButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.9).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: IconButton(
          icon: const Icon(Icons.search, color: AppColors.primaryPink),
          tooltip: 'Tìm kiếm người dùng',
          onPressed: widget.onPressed,
        ),
      ),
    );
  }
}

// Modern Action Button
class _ModernActionButton extends StatefulWidget {
  const _ModernActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_ModernActionButton> createState() => _ModernActionButtonState();
}

class _ModernActionButtonState extends State<_ModernActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.85).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: IconButton(
          icon: Icon(widget.icon, color: AppColors.primaryPink),
          tooltip: widget.tooltip,
          onPressed: widget.onPressed,
        ),
      ),
    );
  }
}

// Modern Text Button
class _ModernTextButton extends StatefulWidget {
  const _ModernTextButton({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  State<_ModernTextButton> createState() => _ModernTextButtonState();
}

class _ModernTextButtonState extends State<_ModernTextButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.95).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: TextButton(
          onPressed: widget.onPressed,
          style: TextButton.styleFrom(
            foregroundColor: widget.isPrimary
                ? AppColors.primaryPink
                : Colors.grey.shade700,
            backgroundColor: widget.isPrimary
                ? AppColors.primaryPink.withOpacity(0.1)
                : null,
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

