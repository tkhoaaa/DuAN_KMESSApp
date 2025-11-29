import 'package:cloud_firestore/cloud_firestore.dart';

enum DigestPeriod {
  daily,
  weekly,
}

class NotificationDigest {
  NotificationDigest({
    required this.id,
    required this.uid,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.stats,
    this.topPosts = const [],
    this.createdAt,
  });

  final String id;
  final String uid;
  final DigestPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final DigestStats stats;
  final List<String> topPosts; // Danh sách post IDs có nhiều tương tác nhất
  final DateTime? createdAt;

  factory NotificationDigest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final periodStr = data['period'] as String? ?? 'daily';
    final period = periodStr == 'weekly' ? DigestPeriod.weekly : DigestPeriod.daily;

    final statsData = data['stats'] as Map<String, dynamic>? ?? {};
    final stats = DigestStats(
      likesCount: (statsData['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (statsData['commentsCount'] as num?)?.toInt() ?? 0,
      followsCount: (statsData['followsCount'] as num?)?.toInt() ?? 0,
      messagesCount: (statsData['messagesCount'] as num?)?.toInt() ?? 0,
    );

    final topPostsData = data['topPosts'] as List<dynamic>? ?? [];
    final topPosts = topPostsData.map((item) => item.toString()).toList();

    return NotificationDigest(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      period: period,
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      stats: stats,
      topPosts: topPosts,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'period': period == DigestPeriod.weekly ? 'weekly' : 'daily',
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'stats': {
        'likesCount': stats.likesCount,
        'commentsCount': stats.commentsCount,
        'followsCount': stats.followsCount,
        'messagesCount': stats.messagesCount,
      },
      'topPosts': topPosts,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

class DigestStats {
  DigestStats({
    this.likesCount = 0,
    this.commentsCount = 0,
    this.followsCount = 0,
    this.messagesCount = 0,
  });

  final int likesCount;
  final int commentsCount;
  final int followsCount;
  final int messagesCount;

  int get totalInteractions =>
      likesCount + commentsCount + followsCount; // Bỏ messagesCount
}

