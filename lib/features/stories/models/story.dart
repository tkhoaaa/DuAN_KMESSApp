import 'package:cloud_firestore/cloud_firestore.dart';

enum StoryMediaType { image, video }

class Story {
  Story({
    required this.id,
    required this.authorUid,
    required this.mediaUrl,
    required this.type,
    required this.createdAt,
    required this.expiresAt,
    this.thumbnailUrl,
    this.text,
  });

  final String id;
  final String authorUid;
  final String mediaUrl;
  final StoryMediaType type;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? thumbnailUrl;
  final String? text;

  Map<String, dynamic> toMap() {
    return {
      'authorUid': authorUid,
      'mediaUrl': mediaUrl,
      'type': type.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (text != null && text!.isNotEmpty) 'text': text,
    };
  }

  factory Story.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final typeString = data['type'] as String? ?? 'image';
    final type = StoryMediaType.values.firstWhere(
      (e) => e.name == typeString,
      orElse: () => StoryMediaType.image,
    );
    return Story(
      id: doc.id,
      authorUid: data['authorUid'] as String? ?? '',
      mediaUrl: data['mediaUrl'] as String? ?? '',
      type: type,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt:
          (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      thumbnailUrl: data['thumbnailUrl'] as String?,
      text: data['text'] as String?,
    );
  }
}


