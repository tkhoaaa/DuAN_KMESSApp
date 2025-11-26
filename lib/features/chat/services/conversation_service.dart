import 'package:cloud_firestore/cloud_firestore.dart';

import '../../profile/user_profile_repository.dart';
import '../models/conversation_summary.dart';
import '../repositories/chat_repository.dart';

class ConversationService {
  ConversationService({
    ChatRepository? chatRepository,
    UserProfileRepository? profileRepository,
  })  : _chatRepository = chatRepository ?? ChatRepository(),
        _profileRepository =
            profileRepository ?? userProfileRepository;

  final ChatRepository _chatRepository;
  final UserProfileRepository _profileRepository;

  Stream<List<ConversationEntry>> watchConversationEntries(
      String uid) {
    return _chatRepository
        .watchConversations(uid)
        .asyncMap((summaries) async {
      final entries = <ConversationEntry>[];
      for (final summary in summaries) {
        entries.add(await _buildEntry(uid, summary));
      }
      return entries;
    });
  }

  Future<ConversationEntry> _buildEntry(
    String currentUid,
    ConversationSummary summary,
  ) async {
    String title = summary.name ?? 'Cuộc trò chuyện';
    String? avatarUrl = summary.avatarUrl;
    String? subtitle;

    if (summary.type == 'direct') {
      final otherUid = summary.participantIds
          .firstWhere((id) => id != currentUid, orElse: () => currentUid);
      final profile = await _profileRepository.fetchProfile(otherUid);
      if (profile != null) {
        title = profile.displayName?.isNotEmpty == true
            ? profile.displayName!
            : (profile.email?.isNotEmpty == true
                ? profile.email!
                : otherUid);
        avatarUrl = profile.photoUrl;
      } else {
        title = otherUid;
      }
    }

    if (summary.lastMessagePreview != null) {
      subtitle = summary.lastMessagePreview;
    }

    return ConversationEntry(
      summary: summary,
      title: title,
      avatarUrl: avatarUrl,
      subtitle: subtitle,
    );
  }

  /// Tạo group conversation mới.
  Future<String> createGroup({
    required String ownerUid,
    required List<String> memberIds,
    required String name,
    String? avatarUrl,
    String? description,
  }) {
    return _chatRepository.createGroupConversation(
      ownerUid: ownerUid,
      memberIds: memberIds,
      name: name,
      avatarUrl: avatarUrl,
      description: description,
    );
  }

  Future<void> addMembers({
    required String conversationId,
    required String requesterId,
    required List<String> newMemberIds,
  }) {
    return _chatRepository.addMembersToGroup(
      conversationId: conversationId,
      requesterId: requesterId,
      newMemberIds: newMemberIds,
    );
  }

  Future<void> removeMember({
    required String conversationId,
    required String requesterId,
    required String targetUid,
  }) {
    return _chatRepository.removeMemberFromGroup(
      conversationId: conversationId,
      requesterId: requesterId,
      targetUid: targetUid,
    );
  }

  Future<void> leaveGroup({
    required String conversationId,
    required String uid,
  }) {
    return _chatRepository.leaveGroup(
      conversationId: conversationId,
      uid: uid,
    );
  }

  Future<void> updateGroupInfo({
    required String conversationId,
    required String requesterId,
    String? name,
    String? avatarUrl,
    String? description,
  }) {
    return _chatRepository.updateGroupInfo(
      conversationId: conversationId,
      requesterId: requesterId,
      name: name,
      avatarUrl: avatarUrl,
      description: description,
    );
  }

  Future<void> setAdmin({
    required String conversationId,
    required String requesterId,
    required String targetUid,
    required bool isAdmin,
  }) {
    return _chatRepository.setAdminForMember(
      conversationId: conversationId,
      requesterId: requesterId,
      targetUid: targetUid,
      isAdmin: isAdmin,
    );
  }
}

class ConversationEntry {
  ConversationEntry({
    required this.summary,
    required this.title,
    this.avatarUrl,
    this.subtitle,
  });

  final ConversationSummary summary;
  final String title;
  final String? avatarUrl;
  final String? subtitle;

  DateTime? get lastMessageAt => summary.lastMessageAt;
}

