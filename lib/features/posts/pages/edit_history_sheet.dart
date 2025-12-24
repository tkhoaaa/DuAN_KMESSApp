import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../profile/user_profile_repository.dart';
import '../models/comment_edit_history.dart';
import '../services/post_service.dart';

class EditHistorySheet extends StatefulWidget {
  const EditHistorySheet({
    required this.postId,
    required this.commentId,
    required this.postService,
    required this.scrollController,
  });

  final String postId;
  final String commentId;
  final PostService postService;
  final ScrollController scrollController;

  @override
  State<EditHistorySheet> createState() => _EditHistorySheetState();
}

class _EditHistorySheetState extends State<EditHistorySheet> {
  final UserProfileRepository _profileRepo = UserProfileRepository();
  final Map<String, UserProfile?> _profileCache = {};

  Future<UserProfile?> _getProfile(String uid) async {
    if (_profileCache.containsKey(uid)) {
      return _profileCache[uid];
    }
    final profile = await _profileRepo.fetchProfile(uid);
    _profileCache[uid] = profile;
    return profile;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lịch sử chỉnh sửa',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: StreamBuilder<List<CommentEditHistory>>(
              stream: widget.postService.getCommentEditHistory(
                postId: widget.postId,
                commentId: widget.commentId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Lỗi: ${snapshot.error}'),
                  );
                }
                final history = snapshot.data ?? [];
                if (history.isEmpty) {
                  return const Center(
                    child: Text('Chưa có lịch sử chỉnh sửa'),
                  );
                }
                return ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[index];
                    return _EditHistoryItem(
                      history: item,
                      getProfile: _getProfile,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EditHistoryItem extends StatelessWidget {
  const _EditHistoryItem({
    required this.history,
    required this.getProfile,
  });

  final CommentEditHistory history;
  final Future<UserProfile?> Function(String) getProfile;

  @override
  Widget build(BuildContext context) {
    final timeString = history.editedAt != null
        ? DateFormat('HH:mm dd/MM/yyyy')
            .format(history.editedAt!.toLocal())
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FutureBuilder<UserProfile?>(
                  future: getProfile(history.editedBy),
                  builder: (context, snapshot) {
                    final profile = snapshot.data;
                    final name = profile?.displayName?.isNotEmpty == true
                        ? profile!.displayName!
                        : (profile?.email?.isNotEmpty == true
                            ? profile!.email!
                            : history.editedBy);
                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: profile?.photoUrl != null
                              ? NetworkImage(profile!.photoUrl!)
                              : null,
                          child: profile?.photoUrl == null
                              ? const Icon(Icons.person, size: 16)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const Spacer(),
                if (timeString.isNotEmpty)
                  Text(
                    timeString,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (history.oldText.isNotEmpty) ...[
              Text(
                'Trước:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  history.oldText,
                  style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Sau:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(history.newText),
            ),
          ],
        ),
      ),
    );
  }
}

