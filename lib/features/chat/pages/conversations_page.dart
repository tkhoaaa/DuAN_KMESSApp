import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/auth_repository.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../services/conversation_service.dart';
import '../../call/pages/call_history_page.dart';
import 'chat_detail_page.dart';
import 'create_group_page.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  late final ConversationService _conversationService;

  @override
  void initState() {
    super.initState();
    _conversationService = ConversationService();
  }

  String? get _currentUid => authRepository.currentUser()?.uid;

  @override
  Widget build(BuildContext context) {
    final uid = _currentUid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Bạn cần đăng nhập để xem hội thoại.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hội thoại',
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryPink,
          ),
        ),
        actions: [
          PopupMenuButton<_ChatMenuAction>(
            icon: const Icon(Icons.more_vert, color: AppColors.primaryPink),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ChatMenuAction.callHistory,
                child: _MenuRow(icon: Icons.history, label: 'Lịch sử cuộc gọi'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _ModernFAB(
        onPressed: _openCreateGroup,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Trigger rebuild to refresh data
          setState(() {});
          await Future.delayed(const Duration(milliseconds: 500));
        },
        color: AppColors.primaryPink,
        child: StreamBuilder(
          stream: _conversationService.watchConversationEntries(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _ShimmerLoadingList();
            }
            if (snapshot.hasError) {
              return _IndexErrorView(error: snapshot.error);
            }
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return _EmptyConversationsView();
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _AnimatedConversationItem(
                  key: ValueKey(entry.summary.id),
                  entry: entry,
                  uid: uid,
                  index: index,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openCreateGroup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreateGroupPage(),
      ),
    );
  }

  Future<void> _openCallHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CallHistoryPage(),
      ),
    );
  }

  void _handleMenuAction(_ChatMenuAction action) {
    switch (action) {
      case _ChatMenuAction.callHistory:
        _openCallHistory();
        break;
    }
  }
}

enum _ChatMenuAction { callHistory }

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryPink),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _IndexErrorView extends StatelessWidget {
  const _IndexErrorView({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final firebaseError = error is FirebaseException ? error as FirebaseException : null;
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
            const SizedBox(height: 16),
            const Text(
              'Cần tạo Firestore index cho truy vấn hội thoại.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Nhấn vào liên kết bên dưới để mở Firebase Console và tạo index. '
              'Sau khi tạo xong, đợi vài phút rồi tải lại ứng dụng.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SelectableText(
              url ?? firebaseError.message ?? '',
              style: const TextStyle(color: Colors.blue),
              textAlign: TextAlign.center,
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 8,
      itemBuilder: (context, index) {
        return _ShimmerConversationItem(delay: Duration(milliseconds: index * 100));
      },
    );
  }
}

class _ShimmerConversationItem extends StatefulWidget {
  const _ShimmerConversationItem({required this.delay});

  final Duration delay;

  @override
  State<_ShimmerConversationItem> createState() => _ShimmerConversationItemState();
}

class _ShimmerConversationItemState extends State<_ShimmerConversationItem>
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
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
class _EmptyConversationsView extends StatefulWidget {
  @override
  State<_EmptyConversationsView> createState() => _EmptyConversationsViewState();
}

class _EmptyConversationsViewState extends State<_EmptyConversationsView>
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
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: AppColors.primaryPink.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Chưa có hội thoại nào',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bắt đầu trò chuyện với bạn bè của bạn',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
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

// Animated Conversation Item
class _AnimatedConversationItem extends StatefulWidget {
  const _AnimatedConversationItem({
    required Key key,
    required this.entry,
    required this.uid,
    required this.index,
  }) : super(key: key);

  final dynamic entry;
  final String uid;
  final int index;

  @override
  State<_AnimatedConversationItem> createState() => _AnimatedConversationItemState();
}

class _AnimatedConversationItemState extends State<_AnimatedConversationItem>
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
    final entry = widget.entry;
    final subtitleText = entry.subtitle ??
        (entry.summary.lastMessageAt != null
            ? 'Tin nhắn cuối lúc ${entry.summary.lastMessageAt}'
            : null);
    final muteLabel = entry.muteDescription();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _ModernConversationCard(
          entry: entry,
          subtitleText: subtitleText,
          muteLabel: muteLabel,
          uid: widget.uid,
        ),
      ),
    );
  }
}

// Helper function to get message type icon
IconData _getMessageTypeIcon(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('📷') || lower.contains('image') || lower.contains('ảnh')) {
    return Icons.image;
  }
  if (lower.contains('🎥') || lower.contains('video') || lower.contains('phim')) {
    return Icons.videocam;
  }
  if (lower.contains('📎') || lower.contains('file') || lower.contains('tệp')) {
    return Icons.attach_file;
  }
  return Icons.message;
}

// Modern Conversation Card
class _ModernConversationCard extends StatefulWidget {
  const _ModernConversationCard({
    required this.entry,
    required this.subtitleText,
    required this.muteLabel,
    required this.uid,
  });

  final dynamic entry;
  final String? subtitleText;
  final String? muteLabel;
  final String uid;

  @override
  State<_ModernConversationCard> createState() => _ModernConversationCardState();
}

class _ModernConversationCardState extends State<_ModernConversationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    if (widget.entry.unreadCount > 0) {
      _pulseController.forward();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    final otherUid = widget.entry.summary.type == 'direct'
        ? widget.entry.summary.participantIds
            .firstWhere(
              (id) => id != widget.uid,
              orElse: () => widget.uid,
            )
        : widget.entry.summary.participantIds
            .firstWhere((id) => id != widget.uid, orElse: () => widget.uid);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          conversationId: widget.entry.summary.id,
          otherUid: otherUid,
          isGroup: widget.entry.summary.isGroup,
          conversationTitle: widget.entry.title,
          conversationAvatarUrl: widget.entry.avatarUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(widget.entry.summary.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        // TODO: Implement delete conversation logic
        return false; // For now, don't delete
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(16),
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
                      avatarUrl: widget.entry.avatarUrl,
                      isGroup: widget.entry.summary.isGroup,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Hero(
                                  tag: 'conversation_title_${widget.entry.summary.id}',
                                  child: Text(
                                    widget.entry.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              if (widget.entry.isMuted)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.notifications_off,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (widget.subtitleText != null || widget.muteLabel != null)
                            Row(
                              children: [
                                if (widget.subtitleText != null) ...[
                                  Icon(
                                    _getMessageTypeIcon(widget.subtitleText!),
                                    size: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      widget.subtitleText!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                if (widget.muteLabel != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      widget.muteLabel!,
                                      style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (widget.entry.unreadCount > 0)
                      _AnimatedBadge(
                        count: widget.entry.unreadCount,
                        controller: _pulseController,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Modern Avatar with gradient border
class _ModernAvatar extends StatelessWidget {
  const _ModernAvatar({
    required this.avatarUrl,
    required this.isGroup,
  });

  final String? avatarUrl;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'conversation_avatar_${avatarUrl ?? 'default'}',
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
              ? Icon(
                  isGroup ? Icons.group : Icons.person,
                  color: AppColors.primaryPink,
                )
              : null,
        ),
      ),
    );
  }
}

// Animated Badge with pulse effect
class _AnimatedBadge extends StatelessWidget {
  const _AnimatedBadge({
    required this.count,
    required this.controller,
  });

  final int count;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (controller.value * 0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryPink,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPink.withOpacity(0.4 * controller.value),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }
}

// Modern FAB with scale animation
class _ModernFAB extends StatefulWidget {
  const _ModernFAB({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_ModernFAB> createState() => _ModernFABState();
}

class _ModernFABState extends State<_ModernFAB> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    HapticFeedback.mediumImpact();
    widget.onPressed();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryPink,
                AppColors.primaryPink.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPink.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.group_add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

