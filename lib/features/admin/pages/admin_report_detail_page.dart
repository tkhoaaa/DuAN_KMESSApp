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

class _AdminReportDetailPageState extends State<AdminReportDetailPage>
    with SingleTickerProviderStateMixin {
  final ReportRepository _reportRepository = ReportRepository();
  final AdminService _adminService = AdminService();
  final UserProfileRepository _profileRepository = UserProfileRepository();
  report_models.Report? _report;
  String? _targetDisplayName;
  bool _isLoading = true;
  bool _isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _loadReport();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      _animationController.forward();
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết báo cáo'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_report == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết báo cáo'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(child: Text('Không tìm thấy báo cáo')),
      );
    }

    final report = _report!;
    final isResolved = report.reportStatus != report_models.ReportStatus.pending;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withOpacity(0.2),
              colorScheme.secondaryContainer.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // App Bar
                  SliverAppBar(
                    expandedHeight: 120,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      title: const Text(
                        'Chi tiết báo cáo',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      centerTitle: false,
                    ),
                    actions: [
                      if (report.targetOwnerUid != null)
                        IconButton(
                          icon: const Icon(Icons.person_outline),
                          tooltip: 'Xem profile',
                          onPressed: () {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder: (context, animation, _) =>
                                    PublicProfilePage(uid: report.targetOwnerUid!),
                                transitionsBuilder:
                                    (context, animation, secondaryAnimation, child) {
                                  return SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(1.0, 0.0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  // Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status Card with Animation
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOut,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.scale(
                                  scale: 0.8 + (value * 0.2),
                                  child: child,
                                ),
                              );
                            },
                            child: _buildStatusCard(report, colorScheme),
                          ),
                          const SizedBox(height: 24),
                          // Report Info Cards
                          _buildAnimatedInfoCard(
                            delay: 100,
                            child: _buildInfoCard(
                              icon: Icons.category_outlined,
                              title: 'Loại báo cáo',
                              value: _getTargetTypeText(report.targetType),
                              colorScheme: colorScheme,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildAnimatedInfoCard(
                            delay: 200,
                            child: _buildInfoCard(
                              icon: Icons.tag_outlined,
                              title: 'ID đối tượng',
                              value: report.targetId,
                              colorScheme: colorScheme,
                            ),
                          ),
                          if (report.targetOwnerUid != null) ...[
                            const SizedBox(height: 16),
                            _buildAnimatedInfoCard(
                              delay: 300,
                              child: _buildUserCard(report, colorScheme),
                            ),
                          ],
                          if (report.reason != null) ...[
                            const SizedBox(height: 16),
                            _buildAnimatedInfoCard(
                              delay: 400,
                              child: _buildReasonCard(report.reason!, colorScheme),
                            ),
                          ],
                          if (report.createdAt != null) ...[
                            const SizedBox(height: 16),
                            _buildAnimatedInfoCard(
                              delay: 500,
                              child: _buildInfoCard(
                                icon: Icons.access_time_outlined,
                                title: 'Thời gian tạo',
                                value: _formatDate(report.createdAt!),
                                colorScheme: colorScheme,
                              ),
                            ),
                          ],
                          if (report.resolvedBy != null) ...[
                            const SizedBox(height: 16),
                            _buildAnimatedInfoCard(
                              delay: 600,
                              child: _buildInfoCard(
                                icon: Icons.person_outline,
                                title: 'Xử lý bởi',
                                value: report.resolvedBy!,
                                colorScheme: colorScheme,
                              ),
                            ),
                          ],
                          if (report.resolvedAt != null) ...[
                            const SizedBox(height: 16),
                            _buildAnimatedInfoCard(
                              delay: 700,
                              child: _buildInfoCard(
                                icon: Icons.check_circle_outline,
                                title: 'Thời gian xử lý',
                                value: _formatDate(report.resolvedAt!),
                                colorScheme: colorScheme,
                              ),
                            ),
                          ],
                          if (report.adminNotes != null) ...[
                            const SizedBox(height: 16),
                            _buildAnimatedInfoCard(
                              delay: 800,
                              child: _buildNotesCard(report.adminNotes!, colorScheme),
                            ),
                          ],
                          if (report.actionTaken != null) ...[
                            const SizedBox(height: 16),
                            _buildAnimatedInfoCard(
                              delay: 900,
                              child: _buildInfoCard(
                                icon: Icons.gavel_outlined,
                                title: 'Hành động đã thực hiện',
                                value: _getActionText(report.actionTaken!),
                                colorScheme: colorScheme,
                              ),
                            ),
                          ],
                          // Action buttons
                          if (!isResolved) ...[
                            const SizedBox(height: 32),
                            _buildAnimatedInfoCard(
                              delay: 1000,
                              child: _buildActionButtons(report, colorScheme),
                            ),
                          ],
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(report_models.Report report, ColorScheme colorScheme) {
    final statusColor = _getStatusColor(report.reportStatus);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.15),
            statusColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(report.reportStatus),
              color: statusColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trạng thái',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getStatusText(report.reportStatus),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedInfoCard({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(report_models.Report report, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.person_outline, color: colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Người dùng',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: report.targetOwnerUid == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder: (context, animation, _) =>
                                  PublicProfilePage(uid: report.targetOwnerUid!),
                              transitionsBuilder:
                                  (context, animation, secondaryAnimation, child) {
                                return SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(1.0, 0.0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _targetDisplayName ?? report.targetOwnerUid ?? 'Người dùng',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.open_in_new,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonCard(String reason, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.description_outlined, color: colorScheme.secondary, size: 24),
              ),
              const SizedBox(width: 16),
              const Text(
                'Lý do báo cáo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              reason,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(String notes, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.note_outlined, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 16),
              const Text(
                'Ghi chú của admin',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Text(
              notes,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(report_models.Report report, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Xử lý báo cáo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildAnimatedButton(
            onPressed: _isProcessing
                ? null
                : () => _resolveReport(report_models.ReportAction.banned),
            icon: Icons.block,
            label: 'Khóa tài khoản',
            color: Colors.red,
            delay: 0,
          ),
          const SizedBox(height: 12),
          _buildAnimatedButton(
            onPressed: _isProcessing
                ? null
                : () => _resolveReport(report_models.ReportAction.warning),
            icon: Icons.warning_amber_rounded,
            label: 'Cảnh báo',
            color: Colors.orange,
            delay: 100,
          ),
          const SizedBox(height: 12),
          _buildAnimatedButton(
            onPressed: _isProcessing
                ? null
                : () => _resolveReport(report_models.ReportAction.none),
            icon: Icons.close,
            label: 'Bỏ qua',
            color: Colors.grey,
            isOutlined: true,
            delay: 200,
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required int delay,
    bool isOutlined = false,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + delay),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Material(
          elevation: onPressed == null ? 0 : (isOutlined ? 0 : 2),
          shadowColor: color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          color: isOutlined ? Colors.transparent : color,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: isOutlined
                    ? Border.all(color: color, width: 1.5)
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: isOutlined ? color : Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: isOutlined ? color : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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

}

