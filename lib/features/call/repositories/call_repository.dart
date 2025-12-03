import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/call.dart';

class CallRepository {
  CallRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _callsRef =>
      _firestore.collection('calls');

  CollectionReference<Map<String, dynamic>> _candidatesRef(String callId) =>
      _callsRef.doc(callId).collection('candidates');

  /// Tạo cuộc gọi mới
  Future<String> createCall({
    required String callerUid,
    required String calleeUid,
    required CallType type,
    String? conversationId,
  }) async {
    final now = DateTime.now();
    final callDoc = _callsRef.doc();
    final callId = callDoc.id;

    await callDoc.set({
      'callerUid': callerUid,
      'calleeUid': calleeUid,
      'type': type.name,
      'status': CallStatus.ringing.name,
      'conversationId': conversationId,
      'startedAt': null,
      'endedAt': null,
      'duration': null,
      'callerOffer': null,
      'calleeAnswer': null,
      'callerCandidates': [],
      'calleeCandidates': [],
      'iceCandidates': [],
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    return callId;
  }

  /// Stream call document để realtime updates
  Stream<Call?> watchCall(String callId) {
    return _callsRef.doc(callId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Call.fromDoc(doc);
    });
  }

  /// Cập nhật trạng thái cuộc gọi
  Future<void> updateCallStatus(
    String callId,
    CallStatus status, {
    DateTime? startedAt,
    DateTime? endedAt,
    int? duration,
  }) async {
    final updates = <String, dynamic>{
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (startedAt != null) {
      updates['startedAt'] = Timestamp.fromDate(startedAt);
    }

    if (endedAt != null) {
      updates['endedAt'] = Timestamp.fromDate(endedAt);
    }

    if (duration != null) {
      updates['duration'] = duration;
    }

    await _callsRef.doc(callId).update(updates);
  }

  /// Cập nhật signaling data (offer, answer, ICE candidates)
  Future<void> updateCallSignaling(
    String callId, {
    Map<String, dynamic>? offer,
    Map<String, dynamic>? answer,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (offer != null) {
      updates['callerOffer'] = offer;
    }

    if (answer != null) {
      updates['calleeAnswer'] = answer;
    }

    await _callsRef.doc(callId).update(updates);
  }

  /// Thêm ICE candidate (lưu vào subcollection để tránh phình to document chính)
  Future<void> addIceCandidate(
    String callId, {
    required Map<String, dynamic> candidate,
    required bool isCaller,
  }) async {
    final owner = isCaller ? 'caller' : 'callee';
    await _candidatesRef(callId).add({
      'owner': owner,
      'candidate': candidate['candidate'],
      'sdpMid': candidate['sdpMid'],
      'sdpMLineIndex': candidate['sdpMLineIndex'],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Lắng nghe ICE candidates từ subcollection (remote peer)
  Stream<List<Map<String, dynamic>>> watchIceCandidates(
    String callId, {
    required bool listenForCaller,
  }) {
    final remoteOwner = listenForCaller ? 'callee' : 'caller';
    return _candidatesRef(callId)
        .where('owner', isEqualTo: remoteOwner)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return {
          ...doc.data(),
          '_docId': doc.id,
        };
      }).toList();
    });
  }

  /// Kết thúc cuộc gọi
  Future<void> endCall(
    String callId, {
    CallStatus? status,
    DateTime? endedAt,
    int? duration,
  }) async {
    final updates = <String, dynamic>{
      'status': (status ?? CallStatus.ended).name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (endedAt != null) {
      updates['endedAt'] = Timestamp.fromDate(endedAt);
    } else {
      updates['endedAt'] = FieldValue.serverTimestamp();
    }

    if (duration != null) {
      updates['duration'] = duration;
    }

    await _callsRef.doc(callId).update(updates);
  }

  /// Lấy lịch sử cuộc gọi
  Future<List<Call>> fetchCallHistory(
    String uid, {
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _callsRef
        .where(
          Filter.or(
            Filter('callerUid', isEqualTo: uid),
            Filter('calleeUid', isEqualTo: uid),
          ),
        )
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Call.fromDoc(doc)).toList();
  }

  /// Stream các cuộc gọi đang active (ringing hoặc accepted)
  Stream<List<Call>> watchActiveCalls(String uid) {
    return _callsRef
        .where(
          Filter.or(
            Filter('callerUid', isEqualTo: uid),
            Filter('calleeUid', isEqualTo: uid),
          ),
        )
        .where('status', whereIn: [
          CallStatus.ringing.name,
          CallStatus.accepted.name,
        ])
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Call.fromDoc(doc)).toList());
  }

  /// Lấy call document
  Future<Call?> fetchCall(String callId) async {
    final doc = await _callsRef.doc(callId).get();
    if (!doc.exists) return null;
    return Call.fromDoc(doc);
  }

  /// Dọn dẹp signaling data sau khi kết thúc cuộc gọi
  Future<void> clearSignalingData(String callId) async {
    final callDoc = _callsRef.doc(callId);
    try {
      await callDoc.update({
        'callerOffer': null,
        'calleeAnswer': null,
        'callerCandidates': [],
        'calleeCandidates': [],
        'iceCandidates': [],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Có thể call đã bị xóa hoặc không tồn tại, bỏ qua
    }

    try {
      final candidatesSnapshot = await _candidatesRef(callId).get();
      for (final doc in candidatesSnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (_) {
      // Không cần throw khi dọn dẹp thất bại
    }
  }
}

