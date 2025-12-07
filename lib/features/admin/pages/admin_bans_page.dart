import 'package:flutter/material.dart';

import '../models/ban.dart';
import '../repositories/ban_repository.dart';
import '../widgets/index_error_view.dart';
import '../../profile/user_profile_repository.dart';
import 'admin_ban_detail_page.dart';

class AdminBansPage extends StatefulWidget {
  const AdminBansPage({super.key});

  @override
  State<AdminBansPage> createState() => _AdminBansPageState();
}

class _AdminBansPageState extends State<AdminBansPage> {
  final BanRepository _banRepository = BanRepository();
  String _filterType = 'all'; // all, active, inactive
  String _filterBanType = 'all'; // all, temporary, permanent

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter buttons
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  _buildFilterChip('all', 'Tất cả', _filterType, (v) {
                    setState(() {
                      _filterType = v;
                    });
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip('active', 'Đang khóa', _filterType, (v) {
                    setState(() {
                      _filterType = v;
                    });
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip('inactive', 'Đã mở', _filterType, (v) {
                    setState(() {
                      _filterType = v;
                    });
                  }),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildFilterChip('all', 'Tất cả', _filterBanType, (v) {
                    setState(() {
                      _filterBanType = v;
                    });
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip('temporary', 'Tạm thời', _filterBanType, (v) {
                    setState(() {
                      _filterBanType = v;
                    });
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip('permanent', 'Vĩnh viễn', _filterBanType, (v) {
                    setState(() {
                      _filterBanType = v;
                    });
                  }),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Bans list
        Expanded(
          child: StreamBuilder<List<Ban>>(
            stream: _banRepository.watchAllBans(
              banType: _filterBanType == 'all'
                  ? null
                  : (_filterBanType == 'temporary'
                      ? BanType.temporary
                      : BanType.permanent),
              isActive: _filterType == 'all'
                  ? null
                  : (_filterType == 'active'),
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return IndexErrorView(
                  error: snapshot.error!,
                  title: 'Không thể tải danh sách khóa tài khoản',
                );
              }

              final bans = snapshot.data ?? [];

              if (bans.isEmpty) {
                return const Center(
                  child: Text('Không có ban nào'),
                );
              }

              return ListView.builder(
                itemCount: bans.length,
                itemBuilder: (context, index) {
                  final ban = bans[index];
                  return _BanListItem(
                    ban: ban,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AdminBanDetailPage(
                            banId: ban.id,
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

  Widget _buildFilterChip(
    String value,
    String label,
    String currentValue,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = currentValue == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          onSelected(value);
        }
      },
    );
  }
}

class _BanListItem extends StatelessWidget {
  const _BanListItem({
    required this.ban,
    required this.onTap,
  });

  final Ban ban;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final banTypeColor = ban.banType == BanType.permanent
        ? Colors.red
        : Colors.orange;
    final banTypeText = ban.banType == BanType.permanent
        ? 'Vĩnh viễn'
        : 'Tạm thời';

    return FutureBuilder<UserProfile?>(
      future: userProfileRepository.fetchProfile(ban.uid),
      builder: (context, snapshot) {
        final displayName = snapshot.data?.displayName;
        final titleText = (displayName != null && displayName.isNotEmpty)
            ? '$displayName (${ban.uid})'
            : 'UID: ${ban.uid}';

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: banTypeColor.withOpacity(0.2),
            child: Icon(
              ban.banType == BanType.permanent
                  ? Icons.block
                  : Icons.schedule,
              color: banTypeColor,
            ),
          ),
          title: Text(
            titleText,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                ban.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: banTypeColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      banTypeText,
                      style: TextStyle(
                        color: banTypeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!ban.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Đã mở',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              if (ban.expiresAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Hết hạn: ${_formatDate(ban.expiresAt!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                'Khóa lúc: ${_formatDate(ban.bannedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

