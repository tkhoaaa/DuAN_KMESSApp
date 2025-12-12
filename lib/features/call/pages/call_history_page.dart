import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/auth_repository.dart';
import '../../profile/user_profile_repository.dart';
import '../models/call.dart';
import '../services/call_service.dart';

class CallHistoryPage extends StatefulWidget {
  const CallHistoryPage({super.key});

  @override
  State<CallHistoryPage> createState() => _CallHistoryPageState();
}

class _CallHistoryPageState extends State<CallHistoryPage> {
  late final CallService _callService;
  late final UserProfileRepository _profileRepository;

  List<Call> _calls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _callService = CallService();
    _profileRepository = userProfileRepository;
    _loadCallHistory();
  }

  Future<void> _loadCallHistory() async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final calls = await _callService.fetchCallHistory(
        currentUid,
        limit: 50,
      );

      setState(() {
        _calls = calls;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        _handleError(e);
      }
    }
  }

  void _handleError(dynamic error) {
    final errorString = error.toString();
    
    // Kiểm tra lỗi failed-precondition (thiếu indexes)
    if (errorString.contains('failed-precondition') || 
        errorString.contains('requires an index')) {
      // Trích xuất URL tạo index từ error message
      final urlMatch = RegExp(r'https://[^\s]+').firstMatch(errorString);
      final indexUrl = urlMatch?.group(0);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cần tạo Index'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Firestore cần tạo indexes để truy vấn lịch sử cuộc gọi. '
                'Bạn có thể tạo indexes tự động bằng cách:',
              ),
              const SizedBox(height: 12),
              const Text(
                '1. Deploy indexes từ file firebase/firestore.indexes.json',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Hoặc'),
              const SizedBox(height: 8),
              const Text(
                '2. Click vào link bên dưới để tạo indexes trên Firebase Console',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (indexUrl != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  indexUrl,
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
            if (indexUrl != null)
              TextButton(
                onPressed: () async {
                  final uri = Uri.parse(indexUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Mở link'),
              ),
            if (indexUrl != null)
              TextButton(
                onPressed: () {
                  // Copy URL to clipboard
                  Clipboard.setData(ClipboardData(text: indexUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã copy link vào clipboard')),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Copy link'),
              ),
          ],
        ),
      );
    } else {
      // Hiển thị lỗi thông thường
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải lịch sử: ${error.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  String _formatCallDuration(int? duration) {
    if (duration == null) return '--:--';
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatCallDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final callDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (callDate == today) {
      return 'Hôm nay ${DateFormat('HH:mm').format(dateTime)}';
    } else if (callDate == today.subtract(const Duration(days: 1))) {
      return 'Hôm qua ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  IconData _getCallIcon(Call call, String currentUid) {
    if (call.status == CallStatus.missed) {
      return Icons.call_missed;
    } else if (call.status == CallStatus.rejected) {
      return Icons.call_end;
    } else if (call.callerUid == currentUid) {
      return call.type == CallType.voice ? Icons.call_made : Icons.videocam;
    } else {
      return call.type == CallType.voice ? Icons.call_received : Icons.videocam;
    }
  }

  Color _getCallIconColor(Call call, String currentUid) {
    if (call.status == CallStatus.missed || call.status == CallStatus.rejected) {
      return Colors.red;
    } else if (call.callerUid == currentUid) {
      return Colors.blue;
    } else {
      return Colors.green;
    }
  }

  String _getCallStatusText(Call call, String currentUid) {
    switch (call.status) {
      case CallStatus.missed:
        return call.callerUid == currentUid ? 'Cuộc gọi nhỡ' : 'Cuộc gọi bị nhỡ';
      case CallStatus.rejected:
        return 'Đã từ chối';
      case CallStatus.cancelled:
        return 'Đã hủy';
      case CallStatus.ended:
        return _formatCallDuration(call.duration);
      case CallStatus.accepted:
        return _formatCallDuration(call.duration);
      case CallStatus.ringing:
        return 'Đang gọi...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lịch sử cuộc gọi')),
        body: const Center(child: Text('Vui lòng đăng nhập')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử cuộc gọi'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _calls.isEmpty
              ? const Center(
                  child: Text('Chưa có cuộc gọi nào'),
                )
              : ListView.builder(
                  itemCount: _calls.length,
                  itemBuilder: (context, index) {
                    final call = _calls[index];
                    final otherUid = call.callerUid == currentUid
                        ? call.calleeUid
                        : call.callerUid;
                    final profile = _profileRepository.watchProfile(otherUid);

                    return StreamBuilder(
                      stream: profile,
                      builder: (context, snapshot) {
                        final userProfile = snapshot.data;
                        final displayName =
                            userProfile?.displayName ?? 'Người dùng';
                        final photoUrl = userProfile?.photoUrl;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: photoUrl != null
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl == null
                                ? Text(displayName[0].toUpperCase())
                                : null,
                          ),
                          title: Text(displayName),
                          subtitle: Row(
                            children: [
                              Icon(
                                _getCallIcon(call, currentUid),
                                size: 16,
                                color: _getCallIconColor(call, currentUid),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                call.type == CallType.voice
                                    ? 'Cuộc gọi thoại'
                                    : 'Cuộc gọi video',
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _getCallStatusText(call, currentUid),
                                style: TextStyle(
                                  color: _getCallIconColor(call, currentUid),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCallDate(call.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

