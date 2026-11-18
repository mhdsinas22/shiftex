import 'package:flutter/material.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';
import 'package:shiftex/features/home/domain/entities/locked_point_allocation_entity.dart';
import 'package:shiftex/features/home/domain/entities/wallet_summary_entity.dart';
import 'package:shiftex/features/home/presentation/widgets/home_formatters.dart';

class LockedPointsCard extends StatelessWidget {
  final WalletSummaryEntity wallet;
  final LockedPointAllocationEntity? nextAllocation;

  const LockedPointsCard({
    super.key,
    required this.wallet,
    this.nextAllocation,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final now = DateTime.now().toUtc();
    final lockedPts = HomeFormatters.formatPoints(wallet.lockedPoints);
    final lockedInr = HomeFormatters.formatInr(wallet.lockedInr);

    final hasLocked = wallet.lockedPoints > 0 && nextAllocation != null;
    final countdownStr =
        hasLocked
            ? HomeFormatters.formatCountdown(
              nextAllocation!.remainingDuration(now),
            )
            : null;
    final unlockDateStr =
        hasLocked
            ? HomeFormatters.formatUnlockDateTime(nextAllocation!.unlockAt)
            : null;

    final progressFraction =
        hasLocked ? nextAllocation!.progressFraction(now) : 0.0;
    final progressPct = hasLocked ? nextAllocation!.progressPercent(now) : 0;

    final clearanceLabel =
        hasLocked && nextAllocation!.sourceType == 'merchant_settlement'
            ? 'Merchant settlement clearance'
            : '7-Day Streak lock clearance';

    final explanationCopy =
        hasLocked
            ? 'Locked points automatically transfer into your available wallet balance once the 7-day verification and settlement lock completes.'
            : 'Complete 7 consecutive daily check-ins to lock your full 7-day streak reward. Locked allocations automatically transfer to available balance after 7 days.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(responsive.isSmallWidth ? 16 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF0C2),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFF4DD9A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_clock_outlined,
                  color: Color(0xFF8A4511),
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          '$lockedPts pts locked',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7C370B),
                            letterSpacing: -0.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4DD9A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '≈ $lockedInr',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7C370B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasLocked
                          ? 'Unlocks in $countdownStr ($unlockDateStr)'
                          : 'No active locked allocations • Unlocks 7 days after streak completion',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFA85823),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  clearanceLabel,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C370B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$progressPct%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7C370B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressFraction,
              minHeight: 7,
              backgroundColor: const Color(0xFFEED694),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF9A4B16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            explanationCopy,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF934A19),
              height: 1.42,
            ),
          ),
        ],
      ),
    );
  }
}
