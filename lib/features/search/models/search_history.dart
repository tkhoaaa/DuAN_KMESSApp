import 'package:cloud_firestore/cloud_firestore.dart';

class SearchHistory {
  SearchHistory({
    required this.id,
    required this.uid,
    required this.query,
    required this.searchType, // 'user' or 'post'
    required this.createdAt,
  });

  final String id;
  final String uid;
  final String query;
  final String searchType; // 'user' or 'post'
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'query': query,
      'searchType': searchType,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory SearchHistory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return SearchHistory(
      id: doc.id,
      uid: data['uid'] as String,
      query: data['query'] as String,
      searchType: data['searchType'] as String? ?? 'user',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}

