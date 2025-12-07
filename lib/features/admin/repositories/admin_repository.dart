import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin.dart';

class AdminRepository {
  AdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _adminsRef =>
      _firestore.collection('admins');

  /// Kiểm tra user có phải admin không
  Future<bool> isAdmin(String uid) async {
    final doc = await _adminsRef.doc(uid).get();
    return doc.exists;
  }

  /// Stream admin status
  Stream<bool> watchAdminStatus(String uid) {
    return _adminsRef.doc(uid).snapshots().map((doc) => doc.exists);
  }

  /// Lấy danh sách admin UIDs
  Future<List<String>> getAllAdmins() async {
    final snapshot = await _adminsRef.get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Lấy admin document
  Future<Admin?> getAdmin(String uid) async {
    final doc = await _adminsRef.doc(uid).get();
    if (!doc.exists) return null;
    return Admin.fromDoc(doc);
  }

  /// Stream tất cả admins (để gửi notification)
  Stream<List<Admin>> watchAllAdmins() {
    return _adminsRef.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Admin.fromDoc(doc)).toList());
  }
}

