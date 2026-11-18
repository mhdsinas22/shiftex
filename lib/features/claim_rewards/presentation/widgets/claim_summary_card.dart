import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/home/presentation/widgets/home_formatters.dart';

/// Displays calculated claim deduction, INR discount value, and remaining
/// instant available balance before generating the Claim QR.
class ClaimSummaryCard extends StatelessWidget {
  final int pointsToDeduct;
  final double discountInr;
  final int remainingBalance;
  final double remainingBalanceInr;

  const ClaimSummaryCard({
    super.key,
    required this.pointsToDeduct,
    required this.discountInr,
    required this.remainingBalance,
    required this.remainingBalanceInr,
  });

  @override
  Widget build(BuildContext context) {
    final ptsStr = '${HomeFormatters.formatPoints(pointsToDeduct)} pts';
    final discountStr = '${HomeFormatters.formatInr(discountInr)} Off Bill';
    final remPtsStr = '${HomeFormatters.formatPoints(remainingBalance)} pts';
    final remInrStr = HomeFormatters.formatInr(remainingBalanceInr);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSummaryRow(
            label: 'Points to Deduct',
            valueWidget: Text(
              ptsStr,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            label: 'Instant Discount Value',
            valueWidget: Text(
              discountStr,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF15803D),
              ),
            ),
          ),
          const Divider(height: 22, thickness: 1, color: AppColors.divider),
          _buildSummaryRow(
            label: 'Remaining Available Balance',
            valueWidget: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: remPtsStr,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: ' ($remInrStr)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required Widget valueWidget,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(child: valueWidget),
      ],
    );
  }
}
