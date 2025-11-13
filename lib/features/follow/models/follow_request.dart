import 'package:cloud_firestore/cloud_firestore.dart';

class FollowRequest {
  FollowRequest({
    required this.followerUid,
    required this.targetUid,
    required this.createdAt,
  });

  final String followerUid;
  final String targetUid;
  final DateTime? createdAt;

  factory FollowRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final targetUid = doc.reference.parent.parent?.id ?? '';
    return FollowRequest(
      followerUid: doc.id,
      targetUid: targetUid,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory FollowRequest.fromCollectionGroupDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final targetUid = doc.reference.parent.parent?.id ?? '';
    return FollowRequest(
      followerUid: data['fromUid'] as String? ?? '',
      targetUid: targetUid,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

