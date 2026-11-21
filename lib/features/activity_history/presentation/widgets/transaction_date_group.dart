import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_transaction_entity.dart';
import 'package:shiftex/features/activity_history/presentation/widgets/transaction_history_card.dart';

class ActivityDateSection {
  final String headerLabel;
  final List<ActivityTransactionEntity> transactions;

  const ActivityDateSection({
    required this.headerLabel,
    required this.transactions,
  });
}

class TransactionDateGrouper {
  const TransactionDateGrouper._();

  static const List<String> _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _fullMonths = [
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER',
  ];

  static String _formatDayMonthYear(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')} ${_shortMonths[dt.month - 1]} ${dt.year}';
  }

  static String _formatDayMonth(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')} ${_shortMonths[dt.month - 1]}';
  }

  /// Groups chronologically sorted ledger entries by TODAY, YESTERDAY,
  /// THIS WEEK (with actual date range), and older MONTH YEAR sections.
  static List<ActivityDateSection> group(
    List<ActivityTransactionEntity> items, {
    DateTime? nowLocal,
  }) {
    if (items.isEmpty) return const [];

    final ref = nowLocal ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final thisWeekEnd = yesterday.subtract(const Duration(days: 1));

    final map = <String, List<ActivityTransactionEntity>>{};
    final order = <String>[];

    for (final item in items) {
      final local = item.createdAt.toLocal();
      final itemDate = DateTime(local.year, local.month, local.day);
      final String label;

      if (itemDate == today) {
        label = 'TODAY — ${_formatDayMonthYear(today)}';
      } else if (itemDate == yesterday) {
        label = 'YESTERDAY — ${_formatDayMonthYear(yesterday)}';
      } else if (!itemDate.isBefore(weekStart) &&
          itemDate.isBefore(yesterday)) {
        label =
            'THIS WEEK — ${_formatDayMonth(weekStart)} – ${_formatDayMonth(thisWeekEnd)}';
      } else {
        label = '${_fullMonths[itemDate.month - 1]} ${itemDate.year}';
      }

      if (!map.containsKey(label)) {
        map[label] = [];
        order.add(label);
      }
      map[label]!.add(item);
    }

    return [
      for (final label in order)
        ActivityDateSection(headerLabel: label, transactions: map[label]!),
    ];
  }
}

/// Renders one dated group section header and its transaction cards.
class TransactionDateGroup extends StatelessWidget {
  final ActivityDateSection section;
  final Set<String> expandedIds;
  final Set<String> loadingDetailIds;
  final ValueChanged<String> onToggleExpand;

  const TransactionDateGroup({
    super.key,
    required this.section,
    required this.expandedIds,
    required this.loadingDetailIds,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            section.headerLabel,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.65,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        for (int i = 0; i < section.transactions.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          TransactionHistoryCard(
            transaction: section.transactions[i],
            isExpanded: expandedIds.contains(section.transactions[i].id),
            isLoadingDetail: loadingDetailIds.contains(
              section.transactions[i].id,
            ),
            onToggleExpand:
                () => onToggleExpand(section.transactions[i].id),
          ),
        ],
      ],
    );
  }
}
