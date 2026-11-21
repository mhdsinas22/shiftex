import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_filter.dart';

/// Filter tabs matching the customer ledger categories:
/// All, Earned (+), Claims (-), Daily Streak.
class HistoryFilterBar extends StatelessWidget {
  final ActivityFilter selectedFilter;
  final ValueChanged<ActivityFilter> onFilterChanged;

  const HistoryFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: ActivityFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = ActivityFilter.values[index];
          final isSelected = filter == selectedFilter;

          return Material(
            color:
                isSelected ? AppColors.primaryButtonDark : AppColors.white,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onFilterChanged(filter),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 9,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color:
                        isSelected
                            ? AppColors.primaryButtonDark
                            : AppColors.divider,
                  ),
                ),
                child: Text(
                  filter.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w600,
                    color:
                        isSelected ? AppColors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
