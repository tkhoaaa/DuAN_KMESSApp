import 'package:cloud_firestore/cloud_firestore.dart';

class BlockRepository {
  BlockRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _blockCollection(String blockerUid) {
    return _firestore.collection('blocks').doc(blockerUid).collection('items');
  }

  DocumentReference<Map<String, dynamic>> blockDoc(
    String blockerUid,
    String blockedUid,
  ) {
    return _blockCollection(blockerUid).doc(blockedUid);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchBlock({
    required String blockerUid,
    required String blockedUid,
  }) {
    return blockDoc(blockerUid, blockedUid).snapshots();
  }

  Future<void> blockUser({
    required String blockerUid,
    required String blockedUid,
    String? reason,
  }) async {
    if (blockerUid.isEmpty ||
        blockedUid.isEmpty ||
        blockerUid == blockedUid) {
      return;
    }
    final data = <String, dynamic>{
      'blockedUid': blockedUid,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (reason != null && reason.isNotEmpty) {
      data['reason'] = reason;
    }

    // Debug log cho dữ liệu gửi lên Firestore
    // ignore: avoid_print
    print('=== DEBUG FIRESTORE DATA ===');
    // ignore: avoid_print
    print('Path: blocks/$blockerUid/items/$blockedUid');
    // ignore: avoid_print
    print('Data: $data');
    // ignore: avoid_print
    print('Keys: ${data.keys.toList()}');

    try {
      await blockDoc(blockerUid, blockedUid).set(data);
      // ignore: avoid_print
      print('✅ Firestore write thành công!');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Firestore error: $e');
      if (e is FirebaseException) {
        // ignore: avoid_print
        print('Code: ${e.code}');
        // ignore: avoid_print
        print('Message: ${e.message}');
      }
      rethrow;
    }
  }

  Future<void> unblockUser({
    required String blockerUid,
    required String blockedUid,
  }) async {
    await blockDoc(blockerUid, blockedUid).delete();
  }

  Future<bool> isBlocked({
    required String blockerUid,
    required String blockedUid,
  }) async {
    final snap = await blockDoc(blockerUid, blockedUid).get();
    return snap.exists;
  }

  Future<bool> isEitherBlocked({
    required String uidA,
    required String uidB,
  }) async {
    if (uidA.isEmpty || uidB.isEmpty) return false;
    final results = await Future.wait([
      blockDoc(uidA, uidB).get(),
      blockDoc(uidB, uidA).get(),
    ]);
    return results.any((doc) => doc.exists);
  }

  Stream<List<String>> watchBlockedIds(String blockerUid) {
    return _blockCollection(blockerUid).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => doc.id).toList(),
        );
  }

  Future<List<String>> fetchBlockedIds(String blockerUid) async {
    final snap = await _blockCollection(blockerUid).get();
    return snap.docs.map((doc) => doc.id).toList();
  }
}

