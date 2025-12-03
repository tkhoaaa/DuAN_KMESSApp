import 'package:cloud_firestore/cloud_firestore.dart';

enum CallType {
  voice,
  video,
}

enum CallStatus {
  ringing,
  accepted,
  rejected,
  missed,
  ended,
  cancelled,
}

class Call {
  Call({
    required this.id,
    required this.callerUid,
    required this.calleeUid,
    required this.type,
    required this.status,
    this.conversationId,
    this.startedAt,
    this.endedAt,
    this.duration,
    this.callerOffer,
    this.calleeAnswer,
    this.callerCandidates = const [],
    this.calleeCandidates = const [],
    this.iceCandidates = const [], // Legacy field (pre v1.0) - keep for backward compatibility
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String callerUid;
  final String calleeUid;
  final CallType type;
  final CallStatus status;
  final String? conversationId;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? duration; // seconds
  final Map<String, dynamic>? callerOffer;
  final Map<String, dynamic>? calleeAnswer;
  final List<Map<String, dynamic>> callerCandidates;
  final List<Map<String, dynamic>> calleeCandidates;
  /// Legacy combined candidates list, kept for backward compatibility with older documents.
  final List<Map<String, dynamic>> iceCandidates;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'callerUid': callerUid,
      'calleeUid': calleeUid,
      'type': type.name,
      'status': status.name,
      'conversationId': conversationId,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'duration': duration,
      'callerOffer': callerOffer,
      'calleeAnswer': calleeAnswer,
      'callerCandidates': callerCandidates,
      'calleeCandidates': calleeCandidates,
      'iceCandidates': iceCandidates,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Call.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Call(
      id: doc.id,
      callerUid: data['callerUid'] as String,
      calleeUid: data['calleeUid'] as String,
      type: CallType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => CallType.voice,
      ),
      status: CallStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => CallStatus.ringing,
      ),
      conversationId: data['conversationId'] as String?,
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
      duration: data['duration'] as int?,
      callerOffer: data['callerOffer'] as Map<String, dynamic>?,
      calleeAnswer: data['calleeAnswer'] as Map<String, dynamic>?,
      callerCandidates: _mapCandidateList(data['callerCandidates'] as List<dynamic>?),
      calleeCandidates: _mapCandidateList(data['calleeCandidates'] as List<dynamic>?),
      iceCandidates: _mapCandidateList(data['iceCandidates'] as List<dynamic>?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Call copyWith({
    String? id,
    String? callerUid,
    String? calleeUid,
    CallType? type,
    CallStatus? status,
    String? conversationId,
    DateTime? startedAt,
    DateTime? endedAt,
    int? duration,
    Map<String, dynamic>? callerOffer,
    Map<String, dynamic>? calleeAnswer,
    List<Map<String, dynamic>>? callerCandidates,
    List<Map<String, dynamic>>? calleeCandidates,
    List<Map<String, dynamic>>? iceCandidates,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Call(
      id: id ?? this.id,
      callerUid: callerUid ?? this.callerUid,
      calleeUid: calleeUid ?? this.calleeUid,
      type: type ?? this.type,
      status: status ?? this.status,
      conversationId: conversationId ?? this.conversationId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      callerOffer: callerOffer ?? this.callerOffer,
      calleeAnswer: calleeAnswer ?? this.calleeAnswer,
      callerCandidates: callerCandidates ?? this.callerCandidates,
      calleeCandidates: calleeCandidates ?? this.calleeCandidates,
      iceCandidates: iceCandidates ?? this.iceCandidates,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

List<Map<String, dynamic>> _mapCandidateList(List<dynamic>? data) {
  return data
          ?.map(
            (e) => Map<String, dynamic>.from(
              e as Map<String, dynamic>,
            ),
          )
          .toList() ??
      [];
}

