import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/auth_repository.dart';
import '../../profile/user_profile_repository.dart';
import '../../../services/cloudinary_service.dart';
import '../models/message.dart';
import '../models/message_attachment.dart';
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
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _otherUserTyping = false;

  @override
  void initState() {
    super.initState();
    _chatRepository = ChatRepository();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    // Set typing false khi dispose
    final currentUid = _currentUid;
    if (currentUid != null && _isTyping) {
      _chatRepository.setTyping(
        uid: currentUid,
        conversationId: widget.conversationId,
        isTyping: false,
      );
    }
    super.dispose();
  }

  String? get _currentUid => authRepository.currentUser()?.uid;

  void _onTextChanged() {
    final currentUid = _currentUid;
    if (currentUid == null) return;

    // Hủy timer cũ nếu có
    _typingTimer?.cancel();

    // Nếu đang có text và chưa set typing, set typing = true
    if (_controller.text.isNotEmpty && !_isTyping) {
      setState(() {
        _isTyping = true;
      });
      _chatRepository.setTyping(
        uid: currentUid,
        conversationId: widget.conversationId,
        isTyping: true,
      );
    }

    // Tạo timer mới: sau 2 giây không gõ thì set typing = false
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        setState(() {
          _isTyping = false;
        });
        _chatRepository.setTyping(
          uid: currentUid,
          conversationId: widget.conversationId,
          isTyping: false,
        );
      }
    });
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final currentUid = _currentUid;
    if (currentUid == null) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked == null) return;

      setState(() {
        _isUploading = true;
      });

      // Upload ảnh lên Cloudinary
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imageUrl = await CloudinaryService.uploadImage(
        file: picked,
        folder: 'chat/${widget.conversationId}',
        publicId: '$timestamp-${picked.name}',
      );

      // Lấy file size
      int fileSize = 0;
      try {
        if (kIsWeb) {
          final bytes = await picked.readAsBytes();
          fileSize = bytes.length;
        } else {
          final file = File(picked.path);
          fileSize = await file.length();
        }
      } catch (_) {
        // Nếu không lấy được size, dùng 0
        fileSize = 0;
      }

      // Tạo attachment
      final attachment = MessageAttachment(
        url: imageUrl,
        name: picked.name,
        size: fileSize,
        mimeType: 'image/jpeg',
      );

      // Gửi tin nhắn
      await _chatRepository.sendImageMessage(
        conversationId: widget.conversationId,
        senderId: currentUid,
        attachments: [attachment],
        text: _controller.text.trim().isNotEmpty ? _controller.text.trim() : null,
      );

      _controller.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi gửi ảnh: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

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
          // Listen typing status của đối phương
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('user_profiles')
                .doc(widget.otherUid)
                .snapshots(),
            builder: (context, typingSnapshot) {
              if (typingSnapshot.hasData) {
                final typingIn = (typingSnapshot.data?.data()?['typingIn']
                        as List<dynamic>? ?? [])
                    .map((e) => e.toString())
                    .toList();
                final isOtherTyping = typingIn.contains(widget.conversationId);
                // Cập nhật state nếu thay đổi
                if (isOtherTyping != _otherUserTyping && mounted) {
                  Future.microtask(() {
                    if (mounted) {
                      setState(() {
                        _otherUserTyping = isOtherTyping;
                      });
                    }
                  });
                }
              }
              return const SizedBox.shrink();
            },
          ),
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
                    return _ChatMessageBubble(
                      message: message,
                      isMine: isMine,
                      onImageTap: (url) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _FullScreenImagePage(imageUrl: url),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          // Typing indicator
          if (_otherUserTyping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Đang gõ...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: _isUploading
                        ? null
                        : () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.photo_library),
                                      title: const Text('Chọn từ thư viện'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _pickAndSendImage(ImageSource.gallery);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.camera_alt),
                                      title: const Text('Chụp ảnh'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _pickAndSendImage(ImageSource.camera);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                    tooltip: 'Gửi ảnh',
                  ),
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
                      enabled: !_isUploading,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isUploading)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
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
                        // Set typing false sau khi gửi
                        if (_isTyping) {
                          setState(() {
                            _isTyping = false;
                          });
                          _chatRepository.setTyping(
                            uid: currentUid,
                            conversationId: widget.conversationId,
                            isTyping: false,
                          );
                        }
                        _typingTimer?.cancel();
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

/// Widget hiển thị message bubble với hỗ trợ ảnh
class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.message,
    required this.isMine,
    required this.onImageTap,
  });

  final ChatMessage message;
  final bool isMine;
  final void Function(String url) onImageTap;

  @override
  Widget build(BuildContext context) {
    final hasImages = message.attachments.isNotEmpty &&
        message.attachments.any((a) => a.mimeType.startsWith('image/'));

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMine
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (hasImages)
              ...message.attachments
                  .where((a) => a.mimeType.startsWith('image/'))
                  .map((attachment) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () => onImageTap(attachment.url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              attachment.url,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 200,
                                  color: Colors.grey[300],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes !=
                                              null
                                          ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.error),
                                );
                              },
                            ),
                          ),
                        ),
                      )),
            if (message.text != null && message.text!.isNotEmpty)
              Text(
                message.text!,
                style: const TextStyle(fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}

/// Trang xem ảnh fullscreen
class _FullScreenImagePage extends StatelessWidget {
  const _FullScreenImagePage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(Icons.error, color: Colors.white, size: 48),
              );
            },
          ),
        ),
      ),
    );
  }
}

