import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';
import 'package:shiftex/features/home/domain/entities/point_transaction_entity.dart';
import 'package:shiftex/features/home/presentation/widgets/recent_reward_tile.dart';

class RecentRewardsSection extends StatelessWidget {
  final List<PointTransactionEntity> transactions;
  final double pointsToInrRate;
  final VoidCallback onViewAllTap;

  const RecentRewardsSection({
    super.key,
    required this.transactions,
    required this.pointsToInrRate,
    required this.onViewAllTap,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final displayed = transactions.take(5).toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(responsive.isSmallWidth ? 16 : 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE4F0FF),
            Color(0xFFB5D4FD),
            Color(0xFF4C92F7),
          ],
          stops: [0.0, 0.65, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Recent Rewards',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onViewAllTap,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (displayed.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 26,
                    color: AppColors.primaryBlue,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No reward activity yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your daily streak check-ins, merchant rewards, and redemptions will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          else
            for (int i = 0; i < displayed.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              RecentRewardTile(
                transaction: displayed[i],
                pointsToInrRate: pointsToInrRate,
              ),
            ],
        ],
      ),
    );
  }
}
