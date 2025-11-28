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

  Stream<ParticipantNotificationSettings>
      watchParticipantNotificationSettings({
    required String conversationId,
    required String uid,
  }) {
    return _participantsRef(conversationId)
        .doc(uid)
        .snapshots()
        .map(ParticipantNotificationSettings.fromSnapshot);
  }

  Future<ParticipantNotificationSettings>
      fetchParticipantNotificationSettings({
    required String conversationId,
    required String uid,
  }) async {
    final snap = await _participantsRef(conversationId).doc(uid).get();
    return ParticipantNotificationSettings.fromSnapshot(snap);
  }

  Future<void> updateParticipantNotificationSettings({
    required String conversationId,
    required String uid,
    bool? notificationsEnabled,
    DateTime? mutedUntil,
    bool clearMutedUntil = false,
  }) async {
    final data = <String, dynamic>{};
    if (notificationsEnabled != null) {
      data['notificationsEnabled'] = notificationsEnabled;
    }
    if (mutedUntil != null) {
      data['mutedUntil'] = Timestamp.fromDate(mutedUntil);
    } else if (clearMutedUntil) {
      data['mutedUntil'] = FieldValue.delete();
    }
    if (data.isEmpty) return;
    await _participantsRef(conversationId)
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  Future<void> ensureParticipantEntry({
    required String conversationId,
    required String uid,
    String role = 'member',
  }) async {
    final participantDoc = _participantsRef(conversationId).doc(uid);
    final snapshot = await participantDoc.get();
    if (snapshot.exists) return;

    await participantDoc.set({
      'role': role,
      'joinedAt': FieldValue.serverTimestamp(),
      'lastReadAt': FieldValue.serverTimestamp(),
      'notificationsEnabled': true,
    }, SetOptions(merge: true));
  }

  /// Tạo hoặc lấy conversation 1-1 dựa trên hai UID
  Future<String> createOrGetDirectConversation({
    required String currentUid,
    required String otherUid,
  }) async {
    final participants = [currentUid, otherUid]..sort();

    final accessibleConversations = await _conversationCollection
        .where('participantIds', arrayContains: currentUid)
        .get();

    QueryDocumentSnapshot<Map<String, dynamic>>? existing;
    for (final doc in accessibleConversations.docs) {
      final data = doc.data();
      final ids = (data['participantIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      final type = data['type'] as String? ?? 'direct';
      final isTwoMembers = ids.length == 2;
      final matches = type == 'direct' && isTwoMembers && ids.contains(otherUid);
      if (matches) {
        existing = doc;
        break;
      }
    }

    if (existing != null) {
      await ensureParticipantEntry(
        conversationId: existing.id,
        uid: currentUid,
      );
      return existing.id;
    }

    final doc = await _conversationCollection.add({
      'type': 'direct',
      'participantIds': participants,
      'participantHash': participants.join('_'),
      'createdBy': currentUid,
      'admins': [],  // ✅ THÊM FIELD NÀY
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
    });

    await _participantsRef(doc.id).doc(currentUid).set({
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
      'lastReadAt': FieldValue.serverTimestamp(),
      'notificationsEnabled': true,
    }, SetOptions(merge: true));

    return doc.id;
  }

  /// Tạo conversation nhóm
  Future<String> createGroupConversation({
    required String ownerUid,
    required List<String> memberIds,
    required String name,
    String? avatarUrl,
    String? description,
  }) async {
    final participants = <String>{ownerUid, ...memberIds}.toList()..sort();

    final doc = await _conversationCollection.add({
      'type': 'group',
      'participantIds': participants,
      'createdBy': ownerUid,
      'name': name,
      'avatarUrl': avatarUrl,
      'description': description,
      'admins': [ownerUid],
      'membersCount': participants.length,
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

  /// Thêm thành viên mới vào group (chỉ admin được phép)
  Future<void> addMembersToGroup({
    required String conversationId,
    required String requesterId,
    required List<String> newMemberIds,
  }) async {
    if (newMemberIds.isEmpty) return;

    await _firestore.runTransaction((txn) async {
      final convRef = _conversationCollection.doc(conversationId);
      final convSnap = await txn.get(convRef);
      if (!convSnap.exists) return;
      final data = convSnap.data() ?? {};

      if (data['type'] != 'group') return;

      final admins = (data['admins'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      if (!admins.contains(requesterId)) {
        throw StateError('Bạn không có quyền thêm thành viên.');
      }

      final participants = (data['participantIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toSet();

      final toAdd =
          newMemberIds.where((id) => !participants.contains(id)).toList();
      if (toAdd.isEmpty) return;

      for (final uid in toAdd) {
        txn.set(_participantsRef(conversationId).doc(uid), {
          'role': 'member',
          'joinedAt': FieldValue.serverTimestamp(),
          'lastReadAt': FieldValue.serverTimestamp(),
          'notificationsEnabled': true,
        }, SetOptions(merge: true));
        participants.add(uid);
      }

      txn.update(convRef, {
        'participantIds': participants.toList()..sort(),
        'membersCount': participants.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Xóa một thành viên khỏi group (chỉ admin được phép, không dùng cho chính mình)
  Future<void> removeMemberFromGroup({
    required String conversationId,
    required String requesterId,
    required String targetUid,
  }) async {
    await _firestore.runTransaction((txn) async {
      final convRef = _conversationCollection.doc(conversationId);
      final convSnap = await txn.get(convRef);
      if (!convSnap.exists) return;
      final data = convSnap.data() ?? {};

      if (data['type'] != 'group') return;

      if (targetUid == requesterId) {
        // Với trường hợp tự rời nhóm, dùng [leaveGroup]
        return;
      }

      final admins = (data['admins'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      if (!admins.contains(requesterId)) {
        throw StateError('Bạn không có quyền xóa thành viên.');
      }

      final participants = (data['participantIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toSet();
      if (!participants.contains(targetUid)) {
        return;
      }

      participants.remove(targetUid);

      // Nếu targetUid là admin thì xóa khỏi danh sách admins
      admins.remove(targetUid);

      txn.delete(_participantsRef(conversationId).doc(targetUid));
      txn.update(convRef, {
        'participantIds': participants.toList()..sort(),
        'admins': admins,
        'membersCount': participants.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Thành viên rời group.
  /// Nếu là admin cuối cùng thì tự động chuyển quyền admin cho một thành viên khác (nếu còn).
  Future<void> leaveGroup({
    required String conversationId,
    required String uid,
  }) async {
    await _firestore.runTransaction((txn) async {
      final convRef = _conversationCollection.doc(conversationId);
      final convSnap = await txn.get(convRef);
      if (!convSnap.exists) return;
      final data = convSnap.data() ?? {};

      if (data['type'] != 'group') return;

      final participants = (data['participantIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toSet();
      if (!participants.contains(uid)) return;

      final admins = (data['admins'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();

      participants.remove(uid);
      var adminList = admins.toList();

      final isAdmin = adminList.contains(uid);
      if (isAdmin) {
        adminList.remove(uid);
        // Nếu không còn admin nào nhưng vẫn còn thành viên -> đặt một thành viên khác làm admin
        if (adminList.isEmpty && participants.isNotEmpty) {
          final newAdmin = participants.first;
          adminList.add(newAdmin);
          txn.set(_participantsRef(conversationId).doc(newAdmin), {
            'role': 'admin',
          }, SetOptions(merge: true));
        }
      }

      txn.delete(_participantsRef(conversationId).doc(uid));
      txn.update(convRef, {
        'participantIds': participants.toList()..sort(),
        'admins': adminList,
        'membersCount': participants.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Cập nhật thông tin nhóm (tên, avatar, mô tả) - chỉ admin được phép.
  Future<void> updateGroupInfo({
    required String conversationId,
    required String requesterId,
    String? name,
    String? avatarUrl,
    String? description,
  }) async {
    if (name == null && avatarUrl == null && description == null) {
      return;
    }

    await _firestore.runTransaction((txn) async {
      final convRef = _conversationCollection.doc(conversationId);
      final convSnap = await txn.get(convRef);
      if (!convSnap.exists) return;
      final data = convSnap.data() ?? {};

      if (data['type'] != 'group') return;

      final admins = (data['admins'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      if (!admins.contains(requesterId)) {
        throw StateError('Bạn không có quyền chỉnh sửa thông tin nhóm.');
      }

      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;
      if (description != null) updates['description'] = description;
      updates['updatedAt'] = FieldValue.serverTimestamp();

      txn.update(convRef, updates);
    });
  }

  /// Thêm hoặc gỡ quyền admin cho một thành viên (chỉ admin khác được phép).
  Future<void> setAdminForMember({
    required String conversationId,
    required String requesterId,
    required String targetUid,
    required bool isAdmin,
  }) async {
    await _firestore.runTransaction((txn) async {
      final convRef = _conversationCollection.doc(conversationId);
      final convSnap = await txn.get(convRef);
      if (!convSnap.exists) return;
      final data = convSnap.data() ?? {};

      if (data['type'] != 'group') return;

      final admins = (data['admins'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();

      if (!admins.contains(requesterId)) {
        throw StateError('Bạn không có quyền thay đổi quyền admin.');
      }

      final participants = (data['participantIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toSet();
      if (!participants.contains(targetUid)) {
        return;
      }

      var adminList = admins.toList();
      if (isAdmin) {
        if (!adminList.contains(targetUid)) {
          adminList.add(targetUid);
        }
        txn.set(_participantsRef(conversationId).doc(targetUid), {
          'role': 'admin',
        }, SetOptions(merge: true));
      } else {
        adminList.remove(targetUid);
        // Đảm bảo luôn còn ít nhất một admin
        if (adminList.isEmpty && participants.isNotEmpty) {
          final newAdmin = participants.first;
          adminList.add(newAdmin);
          txn.set(_participantsRef(conversationId).doc(newAdmin), {
            'role': 'admin',
          }, SetOptions(merge: true));
        }
        txn.set(_participantsRef(conversationId).doc(targetUid), {
          'role': 'member',
        }, SetOptions(merge: true));
      }

      txn.update(convRef, {
        'admins': adminList,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
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
      if (participantId == senderId) continue;
      final shouldNotify = await _shouldSendNotification(
        conversationId: conversationId,
        receiverUid: participantId,
        referenceTime: now,
      );
      if (!shouldNotify) continue;
      _notificationService
          .createMessageNotification(
        conversationId: conversationId,
        senderUid: senderId,
        receiverUid: participantId,
        messageText:
            text.isNotEmpty ? text : (attachments.isNotEmpty ? '[media]' : null),
      )
          .catchError(
              (e) => debugPrint('Error creating message notification: $e'));
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

  /// Gửi voice message (sử dụng attachments với type = 'voice')
  Future<void> sendVoiceMessage({
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

  /// Gửi video message (sử dụng attachments với type = 'video_message')
  Future<void> sendVideoMessage({
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

  Future<bool> _shouldSendNotification({
    required String conversationId,
    required String receiverUid,
    required DateTime referenceTime,
  }) async {
    try {
      final settings = await fetchParticipantNotificationSettings(
        conversationId: conversationId,
        uid: receiverUid,
      );
      if (!settings.notificationsEnabled) return false;
      if (settings.mutedUntil != null &&
          settings.mutedUntil!.isAfter(referenceTime)) {
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Warning: cannot determine mute state ($e), defaulting to notify');
      return true;
    }
  }
}

class ParticipantNotificationSettings {
  const ParticipantNotificationSettings({
    required this.notificationsEnabled,
    this.mutedUntil,
  });

  final bool notificationsEnabled;
  final DateTime? mutedUntil;

  bool isMutedAt(DateTime reference) {
    if (!notificationsEnabled) return true;
    if (mutedUntil == null) return false;
    return mutedUntil!.isAfter(reference);
  }

  static ParticipantNotificationSettings fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>>? snapshot,
  ) {
    final data = snapshot?.data();
    final timestamp = data?['mutedUntil'];
    DateTime? muted;
    if (timestamp is Timestamp) {
      muted = timestamp.toDate();
    }
    return ParticipantNotificationSettings(
      notificationsEnabled: (data?['notificationsEnabled'] as bool?) ?? true,
      mutedUntil: muted,
    );
  }
}

