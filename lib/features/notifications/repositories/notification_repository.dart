import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Không cần helper method này vì query trực tiếp

  /// Tạo notification mới với retry logic
  Future<void> createNotification(Notification notification, {int maxRetries = 2}) async {
    int retries = 0;
    while (retries <= maxRetries) {
      try {
        await _firestore.collection('notifications').add(notification.toMap());
        return; // Thành công, thoát khỏi loop
      } catch (e) {
        if (retries >= maxRetries) {
          // Đã hết số lần retry, throw exception
          rethrow;
        }
        // Đợi một chút trước khi retry (exponential backoff)
        await Future.delayed(Duration(milliseconds: 500 * (retries + 1)));
        retries++;
      }
    }
  }

  /// Đánh dấu notification là đã đọc
  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'read': true,
    });
  }

  /// Đánh dấu tất cả notifications của user là đã đọc
  Future<void> markAllAsRead(String uid) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();
    
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    
    await batch.commit();
  }

  /// Lấy danh sách notifications của user
  Stream<List<Notification>> watchNotifications(String uid, {int limit = 50}) {
    return _firestore
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(Notification.fromDoc).toList());
  }

  /// Đếm số lượng notifications chưa đọc
  Stream<int> watchUnreadCount(String uid) {
    return _firestore
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Lấy notifications trong một khoảng thời gian (để generate digest)
  /// Sử dụng query với toUid và createdAt >= startDate, sau đó filter client-side
  Future<List<Notification>> fetchNotificationsInRange({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Query với toUid và createdAt >= startDate, orderBy createdAt
    // Filter endDate ở client-side để tránh cần index phức tạp
    final snapshot = await _firestore
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .orderBy('createdAt', descending: true)
        .get();

    // Filter endDate ở client-side
    final endTimestamp = Timestamp.fromDate(endDate);
    final notifications = snapshot.docs
        .where((doc) {
          final createdAt = doc.data()['createdAt'] as Timestamp?;
          if (createdAt == null) return false;
          return createdAt.compareTo(endTimestamp) <= 0;
        })
        .map((doc) => Notification.fromDoc(doc))
        .toList();

    return notifications;
  }

  /// Tìm grouped notification theo groupKey trong time window
  /// Time window mặc định: 1 giờ
  Future<Notification?> findGroupedNotification({
    required String groupKey,
    required String toUid,
    Duration timeWindow = const Duration(hours: 1),
  }) async {
    final now = DateTime.now();
    final windowStart = now.subtract(timeWindow);
    
    final snapshot = await _firestore
        .collection('notifications')
        .where('groupKey', isEqualTo: groupKey)
        .where('toUid', isEqualTo: toUid)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(windowStart))
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return Notification.fromDoc(snapshot.docs.first);
  }

  /// Update grouped notification (tăng count, thêm fromUid vào fromUids)
  Future<void> updateGroupedNotification({
    required String notificationId,
    required String fromUid,
  }) async {
    final docRef = _firestore.collection('notifications').doc(notificationId);
    final doc = await docRef.get();
    
    if (!doc.exists) {
      throw Exception('Notification not found');
    }

    final data = doc.data()!;
    final currentCount = (data['count'] as num?)?.toInt() ?? 1;
    final currentFromUids = (data['fromUids'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toList();

    // Thêm fromUid vào list nếu chưa có
    final updatedFromUids = List<String>.from(currentFromUids);
    if (!updatedFromUids.contains(fromUid)) {
      updatedFromUids.add(fromUid);
    }

    // Giới hạn số lượng fromUids (tối đa 50)
    final finalFromUids = updatedFromUids.take(50).toList();

    await docRef.update({
      'count': currentCount + 1,
      'fromUids': finalFromUids,
      'createdAt': FieldValue.serverTimestamp(), // Update để notification hiển thị ở đầu
    });
  }
}

