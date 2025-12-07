import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../profile/public_profile_page.dart';
import '../models/appeal.dart';
import '../models/ban.dart';
import '../repositories/appeal_repository.dart';
import '../repositories/ban_repository.dart';
import '../services/admin_service.dart';

class AdminAppealDetailPage extends StatefulWidget {
  const AdminAppealDetailPage({
    super.key,
    required this.appealId,
  });

  final String appealId;

  @override
  State<AdminAppealDetailPage> createState() => _AdminAppealDetailPageState();
}

class _AdminAppealDetailPageState extends State<AdminAppealDetailPage> {
  final AppealRepository _appealRepository = AppealRepository();
  final BanRepository _banRepository = BanRepository();
  final AdminService _adminService = AdminService();
  Appeal? _appeal;
  Ban? _ban;
  bool _isLoading = true;
  bool _isProcessing = false;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAppeal();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAppeal() async {
    final appeal = await _appealRepository.getAppeal(widget.appealId);
    if (appeal != null) {
      final ban = await _banRepository.getBan(appeal.banId);
      setState(() {
        _appeal = appeal;
        _ban = ban;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _processAppeal(AppealDecision decision) async {
    if (_appeal == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final adminUid = authRepository.currentUser()?.uid;
      if (adminUid == null) {
        throw StateError('Bạn cần đăng nhập');
      }

      await _adminService.processAppeal(
        widget.appealId,
        decision: decision,
        adminUid: adminUid,
        adminNotes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision == AppealDecision.approve
                  ? 'Đã chấp nhận đơn kháng cáo'
                  : 'Đã từ chối đơn kháng cáo',
            ),
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
        appBar: AppBar(title: const Text('Chi tiết đơn kháng cáo')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_appeal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết đơn kháng cáo')),
        body: const Center(child: Text('Không tìm thấy đơn kháng cáo')),
      );
    }

    final appeal = _appeal!;
    final isPending = appeal.status == AppealStatus.pending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đơn kháng cáo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Xem profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PublicProfilePage(uid: appeal.uid),
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
                color: _getStatusColor(appeal.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getStatusColor(appeal.status),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(appeal.status),
                    color: _getStatusColor(appeal.status),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getStatusText(appeal.status),
                    style: TextStyle(
                      color: _getStatusColor(appeal.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Appeal info
            _buildInfoRow('UID người dùng', appeal.uid),
            _buildInfoRow('Ban ID', appeal.banId),
            if (_ban != null) ...[
              _buildInfoRow('Lý do ban', _ban!.reason),
              _buildInfoRow(
                'Loại ban',
                _ban!.banType == BanType.permanent
                    ? 'Vĩnh viễn'
                    : 'Tạm thời',
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Lý do kháng cáo',
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
              child: Text(appeal.reason),
            ),
            if (appeal.evidence.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Bằng chứng',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...appeal.evidence.map((url) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Image.network(url),
                  )),
            ],
            if (appeal.createdAt != null)
              _buildInfoRow('Thời gian tạo', _formatDate(appeal.createdAt!)),
            if (appeal.reviewedBy != null)
              _buildInfoRow('Xử lý bởi', appeal.reviewedBy!),
            if (appeal.reviewedAt != null)
              _buildInfoRow(
                'Thời gian xử lý',
                _formatDate(appeal.reviewedAt!),
              ),
            if (appeal.adminNotes != null) ...[
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
                child: Text(appeal.adminNotes!),
              ),
            ],
            // Action buttons
            if (isPending) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Ghi chú (tùy chọn)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Nhập ghi chú...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Chấp nhận'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isProcessing
                      ? null
                      : () => _processAppeal(AppealDecision.approve),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Từ chối'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isProcessing
                      ? null
                      : () => _processAppeal(AppealDecision.reject),
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

  Color _getStatusColor(AppealStatus status) {
    switch (status) {
      case AppealStatus.pending:
        return Colors.orange;
      case AppealStatus.approved:
        return Colors.green;
      case AppealStatus.rejected:
        return Colors.red;
    }
  }

  String _getStatusText(AppealStatus status) {
    switch (status) {
      case AppealStatus.pending:
        return 'Chờ xử lý';
      case AppealStatus.approved:
        return 'Đã chấp nhận';
      case AppealStatus.rejected:
        return 'Đã từ chối';
    }
  }

  IconData _getStatusIcon(AppealStatus status) {
    switch (status) {
      case AppealStatus.pending:
        return Icons.pending;
      case AppealStatus.approved:
        return Icons.check_circle;
      case AppealStatus.rejected:
        return Icons.cancel;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

