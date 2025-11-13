import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post.dart';
import '../models/post_comment.dart';

class PostPageResult {
  PostPageResult({
    required this.docs,
    required this.lastDoc,
    required this.hasMore,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
}

class PostRepository {
  PostRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('posts');

  CollectionReference<Map<String, dynamic>> _postLikes(String postId) =>
      _posts.doc(postId).collection('likes');

  CollectionReference<Map<String, dynamic>> _postComments(String postId) =>
      _posts.doc(postId).collection('comments');

  Future<String> createPost({
    required String authorUid,
    required List<Map<String, dynamic>> media,
    String? caption,
  }) async {
    final doc = _posts.doc();
    await doc.set({
      'authorUid': authorUid,
      'media': media,
      'caption': caption ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'likeCount': 0,
      'commentCount': 0,
    });

    await _firestore.collection('user_profiles').doc(authorUid).set({
      'postsCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return doc.id;
  }

  Future<PostPageResult> fetchPosts({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 10,
  }) async {
    Query<Map<String, dynamic>> query =
        _posts.orderBy('createdAt', descending: true).limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snap = await query.get();
    final docs = snap.docs;
    return PostPageResult(
      docs: docs,
      lastDoc: docs.isNotEmpty ? docs.last : startAfter,
      hasMore: docs.length == limit,
    );
  }

  Future<bool> hasUserLikedPost({
    required String postId,
    required String uid,
  }) async {
    final doc = await _postLikes(postId).doc(uid).get();
    return doc.exists;
  }

  Stream<Post> watchPost(String postId) {
    return _posts
        .doc(postId)
        .snapshots()
        .where((snap) => snap.exists)
        .map(Post.fromDoc);
  }

  Stream<bool> watchUserLike({
    required String postId,
    required String uid,
  }) {
    return _postLikes(postId)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> likePost({
    required String postId,
    required String uid,
  }) async {
    final postRef = _posts.doc(postId);
    final likeRef = _postLikes(postId).doc(uid);

    await _firestore.runTransaction((txn) async {
      final likeSnap = await txn.get(likeRef);
      if (likeSnap.exists) return;
      txn.set(likeRef, {
        'likedAt': FieldValue.serverTimestamp(),
      });
      txn.update(postRef, {
        'likeCount': FieldValue.increment(1),
      });
    });
  }

  Future<void> unlikePost({
    required String postId,
    required String uid,
  }) async {
    final postRef = _posts.doc(postId);
    final likeRef = _postLikes(postId).doc(uid);

    await _firestore.runTransaction((txn) async {
      final likeSnap = await txn.get(likeRef);
      if (!likeSnap.exists) return;
      txn.delete(likeRef);
      txn.update(postRef, {
        'likeCount': FieldValue.increment(-1),
      });
    });
  }

  Stream<List<PostComment>> watchComments(String postId) {
    return _postComments(postId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(PostComment.fromDoc).toList());
  }

  Future<void> addComment({
    required String postId,
    required String authorUid,
    required String text,
  }) async {
    final postRef = _posts.doc(postId);
    final commentsRef = _postComments(postId);

    await _firestore.runTransaction((txn) async {
      final newCommentRef = commentsRef.doc();
      txn.set(newCommentRef, {
        'authorUid': authorUid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      txn.update(postRef, {
        'commentCount': FieldValue.increment(1),
      });
    });
  }
}

