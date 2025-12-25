import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import 'edit_history_sheet.dart';
import 'package:intl/intl.dart';
import '../../../theme/colors.dart';

class PostCommentsSheet extends StatefulWidget {
  const PostCommentsSheet({
    super.key,
    required this.post,
  });

  final Post post;

  @override
  State<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<PostCommentsSheet>
    with SingleTickerProviderStateMixin {
  final PostService _postService = PostService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _sending = false;
  PostCommentEntry? _replyingTo;
  final Map<String, String?> _localReactions = {};
  // Lưu trữ reaction counts đã được cập nhật locally để UI phản hồi ngay
  final Map<String, Map<String, int>> _localReactionCounts = {};
  bool _isKeyboardVisible = false;

  static const List<String> _reactionOptions = ['👍', '❤️', '😂', '😮', '😢'];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _isKeyboardVisible = true;
        });
        // Scroll to bottom when keyboard appears
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        setState(() {
          _isKeyboardVisible = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
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
      builder: (context, dragController) {
        return Material(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          color: Colors.white,
          child: Column(
            children: [
              // Modern drag handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Header with animation
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Bình luận',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey.shade600),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Comments list with proper keyboard handling
              Expanded(
                child: StreamBuilder(
                  stream: _postService.watchComments(widget.post.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPink),
                        ),
                      );
                    }
                    final comments = snapshot.data ?? [];
                    
                    // Sync local reactions with stream data
                    if (snapshot.hasData && comments.isNotEmpty) {
                      for (final entry in comments) {
                        final commentId = entry.comment.id;
                        final localReaction = _localReactions[commentId];
                        if (localReaction != null && entry.userReaction == localReaction) {
                          _localReactionCounts.remove(commentId);
                        }
                      }
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
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.comment_outlined,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chưa có bình luận',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      controller: dragController,
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 8,
                        bottom: _isKeyboardVisible ? 100 : 16,
                      ),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final entry = comments[index];
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 300 + (index * 50)),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
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
                                  ...entry.replies.asMap().entries.map(
                                    (replyEntry) => TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: Duration(
                                        milliseconds: 350 + (replyEntry.key * 30),
                                      ),
                                      curve: Curves.easeOut,
                                      builder: (context, value, child) {
                                        return Opacity(
                                          opacity: value,
                                          child: Transform.translate(
                                            offset: Offset(0, 15 * (1 - value)),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 48,
                                          top: 12,
                                        ),
                                        child: _CommentItem(
                                          entry: replyEntry.value,
                                          userReactionOverride: _localReactions[
                                              replyEntry.value.comment.id],
                                          localReactionCounts: _localReactionCounts[
                                              replyEntry.value.comment.id],
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
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // Reply indicator with animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: _replyingTo != null ? 60 : 0,
                child: _replyingTo != null
                    ? Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPink.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primaryPink.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.reply,
                              size: 18,
                              color: AppColors.primaryPink,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Đang trả lời: ${_displayName(_replyingTo!)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryPink,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _replyingTo = null;
                                  });
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: AppColors.primaryPink,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              // Modern input field with animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom > 0
                      ? MediaQuery.of(context).viewInsets.bottom
                      : MediaQuery.of(context).padding.bottom + 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: _isKeyboardVisible
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ]
                      : [],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 100),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _focusNode.hasFocus
                                  ? AppColors.primaryPink
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendComment(),
                            decoration: InputDecoration(
                              hintText: 'Viết bình luận...',
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: _sending
                            ? Colors.grey.shade300
                            : AppColors.primaryPink,
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          onTap: _sending ? null : _sendComment,
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            child: _sending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                          ),
                        ),
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
        Hero(
          tag: 'avatar_${entry.comment.id}',
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryPink.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundImage:
                  photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              backgroundColor: Colors.grey.shade200,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? Icon(Icons.person, size: 20, color: Colors.grey.shade600)
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  if (timeString.isNotEmpty) ...[
                    Text(
                      timeString,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    if (entry.comment.editedAt != null) ...[
                      const SizedBox(width: 6),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showEditHistory(context),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              '(Đã chỉnh sửa)',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryPink,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (canDelete || canEdit)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
              const SizedBox(height: 6),
              if (isReply && entry.comment.replyToUid != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.reply,
                        size: 12,
                        color: AppColors.primaryPink,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Trả lời',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryPink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Text(
                entry.comment.text,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: AppColors.textDark,
                ),
              ),
            ),
            if (totalReactions > 0)
              Positioned(
                right: 12,
                bottom: -12,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final emoji in summaryEmojis) ...[
                          Text(emoji, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 2),
                        ],
                        Text(
                          totalReactions.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryPink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
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
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onReply(entry),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    'Trả lời',
                    style: TextStyle(
                      color: AppColors.primaryPink,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 200),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: selected ? 1.1 : scale,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primaryPink.withValues(alpha: 0.15)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? AppColors.primaryPink
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 16),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: selected ? AppColors.primaryPink : AppColors.textDark,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

