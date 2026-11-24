import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_wallet_summary_entity.dart';
import 'package:shiftex/features/home/presentation/widgets/home_formatters.dart';

/// Displays Net Available Balance (with live rate conversion),
/// Lifetime Earned, Total Redeemed (historical INR), and reconciliation notices.
class WalletSummaryCard extends StatelessWidget {
  final ActivityWalletSummaryEntity summary;

  const WalletSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final availablePts = HomeFormatters.formatPoints(
      summary.netAvailablePoints,
    );
    final earnedPts = HomeFormatters.formatPoints(summary.lifetimeEarnedPoints);
    final redeemedPts = HomeFormatters.formatPoints(
      summary.totalRedeemedPoints,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(responsive.isSmallWidth ? 16 : 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0051C4),
                Color(0xFF1D63ED),
                Color(0xFF3E8BFF),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.24),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8EF63C),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 13.5,
                            color: Color(0xFF0B2405),
                          ),
                          SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Net Available Balance',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0B2405),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Points Wallet',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOnBlueMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '$availablePts pts',
                style: TextStyle(
                  fontSize: responsive.isSmallWidth ? 28 : 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                  letterSpacing: -0.8,
                  height: 1.08,
                ),
              ),
              if (summary.lockedPoints > 0 || summary.reservedPoints > 0) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (summary.lockedPoints > 0)
                      _buildStatusChip(
                        icon: Icons.lock_clock_outlined,
                        label:
                            '${HomeFormatters.formatPoints(summary.lockedPoints)} pts Locked',
                      ),
                    if (summary.reservedPoints > 0)
                      _buildStatusChip(
                        icon: Icons.qr_code_2_rounded,
                        label:
                            '${HomeFormatters.formatPoints(summary.reservedPoints)} pts Pending Claim',
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatTile(
                      label: 'Lifetime Earned',
                      primaryValue: '$earnedPts pts',
                      accentColor: const Color(0xFF8EF63C),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatTile(
                      label: 'Total Redeemed',
                      primaryValue: '$redeemedPts pts',
                      accentColor: AppColors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (summary.reconciliation.hasDiscrepancy) ...[
          const SizedBox(height: 10),
          _buildReconciliationBanner(),
        ],
      ],
    );
  }

  Widget _buildStatusChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required String label,
    required String primaryValue,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textOnBlueMuted,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              primaryValue,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReconciliationBanner() {
    final rec = summary.reconciliation;
    final parts = <String>[];
    if (rec.availableOffsetPoints != 0) {
      final sign = rec.availableOffsetPoints > 0 ? '+' : '';
      parts.add('$sign${rec.availableOffsetPoints} available pts');
    }
    if (rec.lockedOffsetPoints != 0) {
      final sign = rec.lockedOffsetPoints > 0 ? '+' : '';
      parts.add('$sign${rec.lockedOffsetPoints} locked pts');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.pendingBadgeBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.pendingBadgeText.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.pendingBadgeText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ledger reconciliation note: Current wallet includes an opening/off-ledger variance of ${parts.join(', ')} relative to immutable ledger entries.',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.pendingBadgeText,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
