import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../profile/user_profile_repository.dart';
import '../../safety/models/report.dart' as report_models;
import '../../safety/repositories/report_repository.dart';
import '../models/appeal.dart';
import '../models/ban.dart';
import '../repositories/appeal_repository.dart';
import '../repositories/ban_repository.dart';
import 'user_appeal_form_page.dart';

class UserBanScreen extends StatefulWidget {
  const UserBanScreen({super.key});

  @override
  State<UserBanScreen> createState() => _UserBanScreenState();
}

class _UserBanScreenState extends State<UserBanScreen> {
  final BanRepository _banRepository = BanRepository();
  final AppealRepository _appealRepository = AppealRepository();
  final ReportRepository _reportRepository = ReportRepository();
  Ban? _ban;
  Appeal? _appeal;
  report_models.Report? _report;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBanStatus();
  }

  Future<void> _loadBanStatus() async {
    final user = authRepository.currentUser();
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final profile = await userProfileRepository.fetchProfile(user.uid);
      String? activeBanId = profile?.activeBanId;

      if (profile?.banStatus == BanStatus.none) {
        setState(() {
          _isLoading = false;
          _ban = null;
        });
        return;
      }

      Ban? ban;
      if (activeBanId != null) {
        ban = await _banRepository.getBan(activeBanId);
      } else if (profile != null) {
        ban = await _banRepository.getActiveBan(user.uid);
        activeBanId = ban?.id;
      }

      if (ban == null || !ban.isActive || ban.isExpired) {
        setState(() {
          _isLoading = false;
          _ban = null;
        });
        return;
      }

      final currentBan = ban;

      // Kiểm tra xem user đã có appeal chưa
      final appeals = await _appealRepository.getAppealsByUser(user.uid);
      final activeAppeal = appeals.firstWhere(
        (a) => a.banId == currentBan.id && a.status == AppealStatus.pending,
        orElse: () => Appeal(
          id: '',
          uid: '',
          banId: '',
          reason: '',
          createdAt: DateTime.now(),
        ),
      );

      // Lấy report gốc nếu có
      report_models.Report? report;
      if (currentBan.reportId != null && currentBan.reportId!.isNotEmpty) {
        try {
          report = await _reportRepository.getReport(currentBan.reportId!);
        } catch (_) {
          report = null;
        }
      }

      if (!mounted) return;
      setState(() {
        _ban = currentBan;
        _appeal = activeAppeal.id.isNotEmpty ? activeAppeal : null;
        _report = report;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải thông tin khóa tài khoản. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _loadBanStatus();
                  },
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_ban == null) {
      // Không bị ban, không hiển thị gì
      return const SizedBox.shrink();
    }

    final ban = _ban!;
    final hasPendingAppeal = _appeal != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản bị khóa'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await authRepository.signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ban status icon
            Center(
              child: Icon(
                ban.banType == BanType.permanent
                    ? Icons.block
                    : Icons.schedule,
                size: 80,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            // Title
            const Center(
              child: Text(
                'Tài khoản của bạn đã bị khóa',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            // Ban info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Loại khóa', _getBanTypeText(ban.banType)),
                  _buildInfoRow('Mức độ', _getBanLevelText(ban.banLevel)),
                  _buildInfoRow('Lý do khóa', ban.reason),
                  if (_report != null) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Lý do bị báo cáo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _report!.reason ?? 'Không có lý do cụ thể.',
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (_report!.createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Thời gian báo cáo: ${_formatDate(_report!.createdAt!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ],
                  if (ban.expiresAt != null)
                    _buildInfoRow(
                      'Hết hạn',
                      _formatDate(ban.expiresAt!),
                    ),
                  _buildInfoRow('Thời gian khóa', _formatDate(ban.bannedAt)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Appeal section
            if (hasPendingAppeal) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pending, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Text(
                          'Đơn kháng cáo đang chờ xử lý',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _appeal!.reason,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gửi lúc: ${_formatDate(_appeal!.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text(
                'Bạn có thể gửi đơn kháng cáo nếu bạn nghĩ rằng việc khóa tài khoản là không đúng.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.gavel),
                  label: const Text('Gửi đơn kháng cáo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => UserAppealFormPage(
                          banId: ban.id,
                        ),
                      ),
                    ).then((_) {
                      // Reload ban status sau khi gửi appeal
                      _loadBanStatus();
                    });
                  },
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
            width: 100,
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

  String _getBanTypeText(BanType type) {
    return type == BanType.permanent ? 'Vĩnh viễn' : 'Tạm thời';
  }

  String _getBanLevelText(BanLevel level) {
    switch (level) {
      case BanLevel.warning:
        return 'Cảnh báo';
      case BanLevel.light:
        return 'Nhẹ';
      case BanLevel.medium:
        return 'Trung bình';
      case BanLevel.severe:
        return 'Nghiêm trọng';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

