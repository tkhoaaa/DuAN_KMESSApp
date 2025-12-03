import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/call.dart';
import '../repositories/call_repository.dart';

class WebRTCService {
  WebRTCService({CallRepository? repository})
      : _repository = repository ?? CallRepository();

  final CallRepository _repository;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;

  StreamController<MediaStream>? _remoteStreamController;
  Stream<MediaStream>? _remoteStreamSubscription;

  bool _isInitialized = false;
  bool _isCaller = false;
  String? _currentCallId;

  /// Khởi tạo WebRTC cho caller
  Future<void> initializeCaller({
    required String callId,
    required CallType callType,
    RTCVideoRenderer? localRenderer,
    RTCVideoRenderer? remoteRenderer,
  }) async {
    if (_isInitialized) {
      throw StateError('WebRTC đã được khởi tạo');
    }

    _isCaller = true;
    _currentCallId = callId;
    _localRenderer = localRenderer;
    _remoteRenderer = remoteRenderer;

    try {
      // Tạo peer connection
      _peerConnection = await _createPeerConnection();

      // Lấy local media stream
      _localStream = await _getUserMedia(callType);

      // Thêm local stream vào peer connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Hiển thị local stream
      if (_localRenderer != null && callType == CallType.video) {
        _localRenderer!.srcObject = _localStream;
      }

      // Lắng nghe remote stream
      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          if (_remoteRenderer != null && callType == CallType.video) {
            _remoteRenderer!.srcObject = _remoteStream;
          }
          _remoteStreamController?.add(_remoteStream!);
          
          // Lắng nghe video track enabled/disabled events
          if (callType == CallType.video && event.track != null) {
            final videoTrack = event.track as MediaStreamTrack?;
            if (videoTrack != null && videoTrack.kind == 'video') {
              // Track enabled state sẽ tự động sync với remote peer
              // Khi remote peer toggle camera, track.enabled sẽ thay đổi
            }
          }
        }
      };

      // Lắng nghe ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        _handleIceCandidate(callId, candidate);
      };

      // Tạo offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Lưu offer vào Firestore
      await _repository.updateCallSignaling(
        callId,
        offer: {
          'type': offer.type,
          'sdp': offer.sdp,
        },
      );

      // Lắng nghe answer từ callee
      _watchForAnswer(callId);
      // Lắng nghe ICE candidates từ remote
      _watchForIceCandidates(callId);

      _isInitialized = true;
    } catch (e) {
      developer.log('Error initializing caller: $e');
      await dispose();
      rethrow;
    }
  }

  /// Khởi tạo WebRTC cho callee
  Future<void> initializeCallee({
    required String callId,
    required CallType callType,
    RTCVideoRenderer? localRenderer,
    RTCVideoRenderer? remoteRenderer,
  }) async {
    if (_isInitialized) {
      throw StateError('WebRTC đã được khởi tạo');
    }

    _isCaller = false;
    _currentCallId = callId;
    _localRenderer = localRenderer;
    _remoteRenderer = remoteRenderer;

    try {
      // Tạo peer connection
      _peerConnection = await _createPeerConnection();

      // Lấy local media stream
      _localStream = await _getUserMedia(callType);

      // Thêm local stream vào peer connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Hiển thị local stream
      if (_localRenderer != null && callType == CallType.video) {
        _localRenderer!.srcObject = _localStream;
      }

      // Lắng nghe remote stream
      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          if (_remoteRenderer != null && callType == CallType.video) {
            _remoteRenderer!.srcObject = _remoteStream;
          }
          _remoteStreamController?.add(_remoteStream!);
          
          // Lắng nghe video track enabled/disabled events
          if (callType == CallType.video && event.track != null) {
            final videoTrack = event.track as MediaStreamTrack?;
            if (videoTrack != null && videoTrack.kind == 'video') {
              // Track enabled state sẽ tự động sync với remote peer
              // Khi remote peer toggle camera, track.enabled sẽ thay đổi
            }
          }
        }
      };

      // Lắng nghe ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        _handleIceCandidate(callId, candidate);
      };

      // Lắng nghe offer từ caller
      _watchForOffer(callId);
      // Lắng nghe ICE candidates từ remote
      _watchForIceCandidates(callId);

      _isInitialized = true;
    } catch (e) {
      developer.log('Error initializing callee: $e');
      await dispose();
      rethrow;
    }
  }

  StreamSubscription<Call?>? _offerSubscription;
  StreamSubscription<Call?>? _answerSubscription;
  StreamSubscription<Call?>? _iceSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _iceCandidatesSubscription;
  bool _offerHandled = false;
  bool _answerHandled = false;

  /// Lắng nghe offer từ caller và tạo answer
  void _watchForOffer(String callId) {
    _offerSubscription?.cancel();
    _offerHandled = false;
    _offerSubscription = _repository.watchCall(callId).listen((call) {
      if (call == null || _peerConnection == null || _offerHandled) return;

      final offer = call.callerOffer;
      if (offer != null) {
        _offerHandled = true;
        _handleOffer(callId, offer).catchError((e) {
          developer.log('Error handling offer: $e');
          // Reset flag nếu lỗi để có thể thử lại
          _offerHandled = false;
        });
      }
    });
  }

  Future<void> _handleOffer(String callId, Map<String, dynamic> offer) async {
    if (_peerConnection == null) return;

    try {
      // Set remote description (offer)
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offer['sdp'] as String, offer['type'] as String),
      );

      // Tạo answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Lưu answer vào Firestore
      await _repository.updateCallSignaling(
        callId,
        answer: {
          'type': answer.type,
          'sdp': answer.sdp,
        },
      );
    } catch (e) {
      developer.log('Error handling offer: $e');
      // Nếu lỗi do remote description đã được set hoặc invalid state, không cần throw
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('remoteDescription') || 
          errorStr.contains('invalidstate') ||
          errorStr.contains('invalid state') ||
          errorStr.contains('already set')) {
        developer.log('Remote description already set or invalid state, ignoring error');
        return;
      }
      rethrow;
    }
  }

  /// Lắng nghe answer từ callee
  void _watchForAnswer(String callId) {
    _answerSubscription?.cancel();
    _answerHandled = false;
    _answerSubscription = _repository.watchCall(callId).listen((call) {
      if (call == null || _peerConnection == null || _answerHandled) return;

      final answer = call.calleeAnswer;
      if (answer != null) {
        _answerHandled = true;
        _handleAnswer(answer).catchError((e) {
          developer.log('Error handling answer: $e');
          // Reset flag nếu lỗi để có thể thử lại
          _answerHandled = false;
        });
      }
    });
  }

  Future<void> _handleAnswer(Map<String, dynamic> answer) async {
    if (_peerConnection == null) return;

    try {
      // Set remote description (answer)
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(answer['sdp'] as String, answer['type'] as String),
      );
    } catch (e) {
      developer.log('Error handling answer: $e');
      // Nếu lỗi do remote description đã được set hoặc invalid state, không cần throw
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('remoteDescription') || 
          errorStr.contains('invalidstate') ||
          errorStr.contains('invalid state') ||
          errorStr.contains('already set')) {
        developer.log('Remote description already set or invalid state, ignoring error');
        return;
      }
      rethrow;
    }
  }

  /// Xử lý ICE candidates
  Future<void> _handleIceCandidate(String callId, RTCIceCandidate candidate) async {
    try {
      await _repository.addIceCandidate(
        callId,
        candidate: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
        isCaller: _isCaller,
      );
    } catch (e) {
      developer.log('Error adding ICE candidate: $e');
    }
  }

  Set<String> _processedIceCandidates = {};

  /// Lắng nghe ICE candidates từ remote peer
  void _watchForIceCandidates(String callId) {
    _iceSubscription?.cancel();
    _iceCandidatesSubscription?.cancel();
    _processedIceCandidates.clear();

    _iceCandidatesSubscription = _repository
        .watchIceCandidates(
          callId,
          listenForCaller: _isCaller,
        )
        .listen((candidateDocs) {
      if (_peerConnection == null) return;

      for (final candidateData in candidateDocs) {
        final docId = candidateData['_docId'] as String?;
        final key = docId != null ? 'sub_$docId' : 'sub_${candidateData['candidate']}';
        if (_processedIceCandidates.contains(key)) continue;

        _processedIceCandidates.add(key);
        _handleIceCandidateFromRemote(candidateData).catchError((e) {
          developer.log('Error adding ICE candidate: $e');
        });
      }
    });

    // Legacy fallback để hỗ trợ các document cũ vẫn lưu candidates ngay trên call doc
    _iceSubscription = _repository.watchCall(callId).listen((call) {
      if (call == null || _peerConnection == null) return;

      final candidates = _isCaller
          ? (call.calleeCandidates.isNotEmpty ? call.calleeCandidates : call.iceCandidates)
          : (call.callerCandidates.isNotEmpty ? call.callerCandidates : call.iceCandidates);
      for (final candidateData in candidates) {
        final candidateKey = 'legacy_${candidateData['candidate'] as String? ?? ''}';
        if (_processedIceCandidates.contains(candidateKey)) continue;

        _processedIceCandidates.add(candidateKey);
        _handleIceCandidateFromRemote(candidateData).catchError((e) {
          developer.log('Error adding ICE candidate: $e');
        });
      }
    });
  }

  Future<void> _handleIceCandidateFromRemote(Map<String, dynamic> candidateData) async {
    if (_peerConnection == null) return;

    try {
      final candidate = RTCIceCandidate(
        candidateData['candidate'] as String,
        candidateData['sdpMid'] as String?,
        candidateData['sdpMLineIndex'] as int?,
      );
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      developer.log('Error adding ICE candidate: $e');
    }
  }

  /// Tạo peer connection
  Future<RTCPeerConnection> _createPeerConnection() async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        // Có thể thêm TURN servers nếu cần
      ],
    };

    final constraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    return await createPeerConnection(configuration, constraints);
  }

  /// Lấy user media (camera/microphone)
  Future<MediaStream> _getUserMedia(CallType callType) async {
    final constraints = <String, dynamic>{
      'audio': true,
      'video': callType == CallType.video
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
            }
          : false,
    };

    return await navigator.mediaDevices.getUserMedia(constraints);
  }

  /// Toggle microphone
  Future<void> toggleMicrophone() async {
    if (_localStream == null) return;

    final audioTrack = _localStream!.getAudioTracks().firstOrNull;
    if (audioTrack != null) {
      audioTrack.enabled = !audioTrack.enabled;
    }
  }

  /// Toggle camera (chỉ cho video call)
  Future<void> toggleCamera() async {
    if (_localStream == null || _isInitialized == false) {
      developer.log('Cannot toggle camera: stream is null or not initialized');
      return;
    }

    final videoTrack = _localStream!.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      try {
        // Toggle enabled state
        final newState = !videoTrack.enabled;
        videoTrack.enabled = newState;
        developer.log('Camera toggled: ${newState ? "enabled" : "disabled"}');
        
        // Update local renderer để hiển thị/ẩn video
        // WebRTC sẽ tự động sync với remote peer khi track enabled/disabled
        // Không cần thao tác gì thêm với renderer
      } catch (e) {
        developer.log('Error toggling camera: $e');
        rethrow;
      }
    } else {
      developer.log('Cannot toggle camera: no video track found');
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    if (_localStream == null) return;

    final videoTrack = _localStream!.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      try {
        await Helper.switchCamera(videoTrack);
      } catch (e) {
        developer.log('Error switching camera: $e');
      }
    }
  }

  /// Stream remote media
  Stream<MediaStream>? get remoteStream => _remoteStreamSubscription;

  /// Kiểm tra microphone đang bật hay tắt
  bool get isMicrophoneEnabled {
    final audioTrack = _localStream?.getAudioTracks().firstOrNull;
    return audioTrack?.enabled ?? false;
  }

  /// Kiểm tra camera đang bật hay tắt
  bool get isCameraEnabled {
    final videoTrack = _localStream?.getVideoTracks().firstOrNull;
    return videoTrack?.enabled ?? false;
  }

  /// Kiểm tra remote video đang bật hay tắt
  bool get isRemoteVideoEnabled {
    if (_remoteStream == null) return false;
    final videoTrack = _remoteStream!.getVideoTracks().firstOrNull;
    return videoTrack?.enabled ?? false;
  }

  /// Giải phóng resources
  Future<void> dispose() async {
    _isInitialized = false;
    _isCaller = false;
    _currentCallId = null;

    await _offerSubscription?.cancel();
    await _answerSubscription?.cancel();
    await _iceSubscription?.cancel();
    await _iceCandidatesSubscription?.cancel();
    _offerSubscription = null;
    _answerSubscription = null;
    _iceSubscription = null;
    _iceCandidatesSubscription = null;
    _offerHandled = false;
    _answerHandled = false;
    _processedIceCandidates.clear();

    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        track.stop();
      });
      await _localStream!.dispose();
      _localStream = null;
    }

    if (_remoteStream != null) {
      _remoteStream!.getTracks().forEach((track) {
        track.stop();
      });
      await _remoteStream!.dispose();
      _remoteStream = null;
    }

    if (_localRenderer != null) {
      _localRenderer!.srcObject = null;
      await _localRenderer!.dispose();
      _localRenderer = null;
    }

    if (_remoteRenderer != null) {
      _remoteRenderer!.srcObject = null;
      await _remoteRenderer!.dispose();
      _remoteRenderer = null;
    }

    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }

    await _remoteStreamController?.close();
    _remoteStreamController = null;
    _remoteStreamSubscription = null;
  }
}

