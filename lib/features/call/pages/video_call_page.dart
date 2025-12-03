import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../auth/auth_repository.dart';
import '../../profile/user_profile_repository.dart';
import '../models/call.dart';
import '../repositories/call_repository.dart';
import '../services/call_service.dart';
import '../services/webrtc_service.dart';

class VideoCallPage extends StatefulWidget {
  const VideoCallPage({
    required this.callId,
    required this.otherUid,
    required this.isCaller,
    super.key,
  });

  final String callId;
  final String otherUid;
  final bool isCaller;

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  late final CallService _callService;
  late final UserProfileRepository _profileRepository;
  late final WebRTCService _webrtcService;
  late final CallRepository _callRepository;

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  Call? _call;
  StreamSubscription<Call?>? _callSubscription;
  Timer? _callTimer;
  Timer? _remoteVideoCheckTimer;
  Timer? _callStatusCheckTimer; // Timer để check call status định kỳ (fallback)
  Duration _callDuration = Duration.zero;
  bool _isMicrophoneEnabled = true;
  bool _isCameraEnabled = true;
  bool _isLocalVideoMinimized = false;
  bool _isDisposed = false;
  bool _isEndingCall = false; // Flag để tránh gọi _endCall nhiều lần
  bool _renderersInitialized = false;
  bool _isRemoteVideoEnabled = true;
  DateTime _lastCallSnapshotAt = DateTime.now();
  static const Duration _statusSilentThreshold = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _callService = CallService();
    _profileRepository = userProfileRepository;
    _webrtcService = WebRTCService();
    _callRepository = CallRepository();

    _initializeRenderers();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    setState(() {
      _renderersInitialized = true;
    });

    if (widget.isCaller) {
      _initializeCaller();
    } else {
      _initializeCallee();
    }

    _watchCall();
  }

  Future<void> _initializeCaller() async {
    try {
      // Request permissions
      final micPermission = await Permission.microphone.request();
      final cameraPermission = await Permission.camera.request();

      if (!micPermission.isGranted || !cameraPermission.isGranted) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Cần quyền truy cập'),
              content: const Text(
                'Ứng dụng cần quyền microphone và camera để thực hiện cuộc gọi video. '
                'Vui lòng cấp quyền trong Cài đặt.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Đóng'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await openAppSettings();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Mở Cài đặt'),
                ),
              ],
            ),
          );
        }
        return;
      }

      await _webrtcService.initializeCaller(
        callId: widget.callId,
        callType: CallType.video,
        localRenderer: _localRenderer,
        remoteRenderer: _remoteRenderer,
      );
      setState(() {
        _isMicrophoneEnabled = _webrtcService.isMicrophoneEnabled;
        _isCameraEnabled = _webrtcService.isCameraEnabled;
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
      // Request permissions
      final micPermission = await Permission.microphone.request();
      final cameraPermission = await Permission.camera.request();

      if (!micPermission.isGranted || !cameraPermission.isGranted) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Cần quyền truy cập'),
              content: const Text(
                'Ứng dụng cần quyền microphone và camera để thực hiện cuộc gọi video. '
                'Vui lòng cấp quyền trong Cài đặt.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Đóng'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await openAppSettings();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Mở Cài đặt'),
                ),
              ],
            ),
          );
        }
        return;
      }

      await _webrtcService.initializeCallee(
        callId: widget.callId,
        callType: CallType.video,
        localRenderer: _localRenderer,
        remoteRenderer: _remoteRenderer,
      );
      setState(() {
        _isMicrophoneEnabled = _webrtcService.isMicrophoneEnabled;
        _isCameraEnabled = _webrtcService.isCameraEnabled;
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
      if (!mounted || _isDisposed || _isEndingCall) {
        debugPrint('_watchCall: Skipping update - mounted: $mounted, disposed: $_isDisposed, ending: $_isEndingCall');
        return;
      }

      _lastCallSnapshotAt = DateTime.now();

      if (call == null) {
        debugPrint('_watchCall: Call document missing, ending call');
        _endCall();
        return;
      }

      final shouldRebuildUi = _call == null ||
          _call!.status != call.status ||
          _call!.startedAt != call.startedAt ||
          _call!.endedAt != call.endedAt ||
          _call!.duration != call.duration;

      _call = call;

      if (shouldRebuildUi && !_isEndingCall) {
        debugPrint('_watchCall: Significant call change (${call.status}), rebuilding UI');
        setState(() {});
      }

      if (call.status == CallStatus.accepted && _callTimer == null && !_isEndingCall) {
        debugPrint('_watchCall: Call accepted, starting timers');
        _startCallTimer();
        _startRemoteVideoCheckTimer();
        _startCallStatusCheckTimer(); // Start fallback timer
      }

      if (call.status == CallStatus.ended ||
          call.status == CallStatus.rejected ||
          call.status == CallStatus.cancelled ||
          call.status == CallStatus.missed) {
        debugPrint('_watchCall: Call ended/rejected/cancelled/missed - ${call.status}');
        if (!_isEndingCall) {
          _callStatusCheckTimer?.cancel(); // Cancel fallback timer
          _endCall();
        } else {
          debugPrint('_watchCall: Already ending call, skipping');
        }
      }
    }, onError: (error) {
      debugPrint('Error watching call: $error');
      if (mounted && !_isDisposed && !_isEndingCall) {
        _endCall();
      }
    });
  }
  
  void _startRemoteVideoCheckTimer() {
    _remoteVideoCheckTimer?.cancel();
    _remoteVideoCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted || _isDisposed || _isEndingCall) {
        timer.cancel();
        return;
      }
      if (_call?.status == CallStatus.accepted && !_isEndingCall) {
        _checkRemoteVideoState();
      } else {
        timer.cancel();
      }
    });
  }
  
  void _checkRemoteVideoState() {
    if (_isDisposed || _isEndingCall || !mounted) return;
    
    final isEnabled = _webrtcService.isRemoteVideoEnabled;
    if (_isRemoteVideoEnabled != isEnabled && mounted && !_isEndingCall) {
      setState(() {
        _isRemoteVideoEnabled = isEnabled;
      });
    }
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isDisposed || _isEndingCall) {
        timer.cancel();
        return;
      }

      if (!_isEndingCall && mounted) {
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

  /// Fallback timer để check call status định kỳ (nếu stream không update)
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
        // Fetch call status trực tiếp từ Firestore khi stream im lặng quá lâu
        final call = await _callRepository.fetchCall(widget.callId).timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            debugPrint('Call status check timer: fetchCall timeout');
            return null;
          },
        );

        _lastCallSnapshotAt = DateTime.now();
        
        if (call == null) {
          debugPrint('Call status check timer: Call not found, ending');
          timer.cancel();
          if (!_isEndingCall) {
            _endCall();
          }
          return;
        }
        
        debugPrint('Call status check timer: Current status - ${call.status}');
        
        // Nếu call đã kết thúc nhưng stream chưa update
        if ((call.status == CallStatus.ended ||
            call.status == CallStatus.rejected ||
            call.status == CallStatus.cancelled ||
            call.status == CallStatus.missed) &&
            !_isEndingCall) {
          debugPrint('Call status check timer detected call ended: ${call.status}');
          timer.cancel();
          _endCall();
        }
      } catch (e) {
        debugPrint('Error in call status check timer: $e');
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
    debugPrint('_endCall called: disposed=$_isDisposed, ending=$_isEndingCall, mounted=$mounted');
    
    // Nếu đã đang ending, chỉ cần đảm bảo navigate back
    if (_isEndingCall) {
      debugPrint('_endCall: Already ending, ensuring navigation');
      if (mounted) {
        final navigator = Navigator.maybeOf(context);
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        }
      }
      return;
    }
    
    // Đánh dấu đã ending để tránh gọi lại
    _isEndingCall = true;
    
    debugPrint('Ending call: ${widget.callId}');
    
    // Cancel tất cả timers trước
    _callTimer?.cancel();
    _callTimer = null;
    _remoteVideoCheckTimer?.cancel();
    _remoteVideoCheckTimer = null;
    _callStatusCheckTimer?.cancel();
    _callStatusCheckTimer = null;
    
    // Cancel subscription (không await để tránh block)
    _callSubscription?.cancel();
    _callSubscription = null;
    
    // Navigate back TRƯỚC khi dispose để tránh block UI
    // Điều này đảm bảo UI được đóng ngay lập tức
    if (mounted) {
      final navigator = Navigator.maybeOf(context);
      if (navigator != null && navigator.canPop()) {
        debugPrint('_endCall: Navigating back');
        navigator.pop();
      } else {
        debugPrint('_endCall: Cannot pop, navigator is null or cannot pop');
      }
    } else {
      debugPrint('_endCall: Widget not mounted, cannot navigate');
    }
    
    // Đánh dấu disposed sau khi navigate
    _isDisposed = true;
    
    // Dispose WebRTC service và renderers trong background (không block UI)
    // Không await để không block UI thread
    Future(() async {
      try {
        await _webrtcService.dispose().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            debugPrint('WebRTC dispose timeout');
          },
        );
      } catch (e) {
        debugPrint('Error disposing WebRTC service: $e');
      }
      
      try {
        await _localRenderer.dispose().timeout(
          const Duration(seconds: 1),
          onTimeout: () {
            debugPrint('Local renderer dispose timeout');
          },
        );
      } catch (e) {
        debugPrint('Error disposing local renderer: $e');
      }
      
      try {
        await _remoteRenderer.dispose().timeout(
          const Duration(seconds: 1),
          onTimeout: () {
            debugPrint('Remote renderer dispose timeout');
          },
        );
      } catch (e) {
        debugPrint('Error disposing remote renderer: $e');
      }
    }).catchError((e) {
      debugPrint('Error in background dispose: $e');
    });
    
    // Update call status (không await để tránh block)
    _callService.endCall(widget.callId).catchError((e) {
      debugPrint('Error ending call: $e');
    });
  }

  Future<void> _toggleMicrophone() async {
    await _webrtcService.toggleMicrophone();
    setState(() {
      _isMicrophoneEnabled = _webrtcService.isMicrophoneEnabled;
    });
  }

  Future<void> _toggleCamera() async {
    if (_isDisposed || !mounted) return;
    
    // Kiểm tra call status
    if (_call?.status != CallStatus.accepted) {
      return;
    }
    
    try {
      // Lưu state hiện tại
      final currentState = _isCameraEnabled;
      
      // Update state trước để UI responsive
      if (mounted) {
        setState(() {
          _isCameraEnabled = !_isCameraEnabled;
        });
      }
      
      // Toggle camera
      await _webrtcService.toggleCamera();
      
      // Update lại state sau khi toggle để đảm bảo sync
      if (mounted && !_isDisposed) {
        setState(() {
          _isCameraEnabled = _webrtcService.isCameraEnabled;
        });
      }
    } catch (e) {
      // Rollback state nếu có lỗi
      if (mounted && !_isDisposed) {
        setState(() {
          _isCameraEnabled = _webrtcService.isCameraEnabled;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tắt/bật camera: $e')),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    await _webrtcService.switchCamera();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    
    debugPrint('VideoCallPage dispose called');
    _isDisposed = true;
    _isEndingCall = true;
    
    // Cancel tất cả timers
    _callTimer?.cancel();
    _callTimer = null;
    _remoteVideoCheckTimer?.cancel();
    _remoteVideoCheckTimer = null;
    _callStatusCheckTimer?.cancel();
    _callStatusCheckTimer = null;
    
    // Cancel subscription
    _callSubscription?.cancel();
    _callSubscription = null;
    
    // Dispose WebRTC service (async nhưng không await để tránh block)
    _webrtcService.dispose().catchError((e) {
      debugPrint('Error disposing WebRTC service in dispose: $e');
    });
    
    // Dispose renderers (async nhưng không await để tránh block)
    _localRenderer.dispose().catchError((e) {
      debugPrint('Error disposing local renderer: $e');
    });
    _remoteRenderer.dispose().catchError((e) {
      debugPrint('Error disposing remote renderer: $e');
    });
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_renderersInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final otherProfile = _profileRepository.watchProfile(widget.otherUid);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: StreamBuilder(
          stream: otherProfile,
          builder: (context, snapshot) {
            final profile = snapshot.data;
            final displayName = profile?.displayName ?? 'Người dùng';

            return Stack(
              children: [
                // Remote video (full screen)
                Positioned.fill(
                  child: _remoteRenderer.srcObject != null && _isRemoteVideoEnabled
                      ? RTCVideoView(
                          _remoteRenderer,
                          mirror: false,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      : Container(
                          color: Colors.black,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.videocam_off,
                                  color: Colors.white,
                                  size: 64,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Camera đã tắt',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),

                // Local video (picture-in-picture)
                if (_call?.status == CallStatus.accepted && _isCameraEnabled)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isLocalVideoMinimized = !_isLocalVideoMinimized;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: _isLocalVideoMinimized ? 120 : 150,
                        height: _isLocalVideoMinimized ? 160 : 200,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _isCameraEnabled
                              ? RTCVideoView(
                                  _localRenderer,
                                  mirror: true,
                                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                )
                              : Container(
                                  color: Colors.black,
                                  child: const Center(
                                    child: Icon(
                                      Icons.videocam_off,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),

                // Overlay với thông tin và controls
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        // Header với thời gian
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_call?.status == CallStatus.accepted)
                                Text(
                                  _formatDuration(_callDuration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
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

                        // Tên người gọi (khi chưa accept)
                        if (_call?.status == CallStatus.ringing)
                          Expanded(
                            child: Center(
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        else
                          const Spacer(),

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

                              // Camera toggle
                              if (_call?.status == CallStatus.accepted)
                                _buildControlButton(
                                  icon: _isCameraEnabled
                                      ? Icons.videocam
                                      : Icons.videocam_off,
                                  color: _isCameraEnabled
                                      ? Colors.blue
                                      : Colors.red,
                                  onPressed: _toggleCamera,
                                ),

                              // Switch camera
                              if (_call?.status == CallStatus.accepted)
                                _buildControlButton(
                                  icon: Icons.flip_camera_ios,
                                  color: Colors.blue,
                                  onPressed: _switchCamera,
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
                                  onPressed: () {
                                    if (!_isEndingCall && !_isDisposed) {
                                      _endCall();
                                    }
                                  },
                                ),

                              // Reject button
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
                    ),
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

