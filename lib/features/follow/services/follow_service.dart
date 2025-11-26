import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../auth/auth_repository.dart';
import '../../notifications/services/notification_service.dart';
import '../../profile/user_profile_repository.dart';
import '../models/follow_request.dart';
import '../models/follow_state.dart';
import '../repositories/follow_repository.dart';

class FollowEntry {
  FollowEntry({
    required this.uid,
    required this.profile,
    this.followedAt,
    this.isMutual = false,
  });

  final String uid;
  final UserProfile? profile;
  final DateTime? followedAt;
  final bool isMutual;
}

class FollowRequestEntry {
  FollowRequestEntry({
    required this.uid,
    required this.profile,
    required this.createdAt,
  });

  final String uid;
  final UserProfile? profile;
  final DateTime? createdAt;
}

class FollowService {
  FollowService({
    FollowRepository? repository,
    UserProfileRepository? profileRepository,
    FirebaseFirestore? firestore,
  })  : _repository = repository ?? FollowRepository(firestore: firestore),
        _profiles = profileRepository ?? userProfileRepository,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FollowRepository _repository;
  final UserProfileRepository _profiles;
  final FirebaseFirestore _firestore;
  final NotificationService _notificationService = NotificationService();

  Future<List<UserProfile>> searchUsers({
    required String keyword,
    int limit = 20,
  }) async {
    final query = keyword.trim();
    if (query.isEmpty) return [];

    final results = <String, UserProfile>{};
    final keywordLower = query.toLowerCase();

    final byDisplayName = await _firestore
        .collection('user_profiles')
        .where('displayNameLower', isGreaterThanOrEqualTo: keywordLower)
        .where('displayNameLower', isLessThanOrEqualTo: '$keywordLower\uf8ff')
        .limit(limit)
        .get();
    for (final doc in byDisplayName.docs) {
      results[doc.id] = UserProfile.fromDoc(doc);
    }

    final emailQueries = await Future.wait([
      _firestore
          .collection('user_profiles')
          .where('emailLower', isEqualTo: keywordLower)
          .limit(limit)
          .get(),
      _firestore
          .collection('user_profiles')
          .where('email', isEqualTo: query)
          .limit(limit)
          .get(),
      _firestore
          .collection('user_profiles')
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(limit)
          .get(),
    ]);
    for (final snap in emailQueries) {
      for (final doc in snap.docs) {
        results[doc.id] = UserProfile.fromDoc(doc);
      }
    }

    // normalize lowercase fields for legacy docs
    for (final profile in results.values) {
      final updates = <String, dynamic>{};
      if (profile.displayName?.isNotEmpty == true &&
          profile.displayNameLower == null) {
        updates['displayNameLower'] = profile.displayName!.toLowerCase();
      }
      if (profile.email?.isNotEmpty == true &&
          profile.emailLower == null) {
        updates['emailLower'] = profile.email!.toLowerCase();
      }
      if (updates.isNotEmpty) {
        await _firestore
            .collection('user_profiles')
            .doc(profile.uid)
            .set(updates, SetOptions(merge: true));
      }
    }

    return results.values.toList();
  }

  Future<FollowStatus> followUser(String targetUid) async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) {
      throw StateError('Bạn cần đăng nhập');
    }
    if (currentUid == targetUid) {
      return FollowStatus.self;
    }

    final targetProfile = await _profiles.fetchProfile(targetUid);
    if (targetProfile == null) {
      throw StateError('Không tìm thấy người dùng.');
    }

    if (targetProfile.isPrivate) {
      await _repository.sendFollowRequest(
        followerUid: currentUid,
        targetUid: targetUid,
      );
      return FollowStatus.requested;
    }

    await _repository.followUser(
      followerUid: currentUid,
      targetUid: targetUid,
    );
    // Tạo notification
    _notificationService.createFollowNotification(
      followerUid: currentUid,
      followedUid: targetUid,
    ).catchError((e) => debugPrint('Error creating follow notification: $e'));
    return FollowStatus.following;
  }

  Future<void> cancelRequest(String targetUid) async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) return;
    await _repository.cancelFollowRequest(
      followerUid: currentUid,
      targetUid: targetUid,
    );
  }

  Future<void> unfollow(String targetUid) async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) return;
    await _repository.unfollowUser(
      followerUid: currentUid,
      targetUid: targetUid,
    );
  }

  Future<void> acceptRequest(String followerUid) async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) return;
    await _repository.acceptFollowRequest(
      targetUid: currentUid,
      followerUid: followerUid,
    );
    // Tạo notification khi accept follow request
    _notificationService.createFollowNotification(
      followerUid: followerUid,
      followedUid: currentUid,
    ).catchError((e) => debugPrint('Error creating follow notification: $e'));
  }

  Future<void> declineRequest(String followerUid) async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) return;
    await _repository.declineFollowRequest(
      targetUid: currentUid,
      followerUid: followerUid,
    );
  }

  Stream<FollowState> watchFollowState(
    String currentUid,
    String targetUid,
  ) {
    if (currentUid == targetUid) {
      return Stream.value(
        FollowState(status: FollowStatus.self, isTargetPrivate: false),
      );
    }
    final targetProfileStream = _profiles.watchProfile(targetUid);
    return targetProfileStream.asyncMap((profile) async {
      if (profile == null) {
        return FollowState(status: FollowStatus.none, isTargetPrivate: false);
      }
      final isFollowing = await _repository.isFollowing(
        currentUid: currentUid,
        targetUid: targetUid,
      );
      if (isFollowing) {
        return FollowState(
          status: FollowStatus.following,
          isTargetPrivate: profile.isPrivate,
        );
      }
      final hasRequest = await _repository.hasPendingRequest(
        currentUid: currentUid,
        targetUid: targetUid,
      );
      if (hasRequest) {
        return FollowState(
          status: FollowStatus.requested,
          isTargetPrivate: profile.isPrivate,
        );
      }
      return FollowState(
        status: FollowStatus.none,
        isTargetPrivate: profile.isPrivate,
      );
    });
  }

  Future<FollowStatus> fetchFollowStatus(
    String currentUid,
    String targetUid,
  ) async {
    if (currentUid == targetUid) return FollowStatus.self;
    final targetProfile = await _profiles.fetchProfile(targetUid);
    if (targetProfile == null) return FollowStatus.none;
    final isFollowing = await _repository.isFollowing(
      currentUid: currentUid,
      targetUid: targetUid,
    );
    if (isFollowing) return FollowStatus.following;
    final hasRequest = await _repository.hasPendingRequest(
      currentUid: currentUid,
      targetUid: targetUid,
    );
    if (hasRequest) return FollowStatus.requested;
    return FollowStatus.none;
  }

  Stream<List<FollowEntry>> watchFollowingEntries(String uid) {
    return _repository.watchFollowing(uid).asyncMap((snapshot) async {
      final futures = snapshot.docs.map((doc) async {
        final otherUid = doc.id;
        final profile = await _profiles.fetchProfile(otherUid);
        return FollowEntry(
          uid: otherUid,
          profile: profile,
          followedAt: (doc.data()['followedAt'] as Timestamp?)?.toDate(),
          isMutual: await _repository.isFollowing(
            currentUid: otherUid,
            targetUid: uid,
          ),
        );
      }).toList();
      return Future.wait(futures);
    });
  }

  Stream<List<FollowEntry>> watchFollowersEntries(String uid) {
    return _repository.watchFollowers(uid).asyncMap((snapshot) async {
      final followingIds = await _repository.fetchFollowingIds(uid);
      final futures = snapshot.docs.map((doc) async {
        final otherUid = doc.id;
        final profile = await _profiles.fetchProfile(otherUid);
        return FollowEntry(
          uid: otherUid,
          profile: profile,
          followedAt: (doc.data()['followedAt'] as Timestamp?)?.toDate(),
          isMutual: followingIds.contains(otherUid),
        );
      }).toList();
      return Future.wait(futures);
    });
  }

  Stream<List<FollowRequestEntry>> watchIncomingRequestEntries(String uid) {
    return _repository.watchIncomingRequests(uid).asyncMap((snapshot) async {
      final futures = snapshot.docs.map((doc) async {
        final request = FollowRequest.fromDoc(doc);
        final profile = await _profiles.fetchProfile(request.followerUid);
        return FollowRequestEntry(
          uid: request.followerUid,
          profile: profile,
          createdAt: request.createdAt,
        );
      }).toList();
      return Future.wait(futures);
    });
  }

  Stream<List<FollowRequestEntry>> watchSentRequestEntries(String uid) {
    return _repository.watchSentRequests(uid).asyncMap((snapshot) async {
      final futures = snapshot.docs.map((doc) async {
        final request = FollowRequest.fromCollectionGroupDoc(doc);
        final profile = await _profiles.fetchProfile(request.targetUid);
        return FollowRequestEntry(
          uid: request.targetUid,
          profile: profile,
          createdAt: request.createdAt,
        );
      }).toList();
      return Future.wait(futures);
    });
  }
}

