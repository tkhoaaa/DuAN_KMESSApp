import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../services/conversation_service.dart';
import 'chat_detail_page.dart';

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
        title: const Text('Hội thoại'),
      ),
      body: StreamBuilder(
        stream: _conversationService.watchConversationEntries(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
          return _IndexErrorView(error: snapshot.error);
          }
          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return const Center(
              child: Text('Chưa có hội thoại nào.'),
            );
          }
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final subtitle = entry.subtitle ??
                  (entry.summary.lastMessageAt != null
                      ? 'Tin nhắn cuối lúc ${entry.summary.lastMessageAt}'
                      : null);
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: entry.avatarUrl != null
                      ? NetworkImage(entry.avatarUrl!)
                      : null,
                  child: entry.avatarUrl == null
                      ? const Icon(Icons.chat_bubble_outline)
                      : null,
                ),
                title: Text(entry.title),
                subtitle:
                    subtitle != null ? Text(subtitle) : const SizedBox(),
                onTap: () {
                  final otherUid = entry.summary.type == 'direct'
                      ? entry.summary.participantIds
                          .firstWhere(
                            (id) => id != uid,
                            orElse: () => uid,
                          )
                      : entry.summary.participantIds
                          .firstWhere((id) => id != uid, orElse: () => uid);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatDetailPage(
                        conversationId: entry.summary.id,
                        otherUid: otherUid,
                      ),
                    ),
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

