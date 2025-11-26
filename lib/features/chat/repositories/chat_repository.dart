import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../notifications/services/notification_service.dart';
import '../models/conversation_summary.dart';
import '../models/message.dart';
import '../models/message_attachment.dart';

class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final NotificationService _notificationService = NotificationService();

  CollectionReference<Map<String, dynamic>> get _conversationCollection =>
      _firestore.collection('conversations');

  CollectionReference<Map<String, dynamic>> _messagesRef(
          String conversationId) =>
      _conversationCollection
          .doc(conversationId)
          .collection('messages');

  CollectionReference<Map<String, dynamic>> _participantsRef(
          String conversationId) =>
      _conversationCollection
          .doc(conversationId)
          .collection('participants');

  /// Tạo hoặc lấy conversation 1-1 dựa trên hai UID
  Future<String> createOrGetDirectConversation({
    required String currentUid,
    required String otherUid,
  }) async {
    final participants = [currentUid, otherUid]..sort();

    final existing = await _conversationCollection
        .where('type', isEqualTo: 'direct')
        .where('participantHash', isEqualTo: participants.join('_'))
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final doc = await _conversationCollection.add({
      'type': 'direct',
      'participantIds': participants,
      'participantHash': participants.join('_'),
      'createdBy': currentUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
    });

    final batch = _firestore.batch();
    for (final uid in participants) {
      batch.set(_participantsRef(doc.id).doc(uid), {
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
        'lastReadAt': FieldValue.serverTimestamp(),
        'notificationsEnabled': true,
      });
    }
    await batch.commit();

    return doc.id;
  }

  /// Tạo conversation nhóm
  Future<String> createGroupConversation({
    required String ownerUid,
    required List<String> memberIds,
    required String name,
    String? avatarUrl,
  }) async {
    final participants = <String>{ownerUid, ...memberIds}.toList()..sort();

    final doc = await _conversationCollection.add({
      'type': 'group',
      'participantIds': participants,
      'createdBy': ownerUid,
      'name': name,
      'avatarUrl': avatarUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
    });

    final batch = _firestore.batch();
    batch.set(_participantsRef(doc.id).doc(ownerUid), {
      'role': 'admin',
      'joinedAt': FieldValue.serverTimestamp(),
      'lastReadAt': FieldValue.serverTimestamp(),
      'notificationsEnabled': true,
    });
    for (final uid in participants.where((e) => e != ownerUid)) {
      batch.set(_participantsRef(doc.id).doc(uid), {
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
        'lastReadAt': FieldValue.serverTimestamp(),
        'notificationsEnabled': true,
      });
    }
    await batch.commit();

    return doc.id;
  }

  Stream<List<ConversationSummary>> watchConversations(String uid) {
    return _conversationCollection
        .where('participantIds', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(ConversationSummary.fromDoc).toList());
  }

  Stream<List<ChatMessage>> watchMessages(
    String conversationId, {
    int limit = 50,
  }) {
    return _messagesRef(conversationId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map(ChatMessage.fromDoc)
            .toList()
            .reversed
            .toList());
  }

  Future<void> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String text,
    List<MessageAttachment> attachments = const [],
  }) async {
    final now = DateTime.now();
    final messageRef = _messagesRef(conversationId).doc();

    final message = ChatMessage(
      id: messageRef.id,
      senderId: senderId,
      type: attachments.isEmpty ? 'text' : 'media',
      text: text,
      createdAt: now,
      attachments: attachments,
      seenBy: [senderId],
    );

    // Lấy conversation để lấy participantIds
    final conversationDoc = await _conversationCollection.doc(conversationId).get();
    final participantIds = (conversationDoc.data()?['participantIds'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    
    final batch = _firestore.batch();
    batch.set(messageRef, message.toMap());
    batch.set(
      _conversationCollection.doc(conversationId),
      {
        'lastMessage': {
          'text': text.isNotEmpty ? text : (attachments.isNotEmpty ? '[media]' : ''),
          'senderId': senderId,
          'createdAt': Timestamp.fromDate(now),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    
    // Tạo notification cho các participants khác (không phải sender)
    for (final participantId in participantIds) {
      if (participantId != senderId) {
        _notificationService.createMessageNotification(
          conversationId: conversationId,
          senderUid: senderId,
          receiverUid: participantId,
          messageText: text.isNotEmpty ? text : (attachments.isNotEmpty ? '[media]' : null),
        ).catchError((e) => debugPrint('Error creating message notification: $e'));
      }
    }
  }

  /// Gửi tin nhắn có hình ảnh
  Future<void> sendImageMessage({
    required String conversationId,
    required String senderId,
    required List<MessageAttachment> attachments,
    String? text,
  }) async {
    await sendTextMessage(
      conversationId: conversationId,
      senderId: senderId,
      text: text ?? '',
      attachments: attachments,
    );
  }

  /// Thêm/xóa reaction cho một tin nhắn
  Future<void> toggleReaction({
    required String conversationId,
    required String messageId,
    required String uid,
    required String emoji,
  }) async {
    final messageRef = _messagesRef(conversationId).doc(messageId);

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(messageRef);
      if (!snap.exists) return;
      final data = snap.data() ?? {};

      final rawReactions =
          (data['reactions'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      // Sao chép map để tránh mutate trực tiếp
      final Map<String, List<String>> reactions = {};
      rawReactions.forEach((key, value) {
        reactions[key] =
            (value as List<dynamic>? ?? []).map((e) => e.toString()).toList();
      });

      final current = reactions[emoji] ?? <String>[];
      final hasReacted = current.contains(uid);
      final updated = List<String>.from(current);

      if (hasReacted) {
        updated.remove(uid);
      } else {
        updated.add(uid);
      }

      if (updated.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = updated;
      }

      txn.update(messageRef, {
        'reactions': reactions,
      });
    });
  }

  Future<void> markConversationAsRead({
    required String conversationId,
    required String uid,
    int limit = 50,
  }) async {
    final participantDoc = _participantsRef(conversationId).doc(uid);
    final recentMessages = await _messagesRef(conversationId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    final batch = _firestore.batch();
    batch.set(participantDoc, {
      'lastReadAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    for (final doc in recentMessages.docs) {
      final seenBy = (doc.data()['seenBy'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      if (!seenBy.contains(uid)) {
        batch.update(doc.reference, {
          'seenBy': FieldValue.arrayUnion([uid]),
        });
      }
    }
    await batch.commit();
  }

  Future<void> setTyping({
    required String uid,
    required String conversationId,
    required bool isTyping,
  }) async {
    await _firestore.collection('user_profiles').doc(uid).set({
      'typingIn': isTyping
          ? FieldValue.arrayUnion([conversationId])
          : FieldValue.arrayRemove([conversationId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Tìm kiếm tin nhắn trong conversation
  Future<List<ChatMessage>> searchMessages({
    required String conversationId,
    required String searchTerm,
    int limit = 200,
  }) async {
    if (searchTerm.trim().isEmpty) {
      return [];
    }
    
    final query = _messagesRef(conversationId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    
    final snapshot = await query.get();
    final allMessages = snapshot.docs
        .map(ChatMessage.fromDoc)
        .toList()
        .reversed
        .toList();
    
    // Filter messages by text (case-insensitive)
    final lowerSearchTerm = searchTerm.toLowerCase();
    return allMessages.where((message) {
      final text = message.text?.toLowerCase() ?? '';
      return text.contains(lowerSearchTerm);
    }).toList();
  }
}

