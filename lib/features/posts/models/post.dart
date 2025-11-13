import 'package:cloud_firestore/cloud_firestore.dart';

import 'post_media.dart';

class Post {
  Post({
    required this.id,
    required this.authorUid,
    required this.media,
    required this.caption,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
  });

  final String id;
  final String authorUid;
  final List<PostMedia> media;
  final String caption;
  final DateTime? createdAt;
  final int likeCount;
  final int commentCount;

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
    return Post(
      id: doc.id,
      authorUid: data['authorUid'] as String? ?? '',
      media: mediaList,
      caption: data['caption'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
    );
  }
}

