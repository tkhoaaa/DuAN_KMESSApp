import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/post_service.dart';

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _sending = true;
    });
    try {
      await _postService.addComment(
        postId: widget.post.id,
        text: text,
      );
      _controller.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi gửi bình luận: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
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
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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
                    if (comments.isEmpty) {
                      return const Center(
                        child: Text('Chưa có bình luận.'),
                      );
                    }
                    return ListView.builder(
                      controller: controller,
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final entry = comments[index];
                        final author = entry.author;
                        final title = author?.displayName?.isNotEmpty == true
                            ? author!.displayName!
                            : (author?.email ?? entry.comment.authorUid);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: author?.photoUrl != null
                                ? NetworkImage(author!.photoUrl!)
                                : null,
                            child: author?.photoUrl == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(title),
                          subtitle: Text(entry.comment.text),
                          trailing: entry.comment.createdAt != null
                              ? Text(
                                  entry.comment.createdAt!
                                      .toLocal()
                                      .toString(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall,
                                )
                              : null,
                        );
                      },
                    );
                  },
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

