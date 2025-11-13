import 'package:cloud_firestore/cloud_firestore.dart';

class FollowRepository {
  FollowRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _followersRef(String uid) =>
      _firestore
          .collection('user_profiles')
          .doc(uid)
          .collection('followers');

  CollectionReference<Map<String, dynamic>> _followingRef(String uid) =>
      _firestore
          .collection('user_profiles')
          .doc(uid)
          .collection('following');

  CollectionReference<Map<String, dynamic>> _requestsRef(String uid) =>
      _firestore.collection('follow_requests').doc(uid).collection('requests');

  Future<void> followUser({
    required String followerUid,
    required String targetUid,
  }) async {
    if (followerUid == targetUid) return;

    await _firestore.runTransaction((txn) async {
      final followerDoc = _followersRef(targetUid).doc(followerUid);
      final followSnap = await txn.get(followerDoc);
      if (followSnap.exists) {
        return;
      }

      txn.set(followerDoc, {
        'followedAt': FieldValue.serverTimestamp(),
      });

      txn.set(_followingRef(followerUid).doc(targetUid), {
        'followedAt': FieldValue.serverTimestamp(),
      });

      txn.set(
        _firestore.collection('user_profiles').doc(targetUid),
        {'followersCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
      txn.set(
        _firestore.collection('user_profiles').doc(followerUid),
        {'followingCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    });
  }

  Future<void> unfollowUser({
    required String followerUid,
    required String targetUid,
  }) async {
    if (followerUid == targetUid) return;

    await _firestore.runTransaction((txn) async {
      final followerDoc = _followersRef(targetUid).doc(followerUid);
      final followSnap = await txn.get(followerDoc);
      if (!followSnap.exists) {
        return;
      }

      txn.delete(followerDoc);
      txn.delete(_followingRef(followerUid).doc(targetUid));

      txn.set(
        _firestore.collection('user_profiles').doc(targetUid),
        {'followersCount': FieldValue.increment(-1)},
        SetOptions(merge: true),
      );
      txn.set(
        _firestore.collection('user_profiles').doc(followerUid),
        {'followingCount': FieldValue.increment(-1)},
        SetOptions(merge: true),
      );
    });
  }

  Future<void> sendFollowRequest({
    required String followerUid,
    required String targetUid,
  }) async {
    if (followerUid == targetUid) return;

    final requestDoc = _requestsRef(targetUid).doc(followerUid);
    await requestDoc.set({
      'fromUid': followerUid,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> cancelFollowRequest({
    required String followerUid,
    required String targetUid,
  }) async {
    final requestDoc = _requestsRef(targetUid).doc(followerUid);
    await requestDoc.delete();
  }

  Future<void> acceptFollowRequest({
    required String targetUid,
    required String followerUid,
  }) async {
    await _firestore.runTransaction((txn) async {
      final requestDoc = _requestsRef(targetUid).doc(followerUid);
      final requestSnap = await txn.get(requestDoc);
      if (!requestSnap.exists) {
        return;
      }
      txn.delete(requestDoc);

      final followerDoc = _followersRef(targetUid).doc(followerUid);
      final followerSnap = await txn.get(followerDoc);
      if (!followerSnap.exists) {
        txn.set(followerDoc, {
          'followedAt': FieldValue.serverTimestamp(),
        });
        txn.set(_followingRef(followerUid).doc(targetUid), {
          'followedAt': FieldValue.serverTimestamp(),
        });
        txn.set(
          _firestore.collection('user_profiles').doc(targetUid),
          {'followersCount': FieldValue.increment(1)},
          SetOptions(merge: true),
        );
        txn.set(
          _firestore.collection('user_profiles').doc(followerUid),
          {'followingCount': FieldValue.increment(1)},
          SetOptions(merge: true),
        );
      }
    });
  }

  Future<void> declineFollowRequest({
    required String targetUid,
    required String followerUid,
  }) async {
    final requestDoc = _requestsRef(targetUid).doc(followerUid);
    await requestDoc.delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchFollowers(String uid) {
    return _followersRef(uid).orderBy('followedAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchFollowing(String uid) {
    return _followingRef(uid)
        .orderBy('followedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchIncomingRequests(
      String uid) {
    return _requestsRef(uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSentRequests(
      String uid) {
    return _firestore
        .collectionGroup('requests')
        .where('fromUid', isEqualTo: uid)
        .snapshots();
  }

  Future<bool> isFollowing({
    required String currentUid,
    required String targetUid,
  }) async {
    final doc =
        await _followersRef(targetUid).doc(currentUid).get();
    return doc.exists;
  }

  Future<bool> hasPendingRequest({
    required String currentUid,
    required String targetUid,
  }) async {
    final doc = await _requestsRef(targetUid).doc(currentUid).get();
    return doc.exists;
  }

  Future<Set<String>> fetchFollowingIds(String uid) async {
    final snap = await _followingRef(uid).get();
    return snap.docs.map((doc) => doc.id).toSet();
  }
}

