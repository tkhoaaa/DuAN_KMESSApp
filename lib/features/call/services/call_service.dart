import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../auth/auth_repository.dart';
import '../../notifications/models/notification.dart';
import '../../notifications/services/notification_service.dart';
import '../../profile/user_profile_repository.dart';
import '../models/call.dart';
import '../repositories/call_repository.dart';

class CallService {
  CallService({
    CallRepository? repository,
    NotificationService? notificationService,
    UserProfileRepository? profileRepository,
  })  : _repository = repository ?? CallRepository(),
        _notificationService = notificationService ?? NotificationService(),
        _profileRepository = profileRepository ?? userProfileRepository;

  final CallRepository _repository;
  final NotificationService _notificationService;
  final UserProfileRepository _profileRepository;

  /// Khởi tạo cuộc gọi
  Future<String> initiateCall({
    required String calleeUid,
    required CallType type,
    String? conversationId,
  }) async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) {
      throw StateError('Bạn cần đăng nhập');
    }

    if (currentUid == calleeUid) {
      throw StateError('Không thể gọi cho chính mình');
    }

    // Kiểm tra callee có tồn tại không
    final calleeProfile = await _profileRepository.fetchProfile(calleeUid);
    if (calleeProfile == null) {
      throw StateError('Không tìm thấy người dùng');
    }

    // Tạo call document
    final callId = await _repository.createCall(
      callerUid: currentUid,
      calleeUid: calleeUid,
      type: type,
      conversationId: conversationId,
    );

    // Tạo notification cho callee
    try {
      await _notificationService.createCallNotification(
        callId: callId,
        callerUid: currentUid,
        calleeUid: calleeUid,
        callType: type,
      );
    } catch (e) {
      debugPrint('Error creating call notification: $e');
      // Không throw error vì call đã được tạo
    }

    return callId;
  }

  /// Chấp nhận cuộc gọi
  Future<void> answerCall(String callId) async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) {
      throw StateError('Bạn cần đăng nhập');
    }

    final call = await _repository.fetchCall(callId);
    if (call == null) {
      throw StateError('Không tìm thấy cuộc gọi');
    }

    if (call.calleeUid != currentUid) {
      throw StateError('Bạn không phải người nhận cuộc gọi');
    }

    if (call.status != CallStatus.ringing) {
      throw StateError('Cuộc gọi không còn ở trạng thái ringing');
    }

    await _repository.updateCallStatus(
      callId,
      CallStatus.accepted,
      startedAt: DateTime.now(),
    );
  }

  /// Từ chối cuộc gọi
  Future<void> rejectCall(String callId) async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) {
      throw StateError('Bạn cần đăng nhập');
    }

    final call = await _repository.fetchCall(callId);
    if (call == null) {
      throw StateError('Không tìm thấy cuộc gọi');
    }

    if (call.calleeUid != currentUid) {
      throw StateError('Bạn không phải người nhận cuộc gọi');
    }

    await _repository.updateCallStatus(
      callId,
      CallStatus.rejected,
      endedAt: DateTime.now(),
    );

    unawaited(_repository.clearSignalingData(callId));
  }

  /// Kết thúc cuộc gọi
  Future<void> endCall(String callId) async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) {
      throw StateError('Bạn cần đăng nhập');
    }

    final call = await _repository.fetchCall(callId);
    if (call == null) {
      throw StateError('Không tìm thấy cuộc gọi');
    }

    if (call.callerUid != currentUid && call.calleeUid != currentUid) {
      throw StateError('Bạn không có quyền kết thúc cuộc gọi này');
    }

    final now = DateTime.now();
    int? duration;

    if (call.startedAt != null) {
      duration = now.difference(call.startedAt!).inSeconds;
    }

    await _repository.endCall(
      callId,
      status: CallStatus.ended,
      endedAt: now,
      duration: duration,
    );

    unawaited(_repository.clearSignalingData(callId));
  }

  /// Hủy cuộc gọi (chỉ caller mới cancel được)
  Future<void> cancelCall(String callId) async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) {
      throw StateError('Bạn cần đăng nhập');
    }

    final call = await _repository.fetchCall(callId);
    if (call == null) {
      throw StateError('Không tìm thấy cuộc gọi');
    }

    if (call.callerUid != currentUid) {
      throw StateError('Chỉ người gọi mới có thể hủy cuộc gọi');
    }

    if (call.status != CallStatus.ringing) {
      throw StateError('Chỉ có thể hủy cuộc gọi đang ringing');
    }

    await _repository.updateCallStatus(
      callId,
      CallStatus.cancelled,
      endedAt: DateTime.now(),
    );

    unawaited(_repository.clearSignalingData(callId));
  }

  /// Xử lý missed call (tự động sau timeout)
  Future<void> handleMissedCall(String callId) async {
    final call = await _repository.fetchCall(callId);
    if (call == null) return;

    if (call.status == CallStatus.ringing) {
      await _repository.updateCallStatus(
        callId,
        CallStatus.missed,
        endedAt: DateTime.now(),
      );

      unawaited(_repository.clearSignalingData(callId));
    }
  }

  /// Stream call để realtime updates
  Stream<Call?> watchCall(String callId) {
    return _repository.watchCall(callId);
  }

  /// Stream active calls của user
  Stream<List<Call>> watchActiveCalls(String uid) {
    return _repository.watchActiveCalls(uid);
  }

  /// Lấy lịch sử cuộc gọi
  Future<List<Call>> fetchCallHistory(String uid, {int limit = 50}) async {
    return _repository.fetchCallHistory(uid, limit: limit);
  }
}

