import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import 'edit_history_sheet.dart';
import 'package:intl/intl.dart';

class PostCommentsSheet extends StatefulWidget {
  const PostCommentsSheet({
    super.key,
    required this.post,
  });

  final Post post;

  @override
  State<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<PostCommentsSheet> {
  final PostService _postService = PostService();
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;
  PostCommentEntry? _replyingTo;
  final Map<String, String?> _localReactions = {};
  // Lưu trữ reaction counts đã được cập nhật locally để UI phản hồi ngay
  final Map<String, Map<String, int>> _localReactionCounts = {};

  static const List<String> _reactionOptions = ['👍', '❤️', '😂', '😮', '😢'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Nếu đang trả lời một reply, ta luôn gắn parentId về comment gốc
    // để danh sách hiển thị 2 cấp: comment gốc + các reply trực tiếp.
    String? parentCommentId;
    if (_replyingTo != null) {
      final replyingComment = _replyingTo!.comment;
      parentCommentId =
          (replyingComment.parentId != null && replyingComment.parentId!.isNotEmpty)
              ? replyingComment.parentId
              : replyingComment.id;
    }

    // Optimistic update: Clear text field ngay lập tức để UX tốt hơn
    final commentText = text;
    _controller.clear();
    final replyingTo = _replyingTo;
    setState(() {
      _sending = true;
      _replyingTo = null;
    });

    try {
      // Gửi comment (không await notification để tăng tốc)
      await _postService.addComment(
        postId: widget.post.id,
        text: commentText,
        parentCommentId: parentCommentId,
        replyToUid: replyingTo?.comment.authorUid,
      );
    } catch (e) {
      // Nếu lỗi, khôi phục lại text
      if (mounted) {
        _controller.text = commentText;
        setState(() {
          _replyingTo = replyingTo;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi bình luận: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _toggleReaction(PostCommentEntry entry, String reaction) async {
    try {
      final commentId = entry.comment.id;
      final current = _localReactions[commentId] ?? entry.userReaction;
      final newReaction = current == reaction ? null : reaction;
      
      // Cập nhật local state ngay lập tức để UI phản hồi ngay
      // Lưu ý: local counts chỉ là delta (thay đổi), không phải tổng số
      // Stream data sẽ có tổng số đầy đủ từ tất cả users
      setState(() {
        _localReactions[commentId] = newReaction;
        
        // Lấy reactionCounts từ stream (có đầy đủ data từ tất cả users)
        final baseCounts = Map<String, int>.from(entry.comment.reactionCounts);
        
        // Áp dụng delta từ local changes (nếu có)
        final localDelta = _localReactionCounts[commentId];
        if (localDelta != null) {
          for (final entry in localDelta.entries) {
            baseCounts[entry.key] = (baseCounts[entry.key] ?? 0) + entry.value;
          }
        }
        
        // Tính toán delta mới cho reaction này
        final delta = <String, int>{};
        
        // Giảm count của reaction cũ (nếu có)
        if (current != null && current != newReaction) {
          delta[current] = (delta[current] ?? 0) - 1;
        }
        
        // Tăng count của reaction mới (nếu có)
        if (newReaction != null) {
          delta[newReaction] = (delta[newReaction] ?? 0) + 1;
        }
        
        // Merge delta mới với delta cũ
        if (localDelta != null) {
          for (final entry in delta.entries) {
            localDelta[entry.key] = (localDelta[entry.key] ?? 0) + entry.value;
            if (localDelta[entry.key] == 0) {
              localDelta.remove(entry.key);
            }
          }
          _localReactionCounts[commentId] = localDelta;
        } else if (delta.isNotEmpty) {
          _localReactionCounts[commentId] = delta;
        }
      });
      
      // Cập nhật trên Firestore (stream sẽ cập nhật lại sau)
      await _postService.setCommentReaction(
        postId: widget.post.id,
        commentId: commentId,
        reaction: newReaction,
      );
    } catch (e) {
      if (!mounted) return;
      // Nếu có lỗi, revert lại local state
      setState(() {
        _localReactions.remove(entry.comment.id);
        _localReactionCounts.remove(entry.comment.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi thả reaction: $e')),
      );
    }
  }

  void _setReplyingTo(PostCommentEntry entry) {
    setState(() {
      _replyingTo = entry;
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  String _displayName(PostCommentEntry entry) {
    final author = entry.author;
    if (author?.displayName?.isNotEmpty == true) return author!.displayName!;
    if (author?.email?.isNotEmpty == true) return author!.email!;
    return entry.comment.authorUid;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) {
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
                'Bình luận',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: StreamBuilder(
                  stream: _postService.watchComments(widget.post.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    final comments = snapshot.data ?? [];
                    
                    // Khi stream emit data mới từ Firestore, nó đã có tất cả reactions từ tất cả users
                    // Local counts chỉ là delta (thay đổi) để hiển thị ngay lập tức
                    // Khi stream emit data mới, nếu userReaction trong stream khớp với localReactions,
                    // nghĩa là local delta đã được áp dụng vào Firestore, ta xóa local delta để tránh double counting
                    if (snapshot.hasData && comments.isNotEmpty) {
                      for (final entry in comments) {
                        final commentId = entry.comment.id;
                        final localReaction = _localReactions[commentId];
                        // Nếu stream đã có reaction của user (khớp với local), xóa local delta
                        if (localReaction != null && entry.userReaction == localReaction) {
                          _localReactionCounts.remove(commentId);
                        }
                      }
                      // Xử lý tương tự cho replies
                      for (final entry in comments) {
                        for (final reply in entry.replies) {
                          final commentId = reply.comment.id;
                          final localReaction = _localReactions[commentId];
                          if (localReaction != null && reply.userReaction == localReaction) {
                            _localReactionCounts.remove(commentId);
                          }
                        }
                      }
                    }
                    
                    if (comments.isEmpty) {
                      return const Center(
                        child: Text('Chưa có bình luận.'),
                      );
                    }
                    return ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final entry = comments[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _CommentItem(
                                entry: entry,
                                userReactionOverride:
                                    _localReactions[entry.comment.id],
                                localReactionCounts:
                                    _localReactionCounts[entry.comment.id],
                                onReply: _setReplyingTo,
                                onReact: _toggleReaction,
                                reactionOptions: _reactionOptions,
                                postService: _postService,
                                displayNameBuilder: _displayName,
                                postId: widget.post.id,
                                postAuthorUid: widget.post.authorUid,
                              ),
                              if (entry.replies.isNotEmpty)
                                ...entry.replies.map(
                                  (reply) => Padding(
                                    padding: const EdgeInsets.only(
                                      left: 48,
                                      top: 8,
                                    ),
                                    child: _CommentItem(
                                      entry: reply,
                                      userReactionOverride:
                                          _localReactions[reply.comment.id],
                                      localReactionCounts:
                                          _localReactionCounts[reply.comment.id],
                                      isReply: true,
                                      onReply: _setReplyingTo,
                                      onReact: _toggleReaction,
                                      reactionOptions: _reactionOptions,
                                      postService: _postService,
                                      displayNameBuilder: _displayName,
                                      postId: widget.post.id,
                                      postAuthorUid: widget.post.authorUid,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (_replyingTo != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Đang trả lời: ${_displayName(_replyingTo!)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _replyingTo = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Viết bình luận...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        onPressed: _sending ? null : _sendComment,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommentItem extends StatelessWidget {
  const _CommentItem({
    required this.entry,
    this.userReactionOverride,
    this.localReactionCounts,
    required this.onReply,
    required this.onReact,
    required this.reactionOptions,
    required this.postService,
    required this.displayNameBuilder,
    required this.postId,
    required this.postAuthorUid,
    this.isReply = false,
  });

  final PostCommentEntry entry;
  final String? userReactionOverride;
  final Map<String, int>? localReactionCounts;
  final void Function(PostCommentEntry) onReply;
  final void Function(PostCommentEntry, String) onReact;
  final List<String> reactionOptions;
  final PostService postService;
  final String Function(PostCommentEntry) displayNameBuilder;
  final String postId;
  final String postAuthorUid;
  final bool isReply;

  void _showEditHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => EditHistorySheet(
          postId: postId,
          commentId: entry.comment.id,
          postService: postService,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final author = entry.author;
    final name = displayNameBuilder(entry);
    final photoUrl = author?.photoUrl;
    final currentUid = authRepository.currentUser()?.uid;
    final canDelete = currentUid != null &&
        (currentUid == entry.comment.authorUid || currentUid == postAuthorUid);
    final canEdit = currentUid != null && currentUid == entry.comment.authorUid;

    final timeString = entry.comment.createdAt != null
        ? DateFormat('HH:mm dd/MM')
            .format(entry.comment.createdAt!.toLocal())
        : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundImage:
              photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          child: (photoUrl == null || photoUrl.isEmpty)
              ? const Icon(Icons.person, size: 18)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (timeString.isNotEmpty) ...[
                    Text(
                      timeString,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade600),
                    ),
                    if (entry.comment.editedAt != null) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _showEditHistory(context),
                        child: Text(
                          '(Đã chỉnh sửa)',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Colors.blue,
                                fontStyle: FontStyle.italic,
                                decoration: TextDecoration.underline,
                              ),
                        ),
                      ),
                    ],
                  ],
                  if (canDelete || canEdit)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          final result = await showDialog<String>(
                            context: context,
                            builder: (context) {
                              final controller = TextEditingController(
                                text: entry.comment.text,
                              );
                              return AlertDialog(
                                title: const Text('Chỉnh sửa bình luận'),
                                content: TextField(
                                  controller: controller,
                                  autofocus: true,
                                  maxLines: 5,
                                  decoration: const InputDecoration(
                                    hintText: 'Nhập nội dung bình luận...',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, null),
                                    child: const Text('Hủy'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      final newText = controller.text.trim();
                                      if (newText.isNotEmpty) {
                                        Navigator.pop(context, newText);
                                      }
                                    },
                                    child: const Text('Lưu'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (result != null) {
                            try {
                              await postService.editComment(
                                postId: postId,
                                commentId: entry.comment.id,
                                newText: result,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã chỉnh sửa bình luận'),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Lỗi chỉnh sửa bình luận: $e'),
                                ),
                              );
                            }
                          }
                        } else if (value == 'delete') {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Xóa bình luận'),
                              content: const Text(
                                'Bạn có chắc chắn muốn xóa bình luận này?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Hủy'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            try {
                              await postService.deleteComment(
                                postId: postId,
                                commentId: entry.comment.id,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã xóa bình luận'),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Lỗi xóa bình luận: $e'),
                                ),
                              );
                            }
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        if (canEdit)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: 8),
                                Text('Chỉnh sửa'),
                              ],
                            ),
                          ),
                        if (canDelete)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Xóa bình luận'),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 4),
              if (isReply && entry.comment.replyToUid != null)
                Text(
                  'Trả lời',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              _CommentBubbleWithReactions(
                entry: entry,
                userReactionOverride: userReactionOverride,
                localReactionCounts: localReactionCounts,
                reactionOptions: reactionOptions,
                onReact: onReact,
                onReply: onReply,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Phần nội dung comment + tổng hợp reaction nằm chồng trên bong bóng,
/// giống các app mạng xã hội phổ biến.
class _CommentBubbleWithReactions extends StatelessWidget {
  const _CommentBubbleWithReactions({
    required this.entry,
    required this.userReactionOverride,
    this.localReactionCounts,
    required this.reactionOptions,
    required this.onReact,
    required this.onReply,
  });

  final PostCommentEntry entry;
  final String? userReactionOverride;
  final Map<String, int>? localReactionCounts;
  final List<String> reactionOptions;
  final void Function(PostCommentEntry, String) onReact;
  final void Function(PostCommentEntry) onReply;

  @override
  Widget build(BuildContext context) {
    // Lấy reactionCounts từ stream (có đầy đủ data từ tất cả users)
    final baseCounts = Map<String, int>.from(entry.comment.reactionCounts);
    
    // Áp dụng delta từ local changes (nếu có) để hiển thị ngay lập tức
    // Local counts chỉ là delta (thay đổi), không phải tổng số
    if (localReactionCounts != null && localReactionCounts!.isNotEmpty) {
      for (final entry in localReactionCounts!.entries) {
        baseCounts[entry.key] = (baseCounts[entry.key] ?? 0) + entry.value;
        if (baseCounts[entry.key]! <= 0) {
          baseCounts.remove(entry.key);
        }
      }
    }
    
    final reactionCounts = baseCounts;
    
    // Tính tổng số reaction
    final totalReactions = reactionCounts.values.fold<int>(
      0,
      (prev, element) => prev + element,
    );

    // Lấy ra một vài emoji phổ biến để hiển thị trong pill nhỏ
    final activeReactions = reactionCounts.entries
        .where((e) => (e.value) > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final summaryEmojis = activeReactions
        .map((e) => e.key)
        .take(3)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(entry.comment.text),
            ),
            if (totalReactions > 0)
              Positioned(
                right: 8,
                bottom: -10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final emoji in summaryEmojis) ...[
                        Text(emoji, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 2),
                      ],
                      Text(
                        totalReactions.toString(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Nếu đã có reaction thì chỉ hiển thị các reaction đang active
            if (totalReactions > 0)
              ...activeReactions.map(
                (e) => _ReactionChip(
                  emoji: e.key,
                  count: e.value,
                  selected: (userReactionOverride ?? entry.userReaction) ==
                      e.key,
                  onTap: () => onReact(entry, e.key),
                ),
              )
            else
              // Nếu chưa có reaction nào, hiển thị dãy emoji để user chọn lần đầu
              ...reactionOptions.map(
                (reaction) => _ReactionChip(
                  emoji: reaction,
                  count: reactionCounts[reaction] ?? 0,
                  selected: (userReactionOverride ?? entry.userReaction) ==
                      reaction,
                  onTap: () => onReact(entry, reaction),
                ),
              ),
            TextButton(
              onPressed: () => onReply(entry),
              child: const Text('Trả lời'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.pink.shade50 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.pink.shade200 : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

