import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/home/domain/entities/home_dashboard_entity.dart';
import 'package:shiftex/features/home/presentation/widgets/recent_reward_tile.dart';

class TransactionsHistoryView extends StatelessWidget {
  final HomeDashboardEntity dashboard;
  final VoidCallback onBackToHome;

  const TransactionsHistoryView({
    super.key,
    required this.dashboard,
    required this.onBackToHome,
  });

  @override
  Widget build(BuildContext context) {
    final transactions = dashboard.recentTransactions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'Reward History',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onBackToHome,
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: const Text('Dashboard'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Showing all point transactions for ${dashboard.wallet.customerCode}',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        if (transactions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 32,
                  color: AppColors.textTertiary,
                ),
                SizedBox(height: 10),
                Text(
                  'No transactions recorded yet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          )
        else
          for (int i = 0; i < transactions.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            RecentRewardTile(
              transaction: transactions[i],
              pointsToInrRate: dashboard.wallet.pointsToInrRate,
            ),
          ],
      ],
    );
  }
}
