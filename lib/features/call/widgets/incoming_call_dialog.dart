import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../profile/user_profile_repository.dart';
import '../models/call.dart';
import '../services/call_service.dart';
import '../pages/voice_call_page.dart';
import '../pages/video_call_page.dart';

class IncomingCallDialog extends StatefulWidget {
  const IncomingCallDialog({
    required this.callId,
    required this.callerUid,
    required this.callType,
    super.key,
  });

  final String callId;
  final String callerUid;
  final CallType callType;

  @override
  State<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<IncomingCallDialog> {
  late final CallService _callService;
  late final UserProfileRepository _profileRepository;
  StreamSubscription<Call?>? _callSubscription;

  @override
  void initState() {
    super.initState();
    _callService = CallService();
    _profileRepository = userProfileRepository;

    _watchCall();
  }

  void _watchCall() {
    _callSubscription = _callService.watchCall(widget.callId).listen((call) {
      if (call == null || !mounted) return;

      // Nếu call đã kết thúc hoặc bị hủy, đóng dialog
      if (call.status == CallStatus.ended ||
          call.status == CallStatus.rejected ||
          call.status == CallStatus.cancelled ||
          call.status == CallStatus.missed) {
        // Sử dụng SchedulerBinding để tránh lỗi Navigator locked
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.maybeOf(context)?.pop();
          }
        });
      }
    });
  }

  Future<void> _answerCall() async {
    try {
      await _callService.answerCall(widget.callId);
      if (!mounted) return;
      
      // Đóng dialog trước
      final navigator = Navigator.maybeOf(context);
      if (navigator != null) {
        navigator.pop();
        
        // Đợi một frame để đảm bảo dialog đã đóng
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => widget.callType == CallType.voice
                    ? VoiceCallPage(
                        callId: widget.callId,
                        otherUid: widget.callerUid,
                        isCaller: false,
                      )
                    : VideoCallPage(
                        callId: widget.callId,
                        otherUid: widget.callerUid,
                        isCaller: false,
                      ),
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _rejectCall() async {
    try {
      await _callService.rejectCall(widget.callId);
      if (mounted) {
        Navigator.maybeOf(context)?.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profileRepository.watchProfile(widget.callerUid);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: StreamBuilder(
        stream: profile,
        builder: (context, snapshot) {
          final userProfile = snapshot.data;
          final displayName = userProfile?.displayName ?? 'Người dùng';
          final photoUrl = userProfile?.photoUrl;

          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 60,
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null
                      ? Text(
                          displayName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 36,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),

                // Tên
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Loại cuộc gọi
                Text(
                  widget.callType == CallType.voice
                      ? 'Cuộc gọi thoại đến'
                      : 'Cuộc gọi video đến',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Reject button
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.red,
                      child: IconButton(
                        icon: const Icon(Icons.call_end, color: Colors.white),
                        onPressed: _rejectCall,
                      ),
                    ),

                    // Answer button
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.green,
                      child: IconButton(
                        icon: Icon(
                          widget.callType == CallType.voice
                              ? Icons.call
                              : Icons.videocam,
                          color: Colors.white,
                        ),
                        onPressed: _answerCall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

