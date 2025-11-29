import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post.dart';
import '../models/post_comment.dart';
import '../models/feed_filters.dart';
import '../models/post_media.dart';

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

  /// Trích xuất hashtags từ caption (regex tìm từ bắt đầu bằng #)
  /// Trả về list hashtags đã normalize (lowercase, loại bỏ trùng lặp, giới hạn độ dài)
  static List<String> extractHashtagsFromCaption(String caption) {
    if (caption.trim().isEmpty) return [];
    
    // Regex để tìm hashtag: bắt đầu bằng #, theo sau là chữ, số, underscore
    // Giới hạn độ dài tối đa 50 ký tự (không tính #)
    final regex = RegExp(r'#[\w]{1,50}', caseSensitive: false);
    final matches = regex.allMatches(caption);
    
    // Extract và normalize (lowercase, loại bỏ #)
    final hashtags = matches
        .map((match) => match.group(0)?.substring(1).toLowerCase() ?? '')
        .where((tag) => tag.isNotEmpty)
        .toSet() // Loại bỏ trùng lặp
        .toList();
    
    // Giới hạn tối đa 10 hashtags mỗi post
    return hashtags.take(10).toList();
  }

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
    DateTime? scheduledAt,
  }) async {
    final doc = _posts.doc();
    final captionText = caption ?? '';
    final hashtags = extractHashtagsFromCaption(captionText);
    
    // Xác định status dựa trên scheduledAt
    final now = DateTime.now();
    final isScheduled = scheduledAt != null && scheduledAt.isAfter(now);
    final status = isScheduled ? PostStatus.scheduled : PostStatus.published;
    
    final data = <String, dynamic>{
      'authorUid': authorUid,
      'media': media,
      'caption': captionText,
      'captionLower': captionText.toLowerCase(),
      'hashtags': hashtags,
      'createdAt': FieldValue.serverTimestamp(),
      'likeCount': 0,
      'commentCount': 0,
      'status': status.name,
    };
    
    if (isScheduled) {
      data['scheduledAt'] = Timestamp.fromDate(scheduledAt);
    }
    
    await doc.set(data);

    // Chỉ increment postsCount nếu post được publish ngay
    if (status == PostStatus.published) {
      await _firestore.collection('user_profiles').doc(authorUid).set({
        'postsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return doc.id;
  }

  /// Fetch scheduled posts của user
  Future<List<Post>> fetchScheduledPosts({
    required String authorUid,
    int limit = 20,
  }) async {
    try {
      final snapshot = await _posts
          .where('authorUid', isEqualTo: authorUid)
          .where('status', isEqualTo: PostStatus.scheduled.name)
          .orderBy('scheduledAt', descending: false)
          .limit(limit)
          .get();
      
      // Filter out posts without scheduledAt (shouldn't happen but just in case)
      final posts = snapshot.docs
          .map((doc) => Post.fromDoc(doc))
          .where((post) => post.scheduledAt != null)
          .toList();
      
      return posts;
    } catch (e) {
      // Fallback: Query không có orderBy nếu index chưa sẵn sàng
      print('Error fetching scheduled posts with orderBy: $e');
      try {
        final snapshot = await _posts
            .where('authorUid', isEqualTo: authorUid)
            .where('status', isEqualTo: PostStatus.scheduled.name)
            .limit(limit)
            .get();
        
        final posts = snapshot.docs
            .map((doc) => Post.fromDoc(doc))
            .where((post) => post.scheduledAt != null)
            .toList();
        
        // Sort client-side
        posts.sort((a, b) {
          if (a.scheduledAt == null) return 1;
          if (b.scheduledAt == null) return -1;
          return a.scheduledAt!.compareTo(b.scheduledAt!);
        });
        
        return posts;
      } catch (fallbackError) {
        print('Fallback query also failed: $fallbackError');
        rethrow;
      }
    }
  }

  /// Publish scheduled post (chuyển status từ scheduled sang published)
  Future<void> publishScheduledPost({
    required String postId,
    required String authorUid,
  }) async {
    await _firestore.runTransaction((txn) async {
      final postRef = _posts.doc(postId);
      final postSnap = await txn.get(postRef);
      
      if (!postSnap.exists) {
        throw StateError('Post not found');
      }
      
      final data = postSnap.data()!;
      if (data['status'] != PostStatus.scheduled.name) {
        throw StateError('Post is not scheduled');
      }
      
      // Update status và xóa scheduledAt
      txn.update(postRef, {
        'status': PostStatus.published.name,
        'scheduledAt': FieldValue.delete(),
      });
      
      // Increment postsCount
      final profileRef = _firestore.collection('user_profiles').doc(authorUid);
      txn.set(profileRef, {
        'postsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Cancel scheduled post (chuyển status sang cancelled)
  Future<void> cancelScheduledPost(String postId) async {
    await _posts.doc(postId).update({
      'status': PostStatus.cancelled.name,
    });
  }

  /// Update scheduled time của post
  Future<void> updateScheduledTime({
    required String postId,
    required DateTime newScheduledAt,
  }) async {
    final now = DateTime.now();
    if (newScheduledAt.isBefore(now)) {
      throw ArgumentError('Scheduled time must be in the future');
    }
    
    await _posts.doc(postId).update({
      'scheduledAt': Timestamp.fromDate(newScheduledAt),
    });
  }

  Future<PostPageResult> fetchPosts({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 10,
    bool includeScheduled = false,
  }) async {
    // Query posts với status = published hoặc không có status (backward compatibility)
    // Firestore không hỗ trợ OR query trực tiếp, nên ta cần query riêng và merge
    Query<Map<String, dynamic>> query = _posts
        .where('status', isEqualTo: PostStatus.published.name)
        .orderBy('createdAt', descending: true)
        .limit(limit * 2); // Lấy nhiều hơn để filter client-side
    
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    
    final snap = await query.get();
    
    // Filter client-side để bao gồm posts không có status (backward compatibility)
    final docs = snap.docs.where((doc) {
      final data = doc.data();
      final statusStr = data['status'] as String?;
      // Nếu không có status hoặc status = published, thì include
      if (statusStr == null) return true;
      return statusStr == PostStatus.published.name;
    }).take(limit).toList();
    
    return PostPageResult(
      docs: docs,
      lastDoc: docs.isNotEmpty ? docs.last : startAfter,
      hasMore: docs.length == limit,
    );
  }

  /// Fetch posts với filters (media, time, sort)
  Future<PostPageResult> fetchPostsWithFilters({
    required FeedFilters filters,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) async {
    // Build query với time filter và sort option
    Query<Map<String, dynamic>> query = _posts
        .where('status', isEqualTo: PostStatus.published.name);

    // Apply time filter
    final startDate = filters.getStartDate();
    if (startDate != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    // Apply sort option
    String orderByField;
    bool descending;
    switch (filters.sortOption) {
      case PostSortOption.newest:
        orderByField = 'createdAt';
        descending = true;
        break;
      case PostSortOption.mostLiked:
        orderByField = 'likeCount';
        descending = true;
        break;
      case PostSortOption.mostCommented:
        orderByField = 'commentCount';
        descending = true;
        break;
    }
    query = query.orderBy(orderByField, descending: descending);

    // Nếu sort không phải createdAt, cần thêm orderBy createdAt làm secondary sort
    if (orderByField != 'createdAt') {
      // Firestore chỉ cho phép 1 orderBy, nên ta sẽ sort client-side nếu cần
      // Hoặc tạo composite index với cả 2 fields
    }

    // Limit và pagination
    query = query.limit(limit * 2); // Lấy nhiều hơn để filter client-side cho media type
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();

    // Convert to Post objects
    final posts = snap.docs
        .map((doc) => Post.fromDoc(doc))
        .where((post) {
          // Filter backward compatibility: posts không có status
          if (post.status != PostStatus.published) return false;

          // Apply media filter (client-side)
          switch (filters.mediaFilter) {
            case PostMediaFilter.all:
              return true;
            case PostMediaFilter.images:
              return post.media.any((m) => m.type == PostMediaType.image);
            case PostMediaFilter.videos:
              return post.media.any((m) => m.type == PostMediaType.video);
          }
        })
        .take(limit)
        .toList();

    // Convert back to docs for pagination
    final postIds = posts.map((p) => p.id).toSet();
    final filteredDocs = snap.docs.where((doc) => postIds.contains(doc.id)).toList();

    return PostPageResult(
      docs: filteredDocs,
      lastDoc: filteredDocs.isNotEmpty ? filteredDocs.last : startAfter,
      hasMore: filteredDocs.length == limit,
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

  /// Stream để listen posts mới được publish (status thay đổi từ scheduled sang published)
  /// Chỉ trả về posts có status = published
  Stream<List<Post>> watchPublishedPosts({
    int limit = 10,
  }) {
    return _posts
        .where('status', isEqualTo: PostStatus.published.name)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Post.fromDoc(doc))
            .toList());
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

    // Tự động gỡ post khỏi pinnedPostIds của tất cả users
    // Query tất cả user_profiles có pinnedPostIds chứa postId này
    final profilesWithPinned = await _firestore
        .collection('user_profiles')
        .where('pinnedPostIds', arrayContains: postId)
        .get();

    // Update từng profile để xóa postId khỏi pinnedPostIds
    if (profilesWithPinned.docs.isNotEmpty) {
      final updateBatch = _firestore.batch();
      for (final profileDoc in profilesWithPinned.docs) {
        final profileData = profileDoc.data();
        final pinnedPostIds = List<String>.from(
          profileData['pinnedPostIds'] as List<dynamic>? ?? [],
        );
        pinnedPostIds.remove(postId);
        
        updateBatch.update(profileDoc.reference, {
          'pinnedPostIds': pinnedPostIds,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await updateBatch.commit();
    }
  }

  /// Fetch posts theo authorUid (pagination)
  Future<PostPageResult> fetchPostsByAuthor({
    required String authorUid,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _posts
        .where('authorUid', isEqualTo: authorUid)
        .orderBy('createdAt', descending: true)
        .limit(limit);
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

  /// Stream posts theo hashtag (realtime)
  Stream<List<Post>> watchPostsByHashtag(
    String tag, {
    int limit = 20,
    String sortBy = 'createdAt', // 'createdAt' hoặc 'hot' (likeCount + commentCount)
  }) {
    if (tag.trim().isEmpty) return Stream.value([]);
    
    final normalizedTag = tag.trim().toLowerCase();
    
    Query<Map<String, dynamic>> query = _posts
        .where('hashtags', arrayContains: normalizedTag)
        .limit(limit);
    
    // Sort theo thời gian hoặc độ hot
    if (sortBy == 'hot') {
      // Không thể sort trực tiếp theo likeCount + commentCount trong Firestore
      // Sẽ sort client-side sau khi fetch
      query = query.orderBy('createdAt', descending: true);
    } else {
      query = query.orderBy('createdAt', descending: true);
    }
    
    return query.snapshots().map((snapshot) {
      final posts = snapshot.docs.map((doc) => Post.fromDoc(doc)).toList();
      
      // Nếu sortBy == 'hot', sort lại theo likeCount + commentCount
      if (sortBy == 'hot') {
        posts.sort((a, b) {
          final aScore = a.likeCount + a.commentCount;
          final bScore = b.likeCount + b.commentCount;
          if (aScore != bScore) {
            return bScore.compareTo(aScore); // Descending
          }
          // Nếu score bằng nhau, sort theo thời gian
          final aTime = a.createdAt ?? DateTime(1970);
          final bTime = b.createdAt ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });
      }
      
      return posts;
    });
  }

  /// Fetch posts theo hashtag (pagination)
  Future<PostPageResult> fetchPostsByHashtag(
    String tag, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String sortBy = 'createdAt', // 'createdAt' hoặc 'hot'
  }) async {
    if (tag.trim().isEmpty) {
      return PostPageResult(docs: [], lastDoc: null, hasMore: false);
    }
    
    final normalizedTag = tag.trim().toLowerCase();
    
    Query<Map<String, dynamic>> query = _posts
        .where('hashtags', arrayContains: normalizedTag)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    
    final snapshot = await query.get();
    final docs = snapshot.docs;
    
    // Nếu sortBy == 'hot', cần sort lại client-side
    // Nhưng vì Firestore không hỗ trợ sort theo computed field,
    // ta sẽ sort sau khi fetch
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sortedDocs = docs;
    if (sortBy == 'hot') {
      sortedDocs = List.from(docs);
      sortedDocs.sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        final aScore = ((aData['likeCount'] as num?)?.toInt() ?? 0) +
            ((aData['commentCount'] as num?)?.toInt() ?? 0);
        final bScore = ((bData['likeCount'] as num?)?.toInt() ?? 0) +
            ((bData['commentCount'] as num?)?.toInt() ?? 0);
        if (aScore != bScore) {
          return bScore.compareTo(aScore); // Descending
        }
        // Nếu score bằng nhau, sort theo thời gian
        final aTime = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
        final bTime = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
    }
    
    return PostPageResult(
      docs: sortedDocs,
      lastDoc: sortedDocs.isNotEmpty ? sortedDocs.last : startAfter,
      hasMore: sortedDocs.length == limit,
    );
  }

  /// Fetch trending hashtags (dựa trên số lượng posts sử dụng)
  /// Tạm thời: aggregate từ posts collection (có thể optimize sau với hashtags collection)
  Future<List<String>> fetchTrendingHashtags({int limit = 10}) async {
    // Lấy các posts gần đây và đếm hashtags
    final recentPosts = await _posts
        .orderBy('createdAt', descending: true)
        .limit(100) // Lấy 100 posts gần nhất để tính trending
        .get();
    
    final hashtagCounts = <String, int>{};
    
    for (final doc in recentPosts.docs) {
      final data = doc.data();
      final hashtags = (data['hashtags'] as List<dynamic>? ?? [])
          .map((item) => item.toString().toLowerCase())
          .where((item) => item.isNotEmpty)
          .toList();
      
      for (final tag in hashtags) {
        hashtagCounts[tag] = (hashtagCounts[tag] ?? 0) + 1;
      }
    }
    
    // Sort theo số lượng và lấy top N
    final sortedTags = hashtagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedTags.take(limit).map((e) => e.key).toList();
  }
}

