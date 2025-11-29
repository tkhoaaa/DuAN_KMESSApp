import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/draft_post.dart';
import '../models/post_media.dart';
import 'post_repository.dart';

class DraftPostRepository {
  DraftPostRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _draftsRef(String uid) =>
      _firestore.collection('post_drafts').doc(uid).collection('items');

  /// Lưu draft mới
  Future<String> saveDraft({
    required String uid,
    List<PostMedia>? media,
    String? caption,
    List<String>? hashtags,
  }) async {
    final doc = _draftsRef(uid).doc();
    final captionText = caption ?? '';
    final hashtagsList = hashtags ??
        (captionText.isNotEmpty
            ? PostRepository.extractHashtagsFromCaption(captionText)
            : []);

    await doc.set({
      'media': (media ?? []).map((m) => m.toMap()).toList(),
      if (captionText.isNotEmpty) 'caption': captionText,
      'hashtags': hashtagsList,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  /// Cập nhật draft đã tồn tại
  Future<void> updateDraft({
    required String uid,
    required String draftId,
    List<PostMedia>? media,
    String? caption,
    List<String>? hashtags,
  }) async {
    final doc = _draftsRef(uid).doc(draftId);
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (media != null) {
      data['media'] = media.map((m) => m.toMap()).toList();
    }
    if (caption != null) {
      data['caption'] = caption;
      // Extract hashtags từ caption nếu không có hashtags được truyền vào
      if (hashtags == null && caption.isNotEmpty) {
        data['hashtags'] = PostRepository.extractHashtagsFromCaption(caption);
      }
    }
    if (hashtags != null) {
      data['hashtags'] = hashtags;
    }

    await doc.set(data, SetOptions(merge: true));
  }

  /// Xóa draft
  Future<void> deleteDraft({
    required String uid,
    required String draftId,
  }) async {
    await _draftsRef(uid).doc(draftId).delete();
  }

  /// Lấy một draft
  Future<DraftPost?> fetchDraft({
    required String uid,
    required String draftId,
  }) async {
    final doc = await _draftsRef(uid).doc(draftId).get();
    if (!doc.exists) return null;
    return DraftPost.fromDoc(doc);
  }

  /// Watch tất cả drafts của user
  Stream<List<DraftPost>> watchDrafts(String uid) {
    return _draftsRef(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DraftPost.fromDoc(doc))
            .toList());
  }

  /// Fetch tất cả drafts của user (pagination)
  Future<List<DraftPost>> fetchDrafts({
    required String uid,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query =
        _draftsRef(uid).orderBy('updatedAt', descending: true).limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => DraftPost.fromDoc(doc)).toList();
  }
}

