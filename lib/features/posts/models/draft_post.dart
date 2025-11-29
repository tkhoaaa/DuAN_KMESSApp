import 'package:cloud_firestore/cloud_firestore.dart';

import 'post_media.dart';

class DraftPost {
  DraftPost({
    required this.id,
    required this.uid,
    this.media = const [],
    this.caption,
    this.hashtags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String uid;
  final List<PostMedia> media;
  final String? caption;
  final List<String> hashtags;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory DraftPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final mediaList = (data['media'] as List<dynamic>? ?? [])
        .map((item) => PostMedia.fromMap(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
    final hashtagsList = (data['hashtags'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();

    return DraftPost(
      id: doc.id,
      uid: doc.reference.parent.parent?.id ?? '',
      media: mediaList,
      caption: data['caption'] as String?,
      hashtags: hashtagsList,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'media': media.map((m) => m.toMap()).toList(),
      if (caption != null) 'caption': caption,
      'hashtags': hashtags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

