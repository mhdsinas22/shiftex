import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';
import 'package:shiftex/features/home/domain/entities/wallet_summary_entity.dart';
import 'package:shiftex/features/home/presentation/widgets/home_formatters.dart';

class AvailableBalanceCard extends StatelessWidget {
  final WalletSummaryEntity wallet;
  final VoidCallback onClaimRewardsTap;

  const AvailableBalanceCard({
    super.key,
    required this.wallet,
    required this.onClaimRewardsTap,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final pointsFontSize = responsive.isSmallWidth ? 32.0 : 38.0;
    final formattedPoints = HomeFormatters.formatPoints(wallet.availablePoints);
    final todayBadgeText =
        '↑ +${HomeFormatters.formatPoints(wallet.pointsEarnedToday)} pts today';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(responsive.isSmallWidth ? 18 : 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0055D8), Color(0xFF287CFA), Color(0xFFB3D5FF)],
          stops: [0.0, 0.58, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0055D8).withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF8EF63C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monetization_on_rounded,
                      size: 14,
                      color: Color(0xFF0B2405),
                    ),
                    SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Available Balance',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0B2405),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Instant Wallet',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: formattedPoints,
                  style: TextStyle(
                    fontSize: pointsFontSize,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                    letterSpacing: -1.0,
                    height: 1.08,
                  ),
                ),
                const TextSpan(
                  text: ' pts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D254C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 3.5,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF82F03A),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              todayBadgeText,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0B2405),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: const Color(0xFF6BA6FA).withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onClaimRewardsTap,
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.42),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Claim Rewards',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: AppColors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
