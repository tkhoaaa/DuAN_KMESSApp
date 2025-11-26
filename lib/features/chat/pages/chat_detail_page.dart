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
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _otherUserTyping = false;
  bool _isSearchMode = false;
  List<ChatMessage> _searchResults = [];
  bool _isSearching = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _chatRepository = ChatRepository();
    _controller.addListener(_onTextChanged);
    // Mark conversation as read khi mở
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    final currentUid = _currentUid;
    if (currentUid == null) return;
    try {
      await _chatRepository.markConversationAsRead(
        conversationId: widget.conversationId,
        uid: currentUid,
      );
    } catch (e) {
      // Ignore errors silently
      debugPrint('Error marking as read: $e');
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _searchController.dispose();
    _scrollController.dispose();
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

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _chatRepository.searchMessages(
        conversationId: widget.conversationId,
        searchTerm: query,
      );
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });

      // Scroll đến tin nhắn đầu tiên nếu có kết quả
      if (results.isNotEmpty && _scrollController.hasClients) {
        // Tìm index của message đầu tiên trong list
        // Vì ListView reverse, cần tính toán index
        await Future.delayed(const Duration(milliseconds: 100));
        if (_scrollController.hasClients) {
          // Scroll đến đầu list (vì reverse: true)
          _scrollController.jumpTo(0);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tìm kiếm: $e')),
        );
      }
    }
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchController.text.trim().isEmpty) {
      return const Center(
        child: Text('Nhập từ khóa để tìm kiếm...'),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text('Không tìm thấy tin nhắn với từ khóa "${_searchController.text}"'),
      );
    }

    final currentUid = _currentUid;
    if (currentUid == null) {
      return const Center(child: Text('Bạn cần đăng nhập.'));
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final message = _searchResults[_searchResults.length - 1 - index];
        final isMine = message.senderId == currentUid;
        return _ChatMessageBubble(
          message: message,
          isMine: isMine,
          otherUid: widget.otherUid,
          searchTerm: _searchController.text.trim(),
          onImageTap: (url) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _FullScreenImagePage(imageUrl: url),
              ),
            );
          },
          onReact: (emoji) async {
            try {
              final currentUid = _currentUid;
              if (currentUid == null) return;
              await _chatRepository.toggleReaction(
                conversationId: widget.conversationId,
                messageId: message.id,
                uid: currentUid,
                emoji: emoji,
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi cập nhật reaction: $e')),
              );
            }
          },
        );
      },
    );
  }

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
        title: _isSearchMode
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm tin nhắn...',
                  border: InputBorder.none,
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, child) {
                      return value.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                });
                              },
                            )
                          : const SizedBox.shrink();
                    },
                  ),
                ),
                onChanged: (value) {
                  _performSearch(value);
                },
              )
            : FutureBuilder<UserProfile?>(
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
        actions: [
          if (!_isSearchMode)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearchMode = true;
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearchMode = false;
                  _searchController.clear();
                  _searchResults = [];
                });
              },
            ),
        ],
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
            child: _isSearchMode
                ? _buildSearchResults()
                : StreamBuilder<List<ChatMessage>>(
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
                        controller: _scrollController,
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
                            otherUid: widget.otherUid,
                            searchTerm: null,
                            onImageTap: (url) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      _FullScreenImagePage(imageUrl: url),
                                ),
                              );
                            },
                            onReact: (emoji) async {
                              try {
                                final uid = _currentUid;
                                if (uid == null) return;
                                await _chatRepository.toggleReaction(
                                  conversationId: widget.conversationId,
                                  messageId: message.id,
                                  uid: uid,
                                  emoji: emoji,
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Lỗi cập nhật reaction: $e')),
                                );
                              }
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
    required this.otherUid,
    required this.onImageTap,
    required this.onReact,
    this.searchTerm,
  });

  final ChatMessage message;
  final bool isMine;
  final String otherUid;
  final void Function(String url) onImageTap;
   /// Gọi khi user chọn một emoji reaction
  final void Function(String emoji) onReact;
  final String? searchTerm;

  @override
  Widget build(BuildContext context) {
    final hasImages = message.attachments.isNotEmpty &&
        message.attachments.any((a) => a.mimeType.startsWith('image/'));

    final reactionEntries = message.reactions.entries
        .where((e) => e.value.isNotEmpty)
        .toList();

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () async {
          final selected = await showModalBottomSheet<String>(
            context: context,
            builder: (context) {
              final emojis = <String>['👍', '❤️', '😂', '😮', '😢', '🙏'];
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: emojis.map((emoji) {
                      return InkWell(
                        onTap: () {
                          Navigator.of(context).pop(emoji);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          );
          if (selected != null) {
            onReact(selected);
          }
        },
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
                    .map(
                      (attachment) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () => onImageTap(attachment.url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              attachment.url,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 200,
                                  color: Colors.grey[300],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress
                                                  .expectedTotalBytes !=
                                              null
                                          ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
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
                      ),
                    ),
              if (message.text != null && message.text!.isNotEmpty)
                _buildHighlightedText(
                  message.text!,
                  searchTerm: searchTerm,
                  style: const TextStyle(fontSize: 16),
                ),
              if (reactionEntries.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: reactionEntries.map((entry) {
                    final emoji = entry.key;
                    final count = entry.value.length;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$emoji $count',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (isMine)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        message.seenBy.contains(otherUid)
                            ? Icons.done_all
                            : Icons.done,
                        size: 14,
                        color: message.seenBy.contains(otherUid)
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      if (message.seenBy.contains(otherUid))
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            'Đã xem',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, {String? searchTerm, TextStyle? style}) {
    if (searchTerm == null || searchTerm.isEmpty) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final lowerSearchTerm = searchTerm.toLowerCase();
    final matches = <({int start, int end})>[];
    
    int start = 0;
    while (start < lowerText.length) {
      final index = lowerText.indexOf(lowerSearchTerm, start);
      if (index == -1) break;
      matches.add((start: index, end: index + searchTerm.length));
      start = index + 1;
    }

    if (matches.isEmpty) {
      return Text(text, style: style);
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;
    
    for (final match in matches) {
      // Text trước match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: style,
        ));
      }
      // Text được highlight
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: (style ?? const TextStyle()).copyWith(
          backgroundColor: Colors.yellow,
          fontWeight: FontWeight.bold,
        ),
      ));
      lastEnd = match.end;
    }
    
    // Text sau match cuối cùng
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: style,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
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

