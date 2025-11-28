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
    final captionText = caption ?? '';
    await doc.set({
      'authorUid': authorUid,
      'media': media,
      'caption': captionText,
      'captionLower': captionText.toLowerCase(),
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
    int maxRetries = 3,
  }) async {
    final postRef = _posts.doc(postId);
    final likeRef = _postLikes(postId).doc(uid);

    int retries = 0;
    while (retries <= maxRetries) {
      try {
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
        return; // Thành công, thoát khỏi loop
      } catch (e) {
        if (retries >= maxRetries) {
          rethrow; // Đã hết số lần retry, throw exception
        }
        // Đợi một chút trước khi retry (exponential backoff)
        await Future.delayed(Duration(milliseconds: 500 * (retries + 1)));
        retries++;
      }
    }
  }

  Future<void> unlikePost({
    required String postId,
    required String uid,
    int maxRetries = 3,
  }) async {
    final postRef = _posts.doc(postId);
    final likeRef = _postLikes(postId).doc(uid);

    int retries = 0;
    while (retries <= maxRetries) {
      try {
        await _firestore.runTransaction((txn) async {
          final likeSnap = await txn.get(likeRef);
          if (!likeSnap.exists) return;
          txn.delete(likeRef);
          txn.update(postRef, {
            'likeCount': FieldValue.increment(-1),
          });
        });
        return; // Thành công, thoát khỏi loop
      } catch (e) {
        if (retries >= maxRetries) {
          rethrow; // Đã hết số lần retry, throw exception
        }
        // Đợi một chút trước khi retry (exponential backoff)
        await Future.delayed(Duration(milliseconds: 500 * (retries + 1)));
        retries++;
      }
    }
  }

  Stream<List<PostComment>> watchComments(String postId) {
    return _postComments(postId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(PostComment.fromDoc).toList());
  }

  Future<String> addComment({
    required String postId,
    required String authorUid,
    required String text,
    int maxRetries = 3,
  }) async {
    final postRef = _posts.doc(postId);
    final commentsRef = _postComments(postId);
    String commentId = '';

    int retries = 0;
    while (retries <= maxRetries) {
      try {
        await _firestore.runTransaction((txn) async {
          final newCommentRef = commentsRef.doc();
          commentId = newCommentRef.id;
          txn.set(newCommentRef, {
            'authorUid': authorUid,
            'text': text,
            'createdAt': FieldValue.serverTimestamp(),
          });
          txn.update(postRef, {
            'commentCount': FieldValue.increment(1),
          });
        });
        return commentId; // Thành công, return commentId
      } catch (e) {
        if (retries >= maxRetries) {
          rethrow; // Đã hết số lần retry, throw exception
        }
        // Đợi một chút trước khi retry (exponential backoff)
        await Future.delayed(Duration(milliseconds: 500 * (retries + 1)));
        retries++;
      }
    }
    return commentId; // Không bao giờ đến đây, nhưng để tránh lỗi compile
  }

  Future<void> deleteComment({
    required String postId,
    required String commentId,
    required String currentUid,
  }) async {
    final postRef = _posts.doc(postId);
    final commentRef = _postComments(postId).doc(commentId);
    
    // Lấy thông tin post và comment để kiểm tra quyền
    final postDoc = await postRef.get();
    final commentDoc = await commentRef.get();
    
    if (!postDoc.exists) {
      throw Exception('Post not found');
    }
    if (!commentDoc.exists) {
      throw Exception('Comment not found');
    }
    
    final postData = postDoc.data()!;
    final commentData = commentDoc.data()!;
    final postAuthorUid = postData['authorUid'] as String? ?? '';
    final commentAuthorUid = commentData['authorUid'] as String? ?? '';
    
    // Chỉ cho phép tác giả comment hoặc chủ bài đăng xóa
    if (currentUid != commentAuthorUid && currentUid != postAuthorUid) {
      throw Exception('Not authorized to delete this comment');
    }

    // Xóa comment và giảm commentCount
    await _firestore.runTransaction((txn) async {
      txn.delete(commentRef);
      txn.update(postRef, {
        'commentCount': FieldValue.increment(-1),
      });
    });
  }

  Future<void> deletePost({
    required String postId,
    required String authorUid,
  }) async {
    final postRef = _posts.doc(postId);
    final postDoc = await postRef.get();
    
    if (!postDoc.exists) {
      throw Exception('Post not found');
    }
    
    final postData = postDoc.data()!;
    if (postData['authorUid'] != authorUid) {
      throw Exception('Not authorized to delete this post');
    }

    // Xóa tất cả subcollections (likes, comments)
    final batch = _firestore.batch();
    
    // Xóa likes
    final likes = await _postLikes(postId).get();
    for (final like in likes.docs) {
      batch.delete(like.reference);
    }
    
    // Xóa comments
    final comments = await _postComments(postId).get();
    for (final comment in comments.docs) {
      batch.delete(comment.reference);
    }
    
    // Xóa post document
    batch.delete(postRef);
    
    // Giảm postsCount
    batch.set(
      _firestore.collection('user_profiles').doc(authorUid),
      {
        'postsCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    
    await batch.commit();
  }

  /// Tìm kiếm posts theo caption (sử dụng captionLower)
  Future<List<Post>> searchPosts({
    required String query,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    if (query.trim().isEmpty) return [];
    
    final normalizedQuery = query.trim().toLowerCase();
    
    // Sử dụng prefix matching trên captionLower
    // Chỉ orderBy captionLower (không thể dùng nhiều orderBy cùng lúc)
    Query<Map<String, dynamic>> searchQuery = _posts
        .where('captionLower', isGreaterThanOrEqualTo: normalizedQuery)
        .where('captionLower', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
        .orderBy('captionLower')
        .limit(limit);
    
    if (startAfter != null) {
      searchQuery = searchQuery.startAfterDocument(startAfter);
    }
    
    final snapshot = await searchQuery.get();
    
    // Chuyển đổi sang Post và filter client-side để đảm bảo match chính xác
    final posts = snapshot.docs
        .map((doc) => Post.fromDoc(doc))
        .where((post) => post.caption.toLowerCase().contains(normalizedQuery))
        .toList();
    
    // Sắp xếp lại theo createdAt descending sau khi filter
    posts.sort((a, b) {
      final aTime = a.createdAt ?? DateTime(1970);
      final bTime = b.createdAt ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });
    
    return posts;
  }
}

