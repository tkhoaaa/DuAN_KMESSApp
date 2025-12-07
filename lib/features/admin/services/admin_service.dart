import '../../notifications/services/notification_service.dart';
import '../../profile/user_profile_repository.dart';
import '../../safety/models/report.dart' as admin_report;
import '../../safety/repositories/report_repository.dart';
import '../models/appeal.dart';
import '../models/ban.dart';
import '../repositories/admin_repository.dart';
import '../repositories/appeal_repository.dart';
import '../repositories/ban_repository.dart';

class AdminService {
  AdminService({
    AdminRepository? adminRepository,
    BanRepository? banRepository,
    AppealRepository? appealRepository,
    ReportRepository? reportRepository,
    UserProfileRepository? profileRepository,
    NotificationService? notificationService,
  })  : _adminRepository = adminRepository ?? AdminRepository(),
        _banRepository = banRepository ?? BanRepository(),
        _appealRepository = appealRepository ?? AppealRepository(),
        _reportRepository = reportRepository ?? ReportRepository(),
        _profileRepository = profileRepository ?? userProfileRepository,
        _notificationService = notificationService ?? NotificationService();

  final AdminRepository _adminRepository;
  final BanRepository _banRepository;
  final AppealRepository _appealRepository;
  final ReportRepository _reportRepository;
  final UserProfileRepository _profileRepository;
  final NotificationService _notificationService;

  /// Kiểm tra user có phải admin không
  Future<bool> isAdmin(String uid) async {
    return await _adminRepository.isAdmin(uid);
  }

  /// Stream admin status
  Stream<bool> watchAdminStatus(String uid) {
    return _adminRepository.watchAdminStatus(uid);
  }

  /// Khóa user
  Future<void> banUser({
    required String uid,
    required BanType banType,
    required BanLevel banLevel,
    required String reason,
    required String adminUid,
    String? reportId,
    DateTime? expiresAt,
  }) async {
    // Tạo ban document
    final banId = await _banRepository.createBan(
      uid: uid,
      banType: banType,
      banLevel: banLevel,
      reason: reason,
      reportId: reportId,
      adminUid: adminUid,
      expiresAt: expiresAt,
    );

    // Update UserProfile banStatus
    final banStatus = banType == BanType.permanent
        ? BanStatus.permanent
        : BanStatus.temporary;

    await _profileRepository.updateBanStatus(
      uid,
      banStatus: banStatus,
      banExpiresAt: expiresAt,
      activeBanId: banId,
    );

    // Nếu có reportId, update report status
    if (reportId != null) {
      await _reportRepository.updateReportStatus(
        reportId,
        admin_report.ReportStatus.resolved,
        adminUid: adminUid,
        banId: banId,
        actionTaken: admin_report.ReportAction.banned,
      );
    }
  }

  /// Mở khóa user
  Future<void> unbanUser(
    String banId, {
    required String adminUid,
    String? reason,
  }) async {
    final ban = await _banRepository.getBan(banId);
    if (ban == null) {
      throw StateError('Ban không tồn tại');
    }

    // Unban trong ban repository
    await _banRepository.unbanUser(banId, adminUid, reason: reason);

    // Update UserProfile banStatus
    await _profileRepository.updateBanStatus(
      ban.uid,
      banStatus: BanStatus.none,
      banExpiresAt: null,
      activeBanId: null,
    );
  }

  /// Xử lý report
  Future<void> resolveReport(
    String reportId, {
    required admin_report.ReportAction action,
    required String adminUid,
    String? adminNotes,
    String? banId,
  }) async {
    final status = action == admin_report.ReportAction.none
        ? admin_report.ReportStatus.rejected
        : admin_report.ReportStatus.resolved;

    await _reportRepository.updateReportStatus(
      reportId,
      status,
      adminUid: adminUid,
      adminNotes: adminNotes,
      banId: banId,
      actionTaken: action,
    );
  }

  /// Xử lý appeal
  Future<void> processAppeal(
    String appealId, {
    required AppealDecision decision,
    required String adminUid,
    String? adminNotes,
  }) async {
    final appeal = await _appealRepository.getAppeal(appealId);
    if (appeal == null) {
      throw StateError('Appeal không tồn tại');
    }

    final status = decision == AppealDecision.approve
        ? AppealStatus.approved
        : AppealStatus.rejected;

    // Update appeal status
    await _appealRepository.updateAppealStatus(
      appealId,
      status,
      adminUid: adminUid,
      adminNotes: adminNotes,
    );

    // Nếu approve → unban user
    if (decision == AppealDecision.approve) {
      await unbanUser(appeal.banId, adminUid: adminUid, reason: 'Appeal approved');
    }
  }
}

enum AppealDecision {
  approve,
  reject,
}

