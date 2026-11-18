import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/home/presentation/widgets/home_formatters.dart';

/// Displays the disabled/expired QR notice once a single-use claim expires
/// and offers generating a new claim using the released points.
class ClaimExpiredView extends StatelessWidget {
  final String claimReference;
  final int points;
  final bool isCancelled;
  final VoidCallback onGenerateNewClaim;

  const ClaimExpiredView({
    super.key,
    required this.claimReference,
    required this.points,
    this.isCancelled = false,
    required this.onGenerateNewClaim,
  });

  @override
  Widget build(BuildContext context) {
    final ptsFormatted = HomeFormatters.formatPoints(points);
    final title =
        isCancelled ? 'Claim Cancelled' : 'This Claim QR Has Expired';
    final description =
        '$ptsFormatted reserved pts have been released back to your instant available balance.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.errorBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.errorSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.qr_code_2_rounded,
              size: 28,
              color: AppColors.errorRed,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            claimReference,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.errorRed,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onGenerateNewClaim,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: AppColors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text(
              'Generate New Claim',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
