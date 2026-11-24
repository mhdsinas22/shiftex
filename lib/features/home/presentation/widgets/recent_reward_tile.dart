import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/home/domain/entities/point_transaction_entity.dart';
import 'package:shiftex/features/home/presentation/widgets/home_formatters.dart';

class RecentRewardTile extends StatelessWidget {
  final PointTransactionEntity transaction;
  final double pointsToInrRate;

  const RecentRewardTile({
    super.key,
    required this.transaction,
    required this.pointsToInrRate,
  });

  IconData get _icon {
    switch (transaction.type) {
      case PointTransactionType.merchantReward:
        return Icons.storefront_rounded;
      case PointTransactionType.discountRedemption:
        return Icons.confirmation_number_outlined;
      case PointTransactionType.pointAdjustment:
        return Icons.tune_rounded;
      case PointTransactionType.streakUnlock:
      case PointTransactionType.dailyStreak:
        return Icons.bolt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.isCredit;
    final ptsStr =
        '${isCredit ? '+' : ''}${HomeFormatters.formatPoints(transaction.pointsDelta)} pts';
    final timeStr = HomeFormatters.formatRelativeTimestamp(
      transaction.createdAt,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _icon,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  HomeFormatters.stripCurrencyCopy(transaction.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeStr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            ptsStr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color:
                  isCredit
                      ? const Color(0xFF15803D)
                      : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
