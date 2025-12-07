import 'package:flutter/material.dart';

import '../models/appeal.dart';
import '../repositories/appeal_repository.dart';
import '../widgets/index_error_view.dart';
import 'admin_appeal_detail_page.dart';

class AdminAppealsPage extends StatefulWidget {
  const AdminAppealsPage({super.key});

  @override
  State<AdminAppealsPage> createState() => _AdminAppealsPageState();
}

class _AdminAppealsPageState extends State<AdminAppealsPage> {
  final AppealRepository _appealRepository = AppealRepository();
  String _filterStatus = 'all'; // all, pending, approved, rejected

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
              _buildFilterChip('approved', 'Đã chấp nhận'),
              const SizedBox(width: 8),
              _buildFilterChip('rejected', 'Đã từ chối'),
            ],
          ),
        ),
        const Divider(height: 1),
        // Appeals list
        Expanded(
          child: StreamBuilder<List<Appeal>>(
            stream: _filterStatus == 'all'
                ? _appealRepository.watchAllAppeals()
                : _appealRepository.watchAllAppeals(
                    status: _parseStatus(_filterStatus),
                  ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return IndexErrorView(
                  error: snapshot.error!,
                  title: 'Không thể tải danh sách kháng cáo',
                );
              }

              final appeals = snapshot.data ?? [];

              if (appeals.isEmpty) {
                return const Center(
                  child: Text('Không có đơn kháng cáo nào'),
                );
              }

              return ListView.builder(
                itemCount: appeals.length,
                itemBuilder: (context, index) {
                  final appeal = appeals[index];
                  return _AppealListItem(
                    appeal: appeal,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AdminAppealDetailPage(
                            appealId: appeal.id,
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

  AppealStatus? _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return AppealStatus.pending;
      case 'approved':
        return AppealStatus.approved;
      case 'rejected':
        return AppealStatus.rejected;
      default:
        return null;
    }
  }
}

class _AppealListItem extends StatelessWidget {
  const _AppealListItem({
    required this.appeal,
    required this.onTap,
  });

  final Appeal appeal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(appeal.status);
    final statusText = _getStatusText(appeal.status);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withOpacity(0.2),
        child: Icon(
          _getStatusIcon(appeal.status),
          color: statusColor,
        ),
      ),
      title: Text(
        'UID: ${appeal.uid}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            appeal.reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (appeal.createdAt != null) ...[
            const SizedBox(height: 2),
            Text(
              _formatDate(appeal.createdAt),
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

