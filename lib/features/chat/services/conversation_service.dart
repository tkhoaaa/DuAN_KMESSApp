
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

    final settings = await _chatRepository.fetchParticipantNotificationSettings(
      conversationId: summary.id,
      uid: currentUid,
    );

    return ConversationEntry(
      summary: summary,
      title: title,
      avatarUrl: avatarUrl,
      subtitle: subtitle,
      notificationsEnabled: settings.notificationsEnabled,
      mutedUntil: settings.mutedUntil,
      unreadCount: settings.unreadCount,
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
    required this.notificationsEnabled,
    this.unreadCount = 0,
    this.avatarUrl,
    this.subtitle,
    this.mutedUntil,
  });

  final ConversationSummary summary;
  final String title;
  final String? avatarUrl;
  final String? subtitle;
  final bool notificationsEnabled;
  final DateTime? mutedUntil;
  final int unreadCount;

  DateTime? get lastMessageAt => summary.lastMessageAt;

  bool get isMuted {
    if (!notificationsEnabled) return true;
    if (mutedUntil == null) return false;
    return mutedUntil!.isAfter(DateTime.now());
  }

  String? muteDescription() {
    if (!isMuted) return null;
    if (!notificationsEnabled) {
      return 'Đã tắt thông báo';
    }
    if (mutedUntil != null) {
      return 'Tắt thông báo đến ${_formatMuteUntil(mutedUntil!)}';
    }
    return 'Đã tắt thông báo';
  }

  static String _formatMuteUntil(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute $day/$month';
  }
}

