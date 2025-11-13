import 'package:cloud_firestore/cloud_firestore.dart';

class PostComment {
  PostComment({
    required this.id,
    required this.authorUid,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String authorUid;
  final String text;
  final DateTime? createdAt;

  factory PostComment.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return PostComment(
      id: doc.id,
      authorUid: data['authorUid'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

