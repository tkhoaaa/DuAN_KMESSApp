import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../auth/auth_repository.dart';
import '../../profile/user_profile_repository.dart';
import '../models/call.dart';
import '../repositories/call_repository.dart';
import '../services/call_service.dart';
import '../services/webrtc_service.dart';

class VoiceCallPage extends StatefulWidget {
  const VoiceCallPage({
    required this.callId,
    required this.otherUid,
    required this.isCaller,
    super.key,
  });

  final String callId;
  final String otherUid;
  final bool isCaller;

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> {
  late final CallService _callService;
  late final UserProfileRepository _profileRepository;
  late final WebRTCService _webrtcService;
  late final CallRepository _callRepository;

  Call? _call;
  StreamSubscription<Call?>? _callSubscription;
  Timer? _callTimer;
  Timer? _callStatusCheckTimer;
  Duration _callDuration = Duration.zero;
  bool _isMicrophoneEnabled = true;
  bool _isDisposed = false;
  bool _isEndingCall = false;
  DateTime _lastCallSnapshotAt = DateTime.now();
  static const Duration _statusSilentThreshold = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _callService = CallService();
    _profileRepository = userProfileRepository;
    _webrtcService = WebRTCService();
    _callRepository = CallRepository();

    if (widget.isCaller) {
      _initializeCaller();
    } else {
      _initializeCallee();
    }

    _watchCall();
  }

  Future<void> _initializeCaller() async {
    try {
      // Request microphone permission
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cần quyền microphone để thực hiện cuộc gọi'),
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      await _webrtcService.initializeCaller(
        callId: widget.callId,
        callType: CallType.voice,
      );
      setState(() {
        _isMicrophoneEnabled = _webrtcService.isMicrophoneEnabled;
      });
    } catch (e) {
      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khởi tạo cuộc gọi: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _initializeCallee() async {
    try {
      // Request microphone permission
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cần quyền microphone để thực hiện cuộc gọi'),
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      await _webrtcService.initializeCallee(
        callId: widget.callId,
        callType: CallType.voice,
      );
      setState(() {
        _isMicrophoneEnabled = _webrtcService.isMicrophoneEnabled;
      });
    } catch (e) {
      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khởi tạo cuộc gọi: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _watchCall() {
    _callSubscription = _callService.watchCall(widget.callId).listen((call) {
      if (!mounted || _isEndingCall) return;

      _lastCallSnapshotAt = DateTime.now();

      if (call == null) {
        _endCall();
        return;
      }

      final shouldRebuildUi = _call == null ||
          _call!.status != call.status ||
          _call!.startedAt != call.startedAt ||
          _call!.endedAt != call.endedAt ||
          _call!.duration != call.duration;

      _call = call;

      if (shouldRebuildUi && mounted && !_isEndingCall) {
        setState(() {});
      }

      if (call.status == CallStatus.accepted && _callTimer == null && !_isEndingCall) {
        _startCallTimer();
        _startCallStatusCheckTimer();
      }

      if (call.status == CallStatus.ended ||
          call.status == CallStatus.rejected ||
          call.status == CallStatus.cancelled ||
          call.status == CallStatus.missed) {
        _callStatusCheckTimer?.cancel();
        _endCall();
      }
    });
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isEndingCall) {
        timer.cancel();
        return;
      }

      if (mounted && !_isEndingCall) {
        setState(() {
          if (_call?.startedAt != null) {
            _callDuration = DateTime.now().difference(_call!.startedAt!);
          }
        });
      }
    });
  }

  bool _shouldSkipStatusCheck() =>
      !mounted || _isDisposed || _isEndingCall;

  void _startCallStatusCheckTimer() {
    _callStatusCheckTimer?.cancel();
    _callStatusCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_shouldSkipStatusCheck()) {
        timer.cancel();
        return;
      }

      final silentDuration = DateTime.now().difference(_lastCallSnapshotAt);
      if (silentDuration < _statusSilentThreshold) {
        return;
      }

      try {
        final call = await _callRepository.fetchCall(widget.callId).timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );

        _lastCallSnapshotAt = DateTime.now();

        if (call == null) {
          timer.cancel();
          _endCall();
          return;
        }

        if ((call.status == CallStatus.ended ||
                call.status == CallStatus.rejected ||
                call.status == CallStatus.cancelled ||
                call.status == CallStatus.missed) &&
            !_isEndingCall) {
          timer.cancel();
          _endCall();
        }
      } catch (e) {
        debugPrint('Voice call status check error: $e');
      }
    });
  }

  Future<void> _answerCall() async {
    try {
      await _callService.answerCall(widget.callId);
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
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _endCall() async {
    if (_isEndingCall) {
      if (mounted) {
        final navigator = Navigator.maybeOf(context);
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        }
      }
      return;
    }

    _isEndingCall = true;

    _callTimer?.cancel();
    _callTimer = null;
    _callStatusCheckTimer?.cancel();
    _callStatusCheckTimer = null;
    _callSubscription?.cancel();
    _callSubscription = null;

    try {
      await _callService.endCall(widget.callId);
    } catch (_) {
      // Ignore errors when ending call
    }

    if (mounted) {
      final navigator = Navigator.maybeOf(context);
      if (navigator != null && navigator.canPop()) {
        navigator.pop();
      }
    }
  }

  Future<void> _toggleMicrophone() async {
    await _webrtcService.toggleMicrophone();
    setState(() {
      _isMicrophoneEnabled = _webrtcService.isMicrophoneEnabled;
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _callTimer?.cancel();
    _callStatusCheckTimer?.cancel();
    _callSubscription?.cancel();
    _webrtcService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final otherProfile = _profileRepository.watchProfile(widget.otherUid);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: StreamBuilder(
          stream: otherProfile,
          builder: (context, snapshot) {
            final profile = snapshot.data;
            final displayName = profile?.displayName ?? 'Người dùng';
            final photoUrl = profile?.photoUrl;

            return Column(
              children: [
                // Header với thời gian cuộc gọi
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (_call?.status == CallStatus.accepted)
                        Text(
                          _formatDuration(_callDuration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else if (_call?.status == CallStatus.ringing)
                        Text(
                          widget.isCaller ? 'Đang gọi...' : 'Cuộc gọi đến',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                    ],
                  ),
                ),

                // Avatar và tên
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 80,
                          backgroundImage: photoUrl != null
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl == null
                              ? Text(
                                  displayName[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 48,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Control buttons
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Microphone toggle
                      if (_call?.status == CallStatus.accepted)
                        _buildControlButton(
                          icon: _isMicrophoneEnabled
                              ? Icons.mic
                              : Icons.mic_off,
                          color: _isMicrophoneEnabled
                              ? Colors.blue
                              : Colors.red,
                          onPressed: _toggleMicrophone,
                        ),

                      // Answer/End button
                      if (!widget.isCaller &&
                          _call?.status == CallStatus.ringing)
                        _buildControlButton(
                          icon: Icons.call,
                          color: Colors.green,
                          onPressed: _answerCall,
                        )
                      else if (_call?.status == CallStatus.accepted ||
                          (_call?.status == CallStatus.ringing &&
                              widget.isCaller))
                        _buildControlButton(
                          icon: Icons.call_end,
                          color: Colors.red,
                          onPressed: _endCall,
                        ),

                      // Reject button (chỉ hiện khi đang ringing và là callee)
                      if (!widget.isCaller &&
                          _call?.status == CallStatus.ringing)
                        _buildControlButton(
                          icon: Icons.call_end,
                          color: Colors.red,
                          onPressed: _rejectCall,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return CircleAvatar(
      radius: 32,
      backgroundColor: color,
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

