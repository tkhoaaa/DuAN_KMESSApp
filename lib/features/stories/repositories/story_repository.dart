import 'package:cloud_firestore/cloud_firestore.dart';
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
    await docRef.set({
      'authorUid': authorUid,
      'mediaUrl': mediaUrl,
      'type': type.name,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (text != null && text.isNotEmpty) 'text': text,
    });
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

  /// Lấy danh sách viewers (chỉ nên gọi cho story của chính mình)
  Future<List<String>> fetchViewers({
    required String authorUid,
    required String storyId,
  }) async {
    final snap = await _viewersCollection(authorUid, storyId)
        .orderBy('viewedAt', descending: true)
        .get();
    return snap.docs.map((d) => d.id).toList();
  }
}


