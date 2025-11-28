import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../auth/auth_repository.dart';
import '../repositories/block_repository.dart';

class BlockService {
  BlockService({
    BlockRepository? repository,
    FirebaseFirestore? firestore,
  }) : _repository = repository ??
            BlockRepository(
              firestore: firestore ?? FirebaseFirestore.instance,
            );

  final BlockRepository _repository;

  Stream<bool> watchIsBlocked({
    required String blockerUid,
    required String blockedUid,
  }) {
    if (blockerUid.isEmpty || blockedUid.isEmpty) {
      return Stream<bool>.value(false);
    }
    return _repository
        .watchBlock(blockerUid: blockerUid, blockedUid: blockedUid)
        .map((snap) => snap.exists);
  }

  Future<bool> isBlockedByMe(String targetUid) async {
    final currentUid = authRepository.currentUser()?.uid ?? '';
    if (currentUid.isEmpty) return false;
    return _repository.isBlocked(
      blockerUid: currentUid,
      blockedUid: targetUid,
    );
  }

  Future<bool> isEitherBlocked(String uidA, String uidB) {
    return _repository.isEitherBlocked(uidA: uidA, uidB: uidB);
  }

  Future<void> blockUser({
    required String targetUid,
    String? reason,
    VoidCallback? onCompleted,
  }) async {
    final currentUid = authRepository.currentUser()?.uid;
    // Debug logs để xác định trạng thái auth
    // ignore: avoid_print
    print('=== DEBUG BLOCK USER ===');
    // ignore: avoid_print
    print('Current UID: $currentUid');
    // ignore: avoid_print
    print('Target UID: $targetUid');
    // ignore: avoid_print
    print('Reason: $reason');

    if (currentUid == null) {
      throw StateError('Bạn cần đăng nhập để chặn người dùng.');
    }

    try {
      await _repository.blockUser(
        blockerUid: currentUid,
        blockedUid: targetUid,
        reason: reason,
      );
      // ignore: avoid_print
      print('✅ Block thành công!');
      onCompleted?.call();
    } catch (e) {
      // ignore: avoid_print
      print('❌ Lỗi block: $e');
      rethrow;
    }
  }

  Future<void> unblockUser(String targetUid) async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) {
      throw StateError('Bạn cần đăng nhập để bỏ chặn.');
    }
    await _repository.unblockUser(
      blockerUid: currentUid,
      blockedUid: targetUid,
    );
  }

  Stream<List<String>> watchMyBlockedIds() {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) {
      return const Stream<List<String>>.empty();
    }
    return _repository.watchBlockedIds(currentUid);
  }

  Future<List<String>> fetchMyBlockedIds() async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) return [];
    return _repository.fetchBlockedIds(currentUid);
  }
}

final BlockService blockService = BlockService();

