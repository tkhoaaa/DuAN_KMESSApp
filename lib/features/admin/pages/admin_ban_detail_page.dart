import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../profile/public_profile_page.dart';
import '../models/ban.dart';
import '../repositories/ban_repository.dart';
import '../services/admin_service.dart';

class AdminBanDetailPage extends StatefulWidget {
  const AdminBanDetailPage({
    super.key,
    required this.banId,
  });

  final String banId;

  @override
  State<AdminBanDetailPage> createState() => _AdminBanDetailPageState();
}

class _AdminBanDetailPageState extends State<AdminBanDetailPage> {
  final BanRepository _banRepository = BanRepository();
  final AdminService _adminService = AdminService();
  Ban? _ban;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadBan();
  }

  Future<void> _loadBan() async {
    final ban = await _banRepository.getBan(widget.banId);
    setState(() {
      _ban = ban;
      _isLoading = false;
    });
  }

  Future<void> _unbanUser() async {
    if (_ban == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mở khóa tài khoản'),
        content: const Text('Bạn có chắc chắn muốn mở khóa tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mở khóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final adminUid = authRepository.currentUser()?.uid;
      if (adminUid == null) {
        throw StateError('Bạn cần đăng nhập');
      }

      await _adminService.unbanUser(
        widget.banId,
        adminUid: adminUid,
        reason: 'Admin mở khóa thủ công',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã mở khóa tài khoản'),
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
        appBar: AppBar(title: const Text('Chi tiết ban')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_ban == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết ban')),
        body: const Center(child: Text('Không tìm thấy ban')),
      );
    }

    final ban = _ban!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết ban'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Xem profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PublicProfilePage(uid: ban.uid),
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
                color: ban.isActive
                    ? Colors.red.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ban.isActive ? Colors.red : Colors.green,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    ban.isActive ? Icons.block : Icons.check_circle,
                    color: ban.isActive ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ban.isActive ? 'Đang khóa' : 'Đã mở khóa',
                    style: TextStyle(
                      color: ban.isActive ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Ban info
            _buildInfoRow('UID người dùng', ban.uid),
            _buildInfoRow(
              'Loại ban',
              ban.banType == BanType.permanent ? 'Vĩnh viễn' : 'Tạm thời',
            ),
            _buildInfoRow('Mức độ', _getBanLevelText(ban.banLevel)),
            _buildInfoRow('Lý do', ban.reason),
            if (ban.reportId != null)
              _buildInfoRow('Report ID', ban.reportId!),
            _buildInfoRow('Khóa bởi', ban.bannedBy),
            _buildInfoRow('Thời gian khóa', _formatDate(ban.bannedAt)),
            if (ban.expiresAt != null)
              _buildInfoRow('Hết hạn', _formatDate(ban.expiresAt!)),
            if (ban.appealId != null)
              _buildInfoRow('Appeal ID', ban.appealId!),
            // Action button
            if (ban.isActive) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Mở khóa tài khoản'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isProcessing ? null : _unbanUser,
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

  String _getBanLevelText(BanLevel level) {
    switch (level) {
      case BanLevel.warning:
        return 'Cảnh báo';
      case BanLevel.light:
        return 'Nhẹ (1-3 ngày)';
      case BanLevel.medium:
        return 'Trung bình (7-30 ngày)';
      case BanLevel.severe:
        return 'Nghiêm trọng (Vĩnh viễn)';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

