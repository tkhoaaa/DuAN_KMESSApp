import '../../auth/auth_repository.dart';
import '../models/report.dart';
import '../repositories/report_repository.dart';

class ReportService {
  ReportService({ReportRepository? repository})
      : _repository = repository ?? ReportRepository();

  final ReportRepository _repository;

  Future<void> reportUser({
    required String targetUid,
    required String reason,
  }) async {
    final reporterUid = authRepository.currentUser()?.uid;
    if (reporterUid == null) {
      throw StateError('Bạn cần đăng nhập để báo cáo.');
    }
    await _repository.submitReport(
      reporterUid: reporterUid,
      targetType: ReportTargetType.user,
      targetId: targetUid,
      targetOwnerUid: targetUid,
      reason: reason,
    );
  }

  Future<void> reportPost({
    required String postId,
    required String ownerUid,
    required String reason,
  }) async {
    final reporterUid = authRepository.currentUser()?.uid;
    if (reporterUid == null) {
      throw StateError('Bạn cần đăng nhập để báo cáo.');
    }
    await _repository.submitReport(
      reporterUid: reporterUid,
      targetType: ReportTargetType.post,
      targetId: postId,
      targetOwnerUid: ownerUid,
      reason: reason,
    );
  }
}

final ReportService reportService = ReportService();

