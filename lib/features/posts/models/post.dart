import 'package:cloud_firestore/cloud_firestore.dart';

import 'post_media.dart';

enum PostStatus {
  draft,
  scheduled,
  published,
  cancelled,
}

class Post {
  Post({
    required this.id,
    required this.authorUid,
    required this.media,
    required this.caption,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    this.hashtags = const [],
    this.scheduledAt,
    this.status = PostStatus.published,
  });

  final String id;
  final String authorUid;
  final List<PostMedia> media;
  final String caption;
  final DateTime? createdAt;
  final int likeCount;
  final int commentCount;
  final List<String> hashtags;
  final DateTime? scheduledAt;
  final PostStatus status;

  factory Post.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final mediaList = (data['media'] as List<dynamic>? ?? [])
        .map((item) => PostMedia.fromMap(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
    if (mediaList.isEmpty) {
      final legacyUrl = data['mediaUrl'] as String?;
      if (legacyUrl != null && legacyUrl.isNotEmpty) {
        mediaList.add(PostMedia(url: legacyUrl, type: PostMediaType.image));
      }
    }
    final hashtagsList = (data['hashtags'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
    
    // Parse status với default là published
    final statusStr = data['status'] as String? ?? 'published';
    final status = PostStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => PostStatus.published,
    );
    
    return Post(
      id: doc.id,
      authorUid: data['authorUid'] as String? ?? '',
      media: mediaList,
      caption: data['caption'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      hashtags: hashtagsList,
      scheduledAt: (data['scheduledAt'] as Timestamp?)?.toDate(),
      status: status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorUid': authorUid,
      'media': media.map((m) => m.toMap()).toList(),
      'caption': caption,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'hashtags': hashtags,
      if (scheduledAt != null) 'scheduledAt': Timestamp.fromDate(scheduledAt!),
      'status': status.name,
    };
  }
}

