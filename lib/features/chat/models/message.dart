import 'package:cloud_firestore/cloud_firestore.dart';

import 'message_attachment.dart';

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.type,
    this.text,
    required this.createdAt,
    this.attachments = const [],
    this.seenBy = const [],
    this.replyTo,
    this.systemPayload,
  });

  final String id;
  final String senderId;
  final String type;
  final String? text;
  final DateTime createdAt;
  final List<MessageAttachment> attachments;
  final List<String> seenBy;
  final String? replyTo;
  final Map<String, dynamic>? systemPayload;

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'type': type,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'attachments': attachments.map((a) => a.toMap()).toList(),
      'seenBy': seenBy,
      'replyTo': replyTo,
      'systemPayload': systemPayload,
    };
  }

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      type: data['type'] as String? ?? 'text',
      text: data['text'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      attachments: (data['attachments'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((raw) => MessageAttachment.fromMap(
              Map<String, dynamic>.from(raw)))
          .toList(),
      seenBy: (data['seenBy'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      replyTo: data['replyTo'] as String?,
      systemPayload: data['systemPayload'] == null
          ? null
          : Map<String, dynamic>.from(
              data['systemPayload'] as Map<String, dynamic>),
    );
  }
}

