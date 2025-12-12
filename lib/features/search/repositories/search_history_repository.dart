import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/search_history.dart';

class SearchHistoryRepository {
  SearchHistoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _getCollection(String uid) =>
      _firestore.collection('users').doc(uid).collection('search_history');

  /// Lưu lịch sử tìm kiếm
  Future<void> saveSearchHistory({
    required String uid,
    required String query,
    required String searchType, // 'user' or 'post'
  }) async {
    if (query.trim().isEmpty) return;

    final normalizedQuery = query.trim().toLowerCase();
    
    // Kiểm tra xem đã có lịch sử tìm kiếm này chưa
    final existing = await _getCollection(uid)
        .where('query', isEqualTo: normalizedQuery)
        .where('searchType', isEqualTo: searchType)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // Cập nhật createdAt của lịch sử cũ
      await existing.docs.first.reference.update({
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    // Tạo lịch sử mới
    await _getCollection(uid).add({
      'query': normalizedQuery,
      'searchType': searchType,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Giới hạn số lượng lịch sử (xóa các lịch sử cũ nhất nếu vượt quá 50)
    await _limitHistory(uid);
  }

  /// Giới hạn số lượng lịch sử (giữ lại 50 mục mới nhất)
  Future<void> _limitHistory(String uid) async {
    final allHistory = await _getCollection(uid)
        .orderBy('createdAt', descending: true)
        .get();

    if (allHistory.docs.length > 50) {
      final toDelete = allHistory.docs.skip(50);
      final batch = _firestore.batch();
      for (final doc in toDelete) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  /// Lấy lịch sử tìm kiếm
  Future<List<SearchHistory>> getSearchHistory({
    required String uid,
    String? searchType, // 'user' or 'post' or null for all
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _getCollection(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (searchType != null) {
      query = query.where('searchType', isEqualTo: searchType);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => SearchHistory.fromDoc(doc)).toList();
  }

  /// Stream lịch sử tìm kiếm
  Stream<List<SearchHistory>> watchSearchHistory({
    required String uid,
    String? searchType, // 'user' or 'post' or null for all
    int limit = 20,
  }) {
    Query<Map<String, dynamic>> query = _getCollection(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (searchType != null) {
      query = query.where('searchType', isEqualTo: searchType);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => SearchHistory.fromDoc(doc)).toList());
  }

  /// Xóa một lịch sử tìm kiếm
  Future<void> deleteSearchHistory({
    required String uid,
    required String historyId,
  }) async {
    await _getCollection(uid).doc(historyId).delete();
  }

  /// Xóa tất cả lịch sử tìm kiếm
  Future<void> clearSearchHistory({
    required String uid,
    String? searchType, // 'user' or 'post' or null for all
  }) async {
    Query<Map<String, dynamic>> query = _getCollection(uid);

    if (searchType != null) {
      query = query.where('searchType', isEqualTo: searchType);
    }

    final snapshot = await query.get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

