import 'package:flutter/material.dart';

import '../models/feed_filters.dart';

class FeedFilterChips extends StatelessWidget {
  const FeedFilterChips({
    super.key,
    required this.filters,
    this.onRemoveFilter,
    this.onTap,
  });

  final FeedFilters filters;
  final void Function(FeedFilters)? onRemoveFilter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (filters.isDefault) {
      return const SizedBox.shrink();
    }

    final chips = <Widget>[];

    // Media filter chip
    if (filters.mediaFilter != PostMediaFilter.all) {
      chips.add(_buildChip(
        context,
        label: filters.getMediaFilterName(),
        onDeleted: () {
          onRemoveFilter?.call(
            filters.copyWith(mediaFilter: PostMediaFilter.all),
          );
        },
      ));
    }

    // Time filter chip
    if (filters.timeFilter != TimeFilter.all) {
      chips.add(_buildChip(
        context,
        label: filters.getTimeFilterName(),
        onDeleted: () {
          onRemoveFilter?.call(
            filters.copyWith(timeFilter: TimeFilter.all),
          );
        },
      ));
    }

    // Sort option chip
    if (filters.sortOption != PostSortOption.newest) {
      chips.add(_buildChip(
        context,
        label: filters.getSortOptionName(),
        onDeleted: () {
          onRemoveFilter?.call(
            filters.copyWith(sortOption: PostSortOption.newest),
          );
        },
      ));
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...chips,
                  if (chips.length > 1)
                    TextButton(
                      onPressed: () {
                        onRemoveFilter?.call(filters.reset());
                      },
                      child: const Text('Xóa tất cả'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    VoidCallback? onDeleted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(label),
        onDeleted: onDeleted,
        onPressed: onTap,
        deleteIcon: const Icon(Icons.close, size: 18),
      ),
    );
  }
}

