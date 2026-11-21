import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';

/// Displays the compact `Xs` countdown badge with a blue circular progress
/// ring matching the modern light-pill popup header design.
class AdvertisementCountdown extends StatelessWidget {
  final int remainingSeconds;
  final int totalSeconds;

  const AdvertisementCountdown({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final safeTotal = totalSeconds <= 0 ? 1 : totalSeconds;
    final clampedRemaining = remainingSeconds.clamp(0, safeTotal);
    final progress = clampedRemaining / safeTotal;
    final labelText = '${clampedRemaining}s';

    return Semantics(
      label: 'Advertisement closes automatically in $clampedRemaining seconds',
      liveRegion: true,
      child: Container(
        key: const ValueKey('advertisement_countdown_badge'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2.2,
                backgroundColor: const Color(0xFFD0D5DD),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primaryBlue,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              labelText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475467),
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
