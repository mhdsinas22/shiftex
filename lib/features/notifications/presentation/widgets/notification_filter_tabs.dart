import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_entity.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_filter.dart';

class NotificationFilterTabs extends StatelessWidget {
  final NotificationFilter activeFilter;
  final NotificationCountsEntity counts;
  final ValueChanged<NotificationFilter> onFilterSelected;

  const NotificationFilterTabs({
    super.key,
    required this.activeFilter,
    required this.counts,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 360 ? 16.0 : 20.0;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 2,
        ),
        itemCount: NotificationFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = NotificationFilter.values[index];
          final isSelected = filter == activeFilter;
          return _FilterChipPill(
            filter: filter,
            isSelected: isSelected,
            count: counts.countFor(filter),
            onTap: () => onFilterSelected(filter),
          );
        },
      ),
    );
  }
}

class _FilterChipPill extends StatelessWidget {
  final NotificationFilter filter;
  final bool isSelected;
  final int count;
  final VoidCallback onTap;

  const _FilterChipPill({
    required this.filter,
    required this.isSelected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final showCount =
        filter == NotificationFilter.all || filter == NotificationFilter.unread;

    final labelColor =
        isSelected ? AppColors.white : const Color(0xFF344054);

    final countColor = isSelected
        ? (filter == NotificationFilter.unread
            ? const Color(0xFF93C5FD)
            : const Color(0xFFB8C1D1))
        : (filter == NotificationFilter.unread
            ? AppColors.primaryBlue
            : AppColors.textSecondary);

    return Material(
      color: isSelected ? AppColors.primaryButtonDark : AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: Key('notification_filter_${filter.apiValue}'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryButtonDark
                  : AppColors.divider,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: filter.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
                if (showCount)
                  TextSpan(
                    text: '  ($count)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: countColor,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}
