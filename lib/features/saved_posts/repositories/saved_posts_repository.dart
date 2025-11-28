import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/saved_post.dart';

class SavedPostsRepository {
  SavedPostsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('saved_posts').doc(uid).collection('items');
  }

  DocumentReference<Map<String, dynamic>> _doc({
    required String uid,
    required String postId,
  }) {
    return _collection(uid).doc(postId);
  }

  Query<Map<String, dynamic>> _orderedQuery(String uid) {
    return _collection(uid).orderBy('savedAt', descending: true);
  }

  Stream<List<SavedPost>> watchSavedPosts({
    required String uid,
    int limit = 50,
  }) {
    if (uid.isEmpty) return const Stream<List<SavedPost>>.empty();
    return _orderedQuery(uid)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(SavedPost.fromDoc).toList());
  }

  Stream<bool> watchIsSaved({
    required String uid,
    required String postId,
  }) {
    if (uid.isEmpty || postId.isEmpty) {
      return const Stream<bool>.empty();
    }
    return _doc(uid: uid, postId: postId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<bool> isSaved({
    required String uid,
    required String postId,
  }) async {
    if (uid.isEmpty || postId.isEmpty) return false;
    final snap = await _doc(uid: uid, postId: postId).get();
    return snap.exists;
  }

  Future<void> savePost({
    required String uid,
    required String postId,
    String? postOwnerUid,
    String? postUrl,
  }) async {
    if (uid.isEmpty || postId.isEmpty) return;
    final data = <String, dynamic>{
      'postId': postId,
      'savedAt': FieldValue.serverTimestamp(),
      if (postOwnerUid != null) 'postOwnerUid': postOwnerUid,
      if (postUrl != null && postUrl.isNotEmpty) 'postUrl': postUrl,
    };
    await _doc(uid: uid, postId: postId).set(data);
  }

  Future<void> unsavePost({
    required String uid,
    required String postId,
  }) async {
    if (uid.isEmpty || postId.isEmpty) return;
    await _doc(uid: uid, postId: postId).delete();
  }

  Future<List<SavedPost>> fetchSavedPosts({
    required String uid,
    int limit = 20,
  }) async {
    if (uid.isEmpty) return [];
    final snapshot = await _orderedQuery(uid).limit(limit).get();
    return snapshot.docs.map(SavedPost.fromDoc).toList();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> fetchSavedPostsPage({
    required String uid,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) {
    Query<Map<String, dynamic>> query = _orderedQuery(uid).limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }
}

