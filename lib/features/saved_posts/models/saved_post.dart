import 'package:cloud_firestore/cloud_firestore.dart';

class SavedPost {
  SavedPost({
    required this.postId,
    this.postOwnerUid,
    this.postUrl,
    required this.savedAt,
  });

  final String postId;
  final String? postOwnerUid;
  final String? postUrl;
  final DateTime savedAt;

  factory SavedPost.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final timestamp = data['savedAt'];
    return SavedPost(
      postId: doc.id,
      postOwnerUid: data['postOwnerUid'] as String?,
      postUrl: data['postUrl'] as String?,
      savedAt: timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      if (postOwnerUid != null) 'postOwnerUid': postOwnerUid,
      if (postUrl != null) 'postUrl': postUrl,
      'savedAt': Timestamp.fromDate(savedAt),
    };
  }
}

