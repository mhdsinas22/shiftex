import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_transaction_entity.dart';
import 'package:shiftex/features/home/presentation/widgets/home_formatters.dart';

/// Expandable breakdown showing instant available vs future locked points,
/// merchant bill details, unlock schedule, and allocation status.
class LockedPointsDetails extends StatelessWidget {
  final ActivityTransactionEntity transaction;

  const LockedPointsDetails({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final d = transaction.details;
    final instantPts =
        d.instantPoints > 0 ? d.instantPoints : transaction.availablePointsPart;
    final lockedPts =
        d.futureLockedPoints > 0
            ? d.futureLockedPoints
            : transaction.lockedPointsPart;
    final totalPts = transaction.pointsDelta;
    final isRelease = transaction.kind == ActivityKind.lockedRelease;

    final rows = <MapEntry<String, String>>[
      if (d.merchantName != null && d.merchantName!.isNotEmpty)
        MapEntry('Merchant / Branch', d.merchantName!),
      if (d.billNumber != null && d.billNumber!.isNotEmpty)
        MapEntry('Bill Reference', '#${d.billNumber!}'),
      if (d.purchaseAmount != null)
        MapEntry(
          'Purchase Amount',
          HomeFormatters.formatInr(d.purchaseAmount!),
        ),
      MapEntry(
        isRelease ? 'Released Points' : 'Total Points Credited',
        '+${HomeFormatters.formatPoints(totalPts)} pts',
      ),
      if (!isRelease) ...[
        MapEntry(
          'Instant Points (Available)',
          '${HomeFormatters.formatPoints(instantPts)} pts',
        ),
        MapEntry(
          'Future Points (Locked)',
          '${HomeFormatters.formatPoints(lockedPts)} pts',
        ),
      ],
      if (d.unlockAt != null)
        MapEntry(
          'Unlock Schedule',
          HomeFormatters.formatUnlockDateTime(d.unlockAt!),
        ),
      if (d.unlockedAt != null)
        MapEntry(
          'Unlocked On',
          HomeFormatters.formatUnlockDateTime(d.unlockedAt!),
        ),
      MapEntry(
        'Historical Value',
        '${HomeFormatters.formatInr(transaction.historicalInrValue)} (${transaction.historicalPointsPerRupee} pts = ₹1.00)',
      ),
      MapEntry(
        'Status',
        d.allocationStatus?.isNotEmpty == true
            ? '${transaction.status} (${d.allocationStatus})'
            : transaction.status,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRelease
                ? 'Locked Points Release Details'
                : 'Points Allocation Breakdown',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    rows[i].key,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: Text(
                    rows[i].value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
