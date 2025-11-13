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

