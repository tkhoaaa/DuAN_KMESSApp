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
}

