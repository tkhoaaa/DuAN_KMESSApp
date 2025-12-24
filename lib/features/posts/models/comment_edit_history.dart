import 'package:cloud_firestore/cloud_firestore.dart';

class CommentEditHistory {
  CommentEditHistory({
    required this.id,
    required this.oldText,
    required this.newText,
    required this.editedBy,
    required this.editedAt,
  });

  final String id;
  final String oldText;
  final String newText;
  final String editedBy;
  final DateTime? editedAt;

  factory CommentEditHistory.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return CommentEditHistory(
      id: doc.id,
      oldText: data['oldText'] as String? ?? '',
      newText: data['newText'] as String? ?? '',
      editedBy: data['editedBy'] as String? ?? '',
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
    );
  }
}

