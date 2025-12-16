import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../../auth/auth_repository.dart';
import '../../profile/user_profile_repository.dart';
import '../../../services/cloudinary_service.dart';
import '../../safety/services/block_service.dart';
import '../../call/models/call.dart';
import '../../call/pages/voice_call_page.dart';
import '../../call/pages/video_call_page.dart';
import '../../call/services/call_service.dart';
import '../../call/widgets/incoming_call_dialog.dart';
import '../models/message.dart';
import '../models/message_attachment.dart';
import '../repositories/chat_repository.dart';
import '../../posts/pages/post_video_page.dart';

class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({
    required this.conversationId,
    required this.otherUid,
    this.isGroup = false,
    this.conversationTitle,
    this.conversationAvatarUrl,
    super.key,
  });

  final String conversationId;
  final String otherUid;
  final bool isGroup;
  final String? conversationTitle;
  final String? conversationAvatarUrl;

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  late final ChatRepository _chatRepository;
  late final CallService _callService;
  final AudioRecorder _recorder = AudioRecorder();
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isRecording = false;
  bool _isUploading = false;
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _otherUserTyping = false;
  bool _isSearchMode = false;
  List<ChatMessage> _searchResults = [];
  bool _isSearching = false;
  final ScrollController _scrollController = ScrollController();
  bool _isBlockedByMe = false;
  bool _isBlockedByOther = false;
  StreamSubscription<bool>? _blockedByMeSub;
  StreamSubscription<bool>? _blockedByOtherSub;
  StreamSubscription<ParticipantNotificationSettings>?
      _notificationSettingsSub;
  bool _notificationsEnabled = true;
  DateTime? _mutedUntil;
  bool _isUpdatingNotifications = false;
  StreamSubscription<List<Call>>? _activeCallsSub;
  bool _isOtherUserBanned = false;
  StreamSubscription<UserProfile?>? _otherUserProfileSub;

  @override
  void initState() {
    super.initState();
    _chatRepository = ChatRepository();
    _callService = CallService();
    _controller.addListener(_onTextChanged);
    // Mark conversation as read khi mở
    _markAsRead();
    _listenBlockStatus();
    _listenNotificationSettings();
    _listenIncomingCalls();
    _listenOtherUserBanStatus();
  }

  @override
  void didUpdateWidget(covariant ChatDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.otherUid != widget.otherUid ||
        oldWidget.conversationId != widget.conversationId) {
      _listenBlockStatus();
      _listenNotificationSettings();
      _listenOtherUserBanStatus();
    }
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

  void _listenBlockStatus() {
    final currentUid = _currentUid;
    if (currentUid == null) return;
    _blockedByMeSub?.cancel();
    _blockedByOtherSub?.cancel();
    _blockedByMeSub = blockService
        .watchIsBlocked(
          blockerUid: currentUid,
          blockedUid: widget.otherUid,
        )
        .listen((value) {
      if (!mounted) return;
      setState(() {
        _isBlockedByMe = value;
      });
    });
    _blockedByOtherSub = blockService
        .watchIsBlocked(
          blockerUid: widget.otherUid,
          blockedUid: currentUid,
        )
        .listen((value) {
      if (!mounted) return;
      setState(() {
        _isBlockedByOther = value;
      });
    });
  }

  void _listenNotificationSettings() {
    final currentUid = _currentUid;
    if (currentUid == null) return;
    _notificationSettingsSub?.cancel();
    _notificationSettingsSub = _chatRepository
        .watchParticipantNotificationSettings(
          conversationId: widget.conversationId,
          uid: currentUid,
        )
        .listen((settings) {
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = settings.notificationsEnabled;
        _mutedUntil = settings.mutedUntil;
      });
    });
  }

  void _listenIncomingCalls() {
    final currentUid = _currentUid;
    if (currentUid == null) return;
    _activeCallsSub?.cancel();
    // Không cần listen ở đây nữa vì đã có global listener trong AuthGate
    // Giữ lại để tương thích nhưng không hiển thị dialog để tránh duplicate
  }

  void _listenOtherUserBanStatus() {
    _otherUserProfileSub?.cancel();
    _otherUserProfileSub = userProfileRepository
        .watchProfile(widget.otherUid)
        .listen((profile) {
      if (!mounted) return;
      setState(() {
        _isOtherUserBanned = profile != null &&
            (profile.banStatus == BanStatus.temporary ||
                profile.banStatus == BanStatus.permanent);
      });
    });
  }

  void _showIncomingCallDialog(Call call) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IncomingCallDialog(
        callId: call.id,
        callerUid: call.callerUid,
        callType: call.type,
      ),
    );
  }

  Future<void> _initiateCall(CallType type) async {
    final currentUid = _currentUid;
    if (currentUid == null) return;

    if (_isBlockedByMe || _isBlockedByOther || _isOtherUserBanned) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isOtherUserBanned
              ? 'Không thể gọi vì tài khoản đã bị khóa'
              : 'Không thể gọi khi bị chặn'),
        ),
      );
      return;
    }

    try {
      final callId = await _callService.initiateCall(
        calleeUid: widget.otherUid,
        type: type,
        conversationId: widget.conversationId,
      );

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => type == CallType.voice
                ? VoiceCallPage(
                    callId: callId,
                    otherUid: widget.otherUid,
                    isCaller: true,
                  )
                : VideoCallPage(
                    callId: callId,
                    otherUid: widget.otherUid,
                    isCaller: true,
                  ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  bool get _canSendMessages =>
      !_isBlockedByMe && !_isBlockedByOther && !_isOtherUserBanned;

  String get _blockedMessage {
    if (_isOtherUserBanned) {
      return 'Tài khoản đã bị khóa';
    }
    if (_isBlockedByMe) {
      return 'Bạn đã chặn người này. Bỏ chặn để tiếp tục theo dõi hoặc nhắn tin.';
    }
    if (_isBlockedByOther) {
      return 'Người này đã chặn bạn. Bạn không thể nhắn tin.';
    }
    return '';
  }

  void _showBlockedSnack() {
    if (!_isBlockedByMe && !_isBlockedByOther && !_isOtherUserBanned) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_blockedMessage)),
    );
  }

  bool get _isMuteActive =>
      !_notificationsEnabled ||
      (_mutedUntil != null && _mutedUntil!.isAfter(DateTime.now()));

  String get _muteStatusMessage {
    if (!_isMuteActive) return '';
    if (!_notificationsEnabled) {
      return 'Bạn đã tắt thông báo cho hội thoại này.';
    }
    if (_mutedUntil != null) {
      return 'Thông báo sẽ bật lại lúc ${_formatMuteUntil(_mutedUntil!)}.';
    }
    return 'Thông báo đã bị tắt.';
  }

  String _formatMuteUntil(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute $day/$month';
  }

  Widget? _buildMuteBanner() {
    if (!_isMuteActive) return null;
    return Container(
      width: double.infinity,
      color: Colors.orange.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.notifications_off, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _muteStatusMessage,
              style: TextStyle(
                color: Colors.orange.shade800,
              ),
            ),
          ),
          TextButton(
            onPressed: _isUpdatingNotifications
                ? null
                : () => _setNotificationPreference(enable: true),
            child: const Text('Bật lại'),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_active),
                title: const Text('Bật thông báo'),
                onTap: _isUpdatingNotifications
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
                        _setNotificationPreference(enable: true);
                      },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_off),
                title: const Text('Tắt thông báo'),
                subtitle:
                    const Text('Không nhận thông báo cho đến khi bật lại'),
                onTap: _isUpdatingNotifications
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
                        _setNotificationPreference(enable: false);
                      },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('Tắt 1 giờ'),
                onTap: _isUpdatingNotifications
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
                        _setNotificationPreference(
                          enable: true,
                          muteDuration: const Duration(hours: 1),
                        );
                      },
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('Tắt 8 giờ'),
                onTap: _isUpdatingNotifications
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
                        _setNotificationPreference(
                          enable: true,
                          muteDuration: const Duration(hours: 8),
                        );
                      },
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('Tắt 24 giờ'),
                onTap: _isUpdatingNotifications
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
                        _setNotificationPreference(
                          enable: true,
                          muteDuration: const Duration(hours: 24),
                        );
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setNotificationPreference({
    required bool enable,
    Duration? muteDuration,
  }) async {
    final currentUid = _currentUid;
    if (currentUid == null) return;
    if (_isUpdatingNotifications) return;
    setState(() {
      _isUpdatingNotifications = true;
    });
    try {
      if (!enable) {
        await _chatRepository.updateParticipantNotificationSettings(
          conversationId: widget.conversationId,
          uid: currentUid,
          notificationsEnabled: false,
          clearMutedUntil: true,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã tắt thông báo cho hội thoại này.'),
            ),
          );
        }
      } else if (muteDuration != null) {
        final until = DateTime.now().add(muteDuration);
        await _chatRepository.updateParticipantNotificationSettings(
          conversationId: widget.conversationId,
          uid: currentUid,
          notificationsEnabled: true,
          mutedUntil: until,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã tắt thông báo đến ${_formatMuteUntil(until)}.',
              ),
            ),
          );
        }
      } else {
        await _chatRepository.updateParticipantNotificationSettings(
          conversationId: widget.conversationId,
          uid: currentUid,
          notificationsEnabled: true,
          clearMutedUntil: true,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã bật thông báo.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể cập nhật thông báo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingNotifications = false;
        });
      }
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
    _recorder.dispose();
    _activeCallsSub?.cancel();
    _blockedByMeSub?.cancel();
    _blockedByOtherSub?.cancel();
    _notificationSettingsSub?.cancel();
    _otherUserProfileSub?.cancel();
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
    if (!_canSendMessages) return;
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
    if (!_canSendMessages) {
      _showBlockedSnack();
      return;
    }
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
      final uploadResult = await CloudinaryService.uploadImage(
        file: picked,
        folder: 'chat/${widget.conversationId}',
        publicId: '$timestamp-${picked.name}',
      );
      final imageUrl = uploadResult['url']!;

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

  Future<void> _pickAndSendVideo() async {
    if (!_canSendMessages) {
      _showBlockedSnack();
      return;
    }
    final currentUid = _currentUid;
    if (currentUid == null) return;

    try {
      final picked = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (picked == null) return;

      setState(() {
        _isUploading = true;
      });

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uploadResult = await CloudinaryService.uploadVideo(
        file: picked,
        folder: 'chat/${widget.conversationId}',
        publicId: '$timestamp-${picked.name}',
      );

      final videoUrl = uploadResult['url'] as String?;
      if (videoUrl == null) {
        throw Exception('Không nhận được URL video từ Cloudinary');
      }
      final thumbnailUrl = uploadResult['thumbnailUrl'] as String?;
      final durationMs = (uploadResult['durationMs'] as num?)?.toInt();

      int fileSize = 0;
      try {
        final file = File(picked.path);
        fileSize = await file.length();
      } catch (_) {
        fileSize = 0;
      }

      final attachment = MessageAttachment(
        url: videoUrl,
        name: picked.name,
        size: fileSize,
        mimeType: 'video/mp4',
        type: 'video_message',
        durationMs: durationMs,
        thumbnailUrl: thumbnailUrl,
      );

      await _chatRepository.sendVideoMessage(
        conversationId: widget.conversationId,
        senderId: currentUid,
        attachments: [attachment],
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi gửi video: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _toggleRecord() async {
    if (!_canSendMessages) {
      _showBlockedSnack();
      return;
    }
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice message chưa hỗ trợ trên web')),
      );
      return;
    }

    final currentUid = _currentUid;
    if (currentUid == null) return;

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ứng dụng cần quyền micro để ghi âm')),
        );
        return;
      }

      if (!_isRecording) {
        // Bắt đầu ghi âm
        // record 5.x yêu cầu truyền sẵn đường dẫn file đầu ra (path)
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final outputPath = '${tempDir.path}/voice_$timestamp.m4a';

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: outputPath,
        );
        setState(() {
          _isRecording = true;
        });
      } else {
        // Dừng ghi âm và gửi
        final path = await _recorder.stop();
        setState(() {
          _isRecording = false;
        });
        if (path == null) return;

        setState(() {
          _isUploading = true;
        });

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = XFile(path, name: 'voice-$timestamp.m4a');

        final uploadResult = await CloudinaryService.uploadAudio(
          file: file,
          folder: 'chat/${widget.conversationId}',
          publicId: 'voice-$timestamp',
        );

        final audioUrl = uploadResult['url'] as String?;
        if (audioUrl == null) {
          throw Exception('Không nhận được URL audio từ Cloudinary');
        }
        final durationMs = (uploadResult['durationMs'] as num?)?.toInt();

        int fileSize = 0;
        try {
          final f = File(path);
          fileSize = await f.length();
        } catch (_) {
          fileSize = 0;
        }

        final attachment = MessageAttachment(
          url: audioUrl,
          name: file.name,
          size: fileSize,
          mimeType: 'audio/m4a',
          type: 'voice',
          durationMs: durationMs,
        );

        await _chatRepository.sendVoiceMessage(
          conversationId: widget.conversationId,
          senderId: currentUid,
          attachments: [attachment],
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi ghi âm: $e')),
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
    final muteBanner = _buildMuteBanner();

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
            : widget.isGroup
                ? Text(widget.conversationTitle ?? 'Nhóm')
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
                      final note = profile?.note;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (note != null && note.isNotEmpty)
                            Text(
                              note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontStyle: FontStyle.italic),
                            ),
                        ],
                      );
                    },
                  ),
        actions: [
          if (!_isSearchMode) ...[
            // Call buttons (chỉ hiện khi không bị block và không bị khóa)
            if (!_isBlockedByMe &&
                !_isBlockedByOther &&
                !_isOtherUserBanned) ...[
              IconButton(
                icon: const Icon(Icons.phone),
                tooltip: 'Gọi thoại',
                onPressed: () => _initiateCall(CallType.voice),
              ),
              IconButton(
                icon: const Icon(Icons.videocam),
                tooltip: 'Gọi video',
                onPressed: () => _initiateCall(CallType.video),
              ),
            ],
            IconButton(
              icon: Icon(
                _isMuteActive
                    ? Icons.notifications_off
                    : Icons.notifications_active,
              ),
              tooltip:
                  _isMuteActive ? 'Thông báo đang tắt' : 'Thông báo đang bật',
              onPressed:
                  _isUpdatingNotifications ? null : _showNotificationSettingsSheet,
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearchMode = true;
                });
              },
            ),
          ] else
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
          if (muteBanner != null) muteBanner,
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
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
          if (_isBlockedByMe || _isBlockedByOther || _isOtherUserBanned)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                _blockedMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isRecording ? Icons.mic_off : Icons.mic,
                      color: _isRecording
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                    onPressed:
                        _isUploading || !_canSendMessages ? null : _toggleRecord,
                    tooltip: 'Gửi voice',
                  ),
                  IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: _isUploading || !_canSendMessages
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
                                    ListTile(
                                      leading: const Icon(Icons.video_library),
                                      title: const Text('Gửi video'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _pickAndSendVideo();
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
                      enabled: !_isUploading && _canSendMessages,
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
                        if (!_canSendMessages) {
                          _showBlockedSnack();
                          return;
                        }
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
    final voiceAttachments = message.attachments
        .where((a) => a.type == 'voice')
        .toList();
    final videoAttachments = message.attachments
        .where((a) => a.type == 'video' || a.type == 'video_message')
        .toList();

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
                : Theme.of(context).colorScheme.surfaceContainerHighest,
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
              if (voiceAttachments.isNotEmpty) ...[
                ...voiceAttachments.map(
                  (attachment) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _VoiceMessagePlayer(
                      attachment: attachment,
                      isMine: isMine,
                    ),
                  ),
                ),
              ],
              if (videoAttachments.isNotEmpty) ...[
                ...videoAttachments.map(
                  (attachment) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PostVideoPage(
                              videoUrl: attachment.url,
                            ),
                          ),
                        );
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: attachment.thumbnailUrl != null
                                ? Image.network(
                                    attachment.thumbnailUrl!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 200,
                                  )
                                : Container(
                                    width: double.infinity,
                                    height: 200,
                                    color: Colors.black12,
                                  ),
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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

}

class _VoiceMessagePlayer extends StatefulWidget {
  const _VoiceMessagePlayer({
    required this.attachment,
    required this.isMine,
  });

  final MessageAttachment attachment;
  final bool isMine;

  @override
  State<_VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<_VoiceMessagePlayer> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration? _duration;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
        if (state == PlayerState.stopped) {
          _position = Duration.zero;
        }
      });
    });
    _player.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() {
        _duration = duration;
      });
    });
    _player.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() {
        _position = position;
      });
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  double? get _progress {
    if (_duration == null || _duration!.inMilliseconds == 0) return null;
    final ratio =
        _position.inMilliseconds / _duration!.inMilliseconds;
    return ratio.clamp(0, 1);
  }

  String get _displayDuration {
    if (_duration != null && _duration!.inMilliseconds > 0) {
      return _formatDurationMs(_duration!.inMilliseconds);
    }
    if (widget.attachment.durationMs != null) {
      return _formatDurationMs(widget.attachment.durationMs!);
    }
    return '--:--';
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.stop();
      setState(() {
        _position = Duration.zero;
      });
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      await _player.stop();
      await _player.play(UrlSource(widget.attachment.url));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không phát được voice: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: widget.isMine
                ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                : Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(30),
          ),
          child: IconButton(
            iconSize: 20,
            onPressed: _isLoading ? null : _togglePlayback,
            icon: _isLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: _progress,
                minHeight: 4,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 4),
              Text(
                _displayDuration,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatDurationMs(int ms) {
  final totalSeconds = (ms / 1000).round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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

