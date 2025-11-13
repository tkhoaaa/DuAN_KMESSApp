import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../profile/user_profile_repository.dart';
import '../models/message.dart';
import '../repositories/chat_repository.dart';

class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({
    required this.conversationId,
    required this.otherUid,
    super.key,
  });

  final String conversationId;
  final String otherUid;

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  late final ChatRepository _chatRepository;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chatRepository = ChatRepository();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _currentUid => authRepository.currentUser()?.uid;

  @override
  Widget build(BuildContext context) {
    final currentUid = _currentUid;
    if (currentUid == null) {
      return const Scaffold(
        body: Center(child: Text('Bạn cần đăng nhập để nhắn tin.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<UserProfile?>(
          future: userProfileRepository.fetchProfile(widget.otherUid),
          builder: (context, snapshot) {
            final profile = snapshot.data;
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('Đang tải...');
            }
            final title = profile?.displayName?.isNotEmpty == true
                ? profile!.displayName!
                : (profile?.email?.isNotEmpty == true
                    ? profile!.email!
                    : widget.otherUid);
            return Text(title);
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatRepository.watchMessages(
                widget.conversationId,
                limit: 50,
              ),
              builder: (context, snapshot) {

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Hãy gửi tin đầu tiên!'),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    final isMine = message.senderId == currentUid;
                    return Align(
                      alignment:
                          isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(message.text ?? '[Không có nội dung]'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      final text = _controller.text.trim();
                      if (text.isEmpty) return;
                      try {
                        await _chatRepository.sendTextMessage(
                          conversationId: widget.conversationId,
                          senderId: currentUid,
                          text: text,
                        );
                        _controller.clear();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi gửi tin: $e')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

