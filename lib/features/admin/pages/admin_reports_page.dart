import 'package:flutter/material.dart';

import '../../safety/models/report.dart' as report_models;
import '../../safety/repositories/report_repository.dart';
import '../widgets/index_error_view.dart';
import 'admin_report_detail_page.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  final ReportRepository _reportRepository = ReportRepository();
  String _filterStatus = 'all'; // all, pending, resolved, rejected

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter buttons
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildFilterChip('all', 'Tất cả'),
              const SizedBox(width: 8),
              _buildFilterChip('pending', 'Chờ xử lý'),
              const SizedBox(width: 8),
              _buildFilterChip('resolved', 'Đã xử lý'),
              const SizedBox(width: 8),
              _buildFilterChip('rejected', 'Từ chối'),
            ],
          ),
        ),
        const Divider(height: 1),
        // Reports list
        Expanded(
          child: StreamBuilder<List<report_models.Report>>(
            stream: _filterStatus == 'all'
                ? _reportRepository.watchReports()
                : _reportRepository.watchReports(
                    status: _parseStatus(_filterStatus),
                  ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return IndexErrorView(
                  error: snapshot.error!,
                  title: 'Không thể tải danh sách báo cáo',
                );
              }

              final reports = snapshot.data ?? [];

              if (reports.isEmpty) {
                return const Center(
                  child: Text('Không có báo cáo nào'),
                );
              }

              return ListView.builder(
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  return _ReportListItem(
                    report: report,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AdminReportDetailPage(
                            reportId: report.id,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filterStatus = value;
          });
        }
      },
    );
  }

  report_models.ReportStatus? _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return report_models.ReportStatus.pending;
      case 'resolved':
        return report_models.ReportStatus.resolved;
      case 'rejected':
        return report_models.ReportStatus.rejected;
      default:
        return null;
    }
  }
}

class _ReportListItem extends StatelessWidget {
  const _ReportListItem({
    required this.report,
    required this.onTap,
  });

  final report_models.Report report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(report.reportStatus);
    final statusText = _getStatusText(report.reportStatus);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withOpacity(0.2),
        child: Icon(
          _getStatusIcon(report.reportStatus),
          color: statusColor,
        ),
      ),
      title: Text(
        'Báo cáo ${_getTargetTypeText(report.targetType)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (report.reason != null) ...[
            const SizedBox(height: 4),
            Text(
              report.reason!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (report.createdAt != null) ...[
            const SizedBox(height: 2),
            Text(
              _formatDate(report.createdAt!),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
        return 'người dùng';
      case report_models.ReportTargetType.post:
        return 'bài đăng';
      case report_models.ReportTargetType.comment:
        return 'bình luận';
      case report_models.ReportTargetType.story:
        return 'story';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} ngày trước';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }
}

