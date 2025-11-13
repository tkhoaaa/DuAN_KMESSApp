import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../chat/pages/chat_detail_page.dart';
import '../../chat/repositories/chat_repository.dart';
import '../../follow/models/follow_state.dart';
import '../../follow/services/follow_service.dart';
import '../../profile/public_profile_page.dart';
import '../../profile/user_profile_repository.dart';
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
        title: const Text('Kết nối'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Tìm kiếm người dùng',
            onPressed: () {
              showSearch(
                context: context,
                delegate: ContactSearchDelegate(service: _followService),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Đang theo dõi'),
            Tab(text: 'Người theo dõi'),
            Tab(text: 'Yêu cầu đến'),
            Tab(text: 'Yêu cầu đã gửi'),
          ],
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
                _FollowList(
                  stream: _followService.watchFollowingEntries(uid),
                  emptyLabel: 'Bạn chưa theo dõi ai.',
                  actionBuilder: (entry) => [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
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
                    IconButton(
                      icon: const Icon(Icons.person),
                      tooltip: 'Xem trang cá nhân',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PublicProfilePage(uid: entry.uid),
                          ),
                        );
                      },
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          await _followService.unfollow(entry.uid);
                        } catch (e) {
                          _showError(e);
                        }
                      },
                      child: const Text('Bỏ theo dõi'),
                    ),
                  ],
                ),
                _FollowList(
                  stream: _followService.watchFollowersEntries(uid),
                  emptyLabel: 'Chưa có người theo dõi.',
                  actionBuilder: (entry) => [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
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
                    IconButton(
                      icon: const Icon(Icons.person),
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
                      TextButton(
                        onPressed: () async {
                          try {
                            await _followService.followUser(entry.uid);
                          } catch (e) {
                            _showError(e);
                          }
                        },
                        child: const Text('Theo dõi lại'),
                      )
                    else
                      TextButton(
                        onPressed: () async {
                          try {
                            await _followService.unfollow(entry.uid);
                          } catch (e) {
                            _showError(e);
                          }
                        },
                        child: const Text('Bỏ theo dõi'),
                      ),
                  ],
                ),
                _FollowRequestList(
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
                _FollowRequestList(
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

class _FollowList extends StatelessWidget {
  const _FollowList({
    required this.stream,
    required this.emptyLabel,
    required this.actionBuilder,
  });

  final Stream<List<FollowEntry>> stream;
  final String emptyLabel;
  final List<Widget> Function(FollowEntry) actionBuilder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FollowEntry>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _FirestoreIndexErrorView(error: snapshot.error);
        }
        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
          return Center(child: Text(emptyLabel));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final profile = entry.profile;
            final title = profile?.displayName?.isNotEmpty == true
                ? profile!.displayName!
                : (profile?.email?.isNotEmpty == true
                    ? profile!.email!
                    : entry.uid);
            final avatarUrl = profile?.photoUrl;
            return ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null ? const Icon(Icons.person) : null,
              ),
              title: Text(title),
              subtitle:
                  entry.isMutual ? const Text('Theo dõi lẫn nhau') : null,
              trailing: Wrap(
                spacing: 4,
                children: actionBuilder(entry),
              ),
            );
          },
        );
      },
    );
  }
}

class _FollowRequestList extends StatelessWidget {
  const _FollowRequestList({
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
    return StreamBuilder<List<FollowRequestEntry>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _FirestoreIndexErrorView(error: snapshot.error);
        }
        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
          return Center(child: Text(emptyLabel));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final profile = entry.profile;
            final title = profile?.displayName?.isNotEmpty == true
                ? profile!.displayName!
                : (profile?.email?.isNotEmpty == true
                    ? profile!.email!
                    : entry.uid);
            final avatarUrl = profile?.photoUrl;
            return ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null ? const Icon(Icons.person) : null,
              ),
              title: Text(title),
              subtitle: entry.createdAt != null
                  ? Text('Gửi lúc ${entry.createdAt}')
                  : null,
              trailing: Wrap(
                spacing: 8,
                children: [
                  if (showAcceptButton)
                    TextButton(
                      onPressed: () => onAccept(entry.uid),
                      child: Text(acceptLabel),
                    ),
                  TextButton(
                    onPressed: () => onDecline(entry.uid),
                    child: Text(declineLabel),
                  ),
                ],
              ),
            );
          },
        );
      },
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

