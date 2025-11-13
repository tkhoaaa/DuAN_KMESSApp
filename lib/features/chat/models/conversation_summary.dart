import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationSummary {
  ConversationSummary({
    required this.id,
    required this.type,
    required this.participantIds,
    this.name,
    this.avatarUrl,
    this.lastMessagePreview,
    this.lastMessageSenderId,
    this.lastMessageAt,
  });

  final String id;
  final String type; // direct | group
  final List<String> participantIds;
  final String? name;
  final String? avatarUrl;
  final String? lastMessagePreview;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;

  factory ConversationSummary.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final lastMessage = data['lastMessage'] as Map<String, dynamic>?;

    return ConversationSummary(
      id: doc.id,
      type: data['type'] as String? ?? 'direct',
      participantIds: (data['participantIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      name: data['name'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      lastMessagePreview: lastMessage?['text'] as String?,
      lastMessageSenderId: lastMessage?['senderId'] as String?,
      lastMessageAt:
          (lastMessage?['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

