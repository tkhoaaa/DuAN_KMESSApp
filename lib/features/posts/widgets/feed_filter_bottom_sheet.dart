import 'package:flutter/material.dart';

import '../models/feed_filters.dart';

class FeedFilterBottomSheet extends StatefulWidget {
  const FeedFilterBottomSheet({
    super.key,
    required this.initialFilters,
    required this.onApply,
  });

  final FeedFilters initialFilters;
  final void Function(FeedFilters) onApply;

  @override
  State<FeedFilterBottomSheet> createState() => _FeedFilterBottomSheetState();
}

class _FeedFilterBottomSheetState extends State<FeedFilterBottomSheet> {
  late FeedFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lọc & Sắp xếp',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filters = _filters.reset();
                        });
                      },
                      child: const Text('Đặt lại'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Media Filter Section
                      _buildSectionTitle('Loại media'),
                      const SizedBox(height: 8),
                      _buildMediaFilterOptions(),
                      const SizedBox(height: 24),
                      // Time Filter Section
                      _buildSectionTitle('Thời gian'),
                      const SizedBox(height: 8),
                      _buildTimeFilterOptions(),
                      const SizedBox(height: 24),
                      // Sort Option Section
                      _buildSectionTitle('Sắp xếp'),
                      const SizedBox(height: 8),
                      _buildSortOptions(),
                    ],
                  ),
                ),
              ),
              // Bottom actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onApply(_filters);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Áp dụng'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildMediaFilterOptions() {
    return Column(
      children: PostMediaFilter.values.map((filter) {
        return RadioListTile<PostMediaFilter>(
          title: Text(_getMediaFilterName(filter)),
          value: filter,
          groupValue: _filters.mediaFilter,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _filters = _filters.copyWith(mediaFilter: value);
              });
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildTimeFilterOptions() {
    return Column(
      children: TimeFilter.values.map((filter) {
        return RadioListTile<TimeFilter>(
          title: Text(_getTimeFilterName(filter)),
          value: filter,
          groupValue: _filters.timeFilter,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _filters = _filters.copyWith(timeFilter: value);
              });
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildSortOptions() {
    return Column(
      children: PostSortOption.values.map((option) {
        return RadioListTile<PostSortOption>(
          title: Text(_getSortOptionName(option)),
          value: option,
          groupValue: _filters.sortOption,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _filters = _filters.copyWith(sortOption: value);
              });
            }
          },
        );
      }).toList(),
    );
  }

  String _getMediaFilterName(PostMediaFilter filter) {
    switch (filter) {
      case PostMediaFilter.all:
        return 'Tất cả';
      case PostMediaFilter.images:
        return 'Chỉ ảnh';
      case PostMediaFilter.videos:
        return 'Chỉ video';
    }
  }

  String _getTimeFilterName(TimeFilter filter) {
    switch (filter) {
      case TimeFilter.all:
        return 'Tất cả';
      case TimeFilter.today:
        return 'Hôm nay';
      case TimeFilter.thisWeek:
        return 'Tuần này';
      case TimeFilter.thisMonth:
        return 'Tháng này';
    }
  }

  String _getSortOptionName(PostSortOption option) {
    switch (option) {
      case PostSortOption.newest:
        return 'Mới nhất';
      case PostSortOption.mostLiked:
        return 'Nhiều like nhất';
      case PostSortOption.mostCommented:
        return 'Nhiều comment nhất';
    }
  }
}

