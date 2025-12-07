import '../../auth/auth_repository.dart';
import '../../notifications/services/notification_service.dart';
import '../models/report.dart';
import '../repositories/report_repository.dart';

class ReportService {
  ReportService({
    ReportRepository? repository,
    NotificationService? notificationService,
  })  : _repository = repository ?? ReportRepository(),
        _notificationService = notificationService ?? NotificationService();

  final ReportRepository _repository;
  final NotificationService _notificationService;

  Future<void> reportUser({
    required String targetUid,
    required String reason,
  }) async {
    final reporterUid = authRepository.currentUser()?.uid;
    if (reporterUid == null) {
      throw StateError('Bạn cần đăng nhập để báo cáo.');
    }
    
    // Submit report và lấy reportId
    final reportId = await _repository.submitReport(
      reporterUid: reporterUid,
      targetType: ReportTargetType.user,
      targetId: targetUid,
      targetOwnerUid: targetUid,
      reason: reason,
    );

    // Gửi notification cho admin
    await _notificationService.createReportNotification(
      reportId: reportId,
      reporterUid: reporterUid,
      targetUid: targetUid,
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

