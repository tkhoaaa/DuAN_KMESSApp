import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/cloudinary_service.dart';
import '../models/story.dart';

class StoryRepository {
  StoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _storiesCollection(String uid) =>
      _firestore.collection('stories').doc(uid).collection('items');

  CollectionReference<Map<String, dynamic>> _viewersCollection(
          String uid, String storyId) =>
      _storiesCollection(uid).doc(storyId).collection('viewers');

  /// Tạo story mới sau khi đã có mediaUrl (nếu bạn upload bên ngoài)
  Future<void> createStory({
    required String authorUid,
    required String mediaUrl,
    required StoryMediaType type,
    String? thumbnailUrl,
    String? text,
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

    final docRef = _storiesCollection(authorUid).doc();
    
    // Debug: In ra thông tin để kiểm tra
    // Kiểm tra authentication state trước khi tạo story
    final currentUser = FirebaseAuth.instance.currentUser;
    debugPrint('=== Story Creation Debug ===');
    debugPrint('Current Firebase Auth User: ${currentUser?.uid}');
    debugPrint('Current Firebase Auth Email: ${currentUser?.email}');
    debugPrint('Author UID: $authorUid');
    debugPrint('UIDs match: ${currentUser?.uid == authorUid}');
    debugPrint('Creating story - path: stories/$authorUid/items/${docRef.id}');
    
    if (currentUser == null) {
      throw Exception('User not authenticated. Please log in again.');
    }
    
    final currentUid = currentUser.uid;
    if (currentUid != authorUid) {
      throw Exception('Author UID mismatch. Current user: $currentUid, Author: $authorUid');
    }
    
    // Đảm bảo tất cả fields bắt buộc đều có giá trị
    final storyData = <String, dynamic>{
      'authorUid': authorUid,
      'mediaUrl': mediaUrl,
      'type': type.name,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
    
    // Thêm optional fields
    if (thumbnailUrl != null) {
      storyData['thumbnailUrl'] = thumbnailUrl;
    }
    if (text != null && text.isNotEmpty) {
      storyData['text'] = text;
    }
    
    debugPrint('Story data: $storyData');
    debugPrint('Story data keys: ${storyData.keys.toList()}');
    debugPrint('Story data types:');
    storyData.forEach((key, value) {
      debugPrint('  $key: ${value.runtimeType}');
    });
    
    try {
      debugPrint('Attempting to create story document...');
      await docRef.set(storyData);
      debugPrint('Story created successfully!');
    } catch (e, stackTrace) {
      debugPrint('=== Story Creation Error ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error message: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Thêm thông tin chi tiết về lỗi
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('permission') || errorString.contains('denied')) {
        debugPrint('=== Permission Denied Debug ===');
        final authUid = FirebaseAuth.instance.currentUser?.uid ?? 'null';
        debugPrint('Current Firebase Auth UID: $authUid');
        debugPrint('Author UID: $authorUid');
        debugPrint('UIDs match: ${authUid == authorUid}');
        debugPrint('Story path: stories/$authorUid/items/${docRef.id}');
        debugPrint('Story data fields:');
        storyData.forEach((key, value) {
          debugPrint('  $key: $value (${value.runtimeType})');
        });
        debugPrint('Required fields check:');
        debugPrint('  authorUid: ${storyData['authorUid']} (${storyData['authorUid'].runtimeType})');
        debugPrint('  mediaUrl: ${storyData['mediaUrl']} (${storyData['mediaUrl'].runtimeType})');
        debugPrint('  type: ${storyData['type']} (${storyData['type'].runtimeType})');
        debugPrint('  createdAt: ${storyData['createdAt']} (${storyData['createdAt'].runtimeType})');
        debugPrint('  expiresAt: ${storyData['expiresAt']} (${storyData['expiresAt'].runtimeType})');
      }
      
      rethrow;
    }
  }

  /// Upload file lên Cloudinary và tạo story
  Future<void> uploadAndCreateStoryImage({
    required String authorUid,
    required XFile file,
    String? text,
  }) async {
    final result = await CloudinaryService.uploadImage(
      file: file,
      folder: 'stories/$authorUid',
    );
    final mediaUrl = result['url']!;
    await createStory(
      authorUid: authorUid,
      mediaUrl: mediaUrl,
      type: StoryMediaType.image,
      text: text,
    );
  }

  Future<void> uploadAndCreateStoryVideo({
    required String authorUid,
    required XFile file,
    String? text,
  }) async {
    final result = await CloudinaryService.uploadVideo(
      file: file,
      folder: 'stories/$authorUid',
    );
    final mediaUrl = result['url'] as String;
    final thumbnailUrl = result['thumbnailUrl'] as String?;
    await createStory(
      authorUid: authorUid,
      mediaUrl: mediaUrl,
      type: StoryMediaType.video,
      thumbnailUrl: thumbnailUrl,
      text: text,
    );
  }

  /// Stream danh sách story còn hiệu lực của một user
  Stream<List<Story>> watchUserStories(String uid) {
    return _storiesCollection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      return snap.docs
          .map(Story.fromDoc)
          .where((story) => story.expiresAt.isAfter(now))
          .toList();
    });
  }

  /// Trạng thái vòng story quanh avatar:
  /// - none: không có story còn hạn
  /// - unseen: có ít nhất 1 story chưa xem (vòng hồng)
  /// - allSeen: có story và tất cả đều đã xem (vòng xám)
  Future<StoryRingStatus> fetchStoryRingStatus({
    required String ownerUid,
    required String viewerUid,
  }) async {
    try {
      final activeStories = await watchUserStories(ownerUid).first;
      if (activeStories.isEmpty) {
        return StoryRingStatus.none;
      }

      for (final story in activeStories) {
        final viewerDoc =
            await _viewersCollection(ownerUid, story.id).doc(viewerUid).get();
        if (!viewerDoc.exists) {
          // Chỉ cần 1 story chưa xem là hiển thị vòng hồng
          return StoryRingStatus.unseen;
        }
      }

      // Có story và tất cả đều đã xem
      return StoryRingStatus.allSeen;
    } catch (_) {
      // Nếu có lỗi, mặc định không hiển thị vòng để tránh crash
      return StoryRingStatus.none;
    }
  }

  /// Stream toàn bộ story (kể cả đã hết hạn) của user để làm kho lưu trữ
  Stream<List<Story>> watchUserStoryArchive(String uid, {int limit = 200}) {
    return _storiesCollection(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Story.fromDoc).toList());
  }

  /// Fetch stories by author (one-time, includes expired)
  Stream<List<Story>> fetchStoriesByAuthor(String uid, {int limit = 200}) {
    return _storiesCollection(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Story.fromDoc).toList());
  }

  /// Đăng lại một story trong kho lưu trữ (tạo story mới với media cũ)
  Future<void> repostStory({
    required String authorUid,
    required Story story,
  }) async {
    await createStory(
      authorUid: authorUid,
      mediaUrl: story.mediaUrl,
      type: story.type,
      thumbnailUrl: story.thumbnailUrl,
      text: story.text,
    );
  }

  /// Ghi nhận viewer cho story (best effort)
  Future<void> addViewer({
    required String authorUid,
    required String storyId,
    required String viewerUid,
  }) async {
    final viewerRef = _viewersCollection(authorUid, storyId).doc(viewerUid);
    await viewerRef.set({
      'viewedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Toggle tim (like) cho story của người khác
  Future<void> toggleStoryLike({
    required String authorUid,
    required String storyId,
    required String likerUid,
  }) async {
    final viewerRef = _viewersCollection(authorUid, storyId).doc(likerUid);
    final snap = await viewerRef.get();
    if (snap.exists && (snap.data()?['liked'] == true)) {
      // Bỏ tim
      await viewerRef.update({'liked': false});
    } else if (snap.exists) {
      // Đã xem, chỉ update flag liked
      await viewerRef.update({'liked': true});
    } else {
      // Chưa có viewer record: tạo mới với viewedAt + liked
      await viewerRef.set({
        'viewedAt': FieldValue.serverTimestamp(),
        'liked': true,
      }, SetOptions(merge: true));
    }
  }

  /// Lấy danh sách viewers kèm trạng thái tim (liked)
  Future<List<StoryViewerEntry>> fetchViewerEntries({
    required String authorUid,
    required String storyId,
  }) async {
    final snap = await _viewersCollection(authorUid, storyId)
        .orderBy('viewedAt', descending: true)
        .get();
    return snap.docs.map((d) => StoryViewerEntry.fromDoc(d)).toList();
  }

  /// Kiểm tra 1 user cụ thể đã tim story chưa (đọc 1 document, không query)
  Future<bool> isStoryLikedByUser({
    required String authorUid,
    required String storyId,
    required String viewerUid,
  }) async {
    final doc =
        await _viewersCollection(authorUid, storyId).doc(viewerUid).get();
    final data = doc.data();
    if (data == null) return false;
    return data['liked'] == true;
  }

  /// Xóa story
  Future<void> deleteStory({
    required String authorUid,
    required String storyId,
  }) async {
    await _storiesCollection(authorUid).doc(storyId).delete();
  }
}

enum StoryRingStatus {
  none,
  unseen,
  allSeen,
}

class StoryViewerEntry {
  StoryViewerEntry({
    required this.uid,
    required this.viewedAt,
    required this.liked,
  });

  final String uid;
  final DateTime? viewedAt;
  final bool liked;

  factory StoryViewerEntry.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return StoryViewerEntry(
      uid: doc.id,
      viewedAt: (data['viewedAt'] as Timestamp?)?.toDate(),
      liked: data['liked'] as bool? ?? false,
    );
  }
}

