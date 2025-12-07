import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../profile/public_profile_page.dart';
import '../../profile/user_profile_repository.dart';
import '../../safety/models/report.dart' as report_models;
import '../../safety/repositories/report_repository.dart';
import '../models/ban.dart';
import '../services/admin_service.dart';
import 'ban_user_dialog.dart';

class AdminReportDetailPage extends StatefulWidget {
  const AdminReportDetailPage({
    super.key,
    required this.reportId,
  });

  final String reportId;

  @override
  State<AdminReportDetailPage> createState() => _AdminReportDetailPageState();
}

class _AdminReportDetailPageState extends State<AdminReportDetailPage> {
  final ReportRepository _reportRepository = ReportRepository();
  final AdminService _adminService = AdminService();
  final UserProfileRepository _profileRepository = UserProfileRepository();
  report_models.Report? _report;
  String? _targetDisplayName;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    final report = await _reportRepository.getReport(widget.reportId);
    String? displayName;
    if (report?.targetOwnerUid != null) {
      try {
        final profile =
            await _profileRepository.fetchProfile(report!.targetOwnerUid!);
        displayName = profile?.displayName;
      } catch (_) {
        // Ignore profile load errors, vẫn hiển thị UID
      }
    }

    if (mounted) {
      setState(() {
        _report = report;
        _targetDisplayName = displayName;
        _isLoading = false;
      });
    }
  }

  Future<void> _resolveReport(report_models.ReportAction action) async {
    if (_report == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final adminUid = authRepository.currentUser()?.uid;
      if (adminUid == null) {
        throw StateError('Bạn cần đăng nhập');
      }

      String? banId;
      if (action == report_models.ReportAction.banned) {
        // Hiển thị dialog để chọn ban level và duration
        final banResult = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => BanUserDialog(
            targetUid: _report!.targetOwnerUid ?? _report!.targetId,
            reportId: widget.reportId,
          ),
        );

        if (banResult == null) {
          // User cancelled
          setState(() {
            _isProcessing = false;
          });
          return;
        }

        // Ban user
        await _adminService.banUser(
          uid: banResult['uid'] as String,
          banType: banResult['banType'] as BanType,
          banLevel: banResult['banLevel'] as BanLevel,
          reason: banResult['reason'] as String,
          adminUid: adminUid,
          reportId: widget.reportId,
          expiresAt: banResult['expiresAt'] as DateTime?,
        );

        banId = banResult['banId'] as String?;
      }

      // Resolve report
      await _adminService.resolveReport(
        widget.reportId,
        action: action,
        adminUid: adminUid,
        banId: banId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xử lý báo cáo'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết báo cáo')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết báo cáo')),
        body: const Center(child: Text('Không tìm thấy báo cáo')),
      );
    }

    final report = _report!;
    final isResolved = report.reportStatus != report_models.ReportStatus.pending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết báo cáo'),
        actions: [
          if (report.targetOwnerUid != null)
            IconButton(
              icon: const Icon(Icons.person),
              tooltip: 'Xem profile',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PublicProfilePage(
                      uid: report.targetOwnerUid!,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(report.reportStatus).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getStatusColor(report.reportStatus),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(report.reportStatus),
                    color: _getStatusColor(report.reportStatus),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getStatusText(report.reportStatus),
                    style: TextStyle(
                      color: _getStatusColor(report.reportStatus),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Report info
            _buildInfoRow('Loại báo cáo', _getTargetTypeText(report.targetType)),
            _buildInfoRow('ID đối tượng', report.targetId),
            if (report.targetOwnerUid != null) ...[
              _buildInfoRow('UID người dùng', report.targetOwnerUid!),
              _buildUserLinkRow(report),
            ],
            if (report.reason != null)
              _buildInfoRow('Lý do', report.reason!),
            if (report.createdAt != null)
              _buildInfoRow(
                'Thời gian',
                _formatDate(report.createdAt!),
              ),
            if (report.resolvedBy != null)
              _buildInfoRow('Xử lý bởi', report.resolvedBy!),
            if (report.resolvedAt != null)
              _buildInfoRow(
                'Thời gian xử lý',
                _formatDate(report.resolvedAt!),
              ),
            if (report.adminNotes != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Ghi chú của admin',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(report.adminNotes!),
              ),
            ],
            if (report.actionTaken != null) ...[
              const SizedBox(height: 16),
              _buildInfoRow(
                'Hành động',
                _getActionText(report.actionTaken!),
              ),
            ],
            // Action buttons
            if (!isResolved) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Xử lý báo cáo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.block),
                  label: const Text('Khóa tài khoản'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isProcessing
                      ? null
                      : () => _resolveReport(report_models.ReportAction.banned),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.warning),
                  label: const Text('Cảnh báo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isProcessing
                      ? null
                      : () => _resolveReport(report_models.ReportAction.warning),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Bỏ qua'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isProcessing
                      ? null
                      : () => _resolveReport(report_models.ReportAction.none),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(report_models.ReportStatus status) {
    switch (status) {
      case report_models.ReportStatus.pending:
        return Colors.orange;
      case report_models.ReportStatus.resolved:
        return Colors.green;
      case report_models.ReportStatus.rejected:
        return Colors.red;
    }
  }

  String _getStatusText(report_models.ReportStatus status) {
    switch (status) {
      case report_models.ReportStatus.pending:
        return 'Chờ xử lý';
      case report_models.ReportStatus.resolved:
        return 'Đã xử lý';
      case report_models.ReportStatus.rejected:
        return 'Đã từ chối';
    }
  }

  IconData _getStatusIcon(report_models.ReportStatus status) {
    switch (status) {
      case report_models.ReportStatus.pending:
        return Icons.pending;
      case report_models.ReportStatus.resolved:
        return Icons.check_circle;
      case report_models.ReportStatus.rejected:
        return Icons.cancel;
    }
  }

  String _getTargetTypeText(report_models.ReportTargetType type) {
    switch (type) {
      case report_models.ReportTargetType.user:
        return 'Người dùng';
      case report_models.ReportTargetType.post:
        return 'Bài đăng';
      case report_models.ReportTargetType.comment:
        return 'Bình luận';
      case report_models.ReportTargetType.story:
        return 'Story';
    }
  }

  String _getActionText(report_models.ReportAction action) {
    switch (action) {
      case report_models.ReportAction.none:
        return 'Bỏ qua';
      case report_models.ReportAction.warning:
        return 'Cảnh báo';
      case report_models.ReportAction.banned:
        return 'Khóa tài khoản';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildUserLinkRow(report_models.Report report) {
    final displayName = _targetDisplayName ?? report.targetOwnerUid ?? 'Người dùng';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              'Trang cá nhân',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: report.targetOwnerUid == null
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PublicProfilePage(
                            uid: report.targetOwnerUid!,
                          ),
                        ),
                      );
                    },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

