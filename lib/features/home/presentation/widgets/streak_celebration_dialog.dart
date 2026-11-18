import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/widgets/shiiftex_primary_button.dart';
import 'package:shiftex/features/home/domain/entities/daily_streak_entity.dart';
import 'package:shiftex/features/home/presentation/widgets/daily_streak_day_node.dart';
import 'package:shiftex/features/home/presentation/widgets/home_formatters.dart';

class StreakCelebrationDialog extends StatelessWidget {
  final DailyStreakEntity streak;
  final VoidCallback onContinue;

  const StreakCelebrationDialog({
    super.key,
    required this.streak,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final totalPoints =
        streak.completedStreakPoints > 0
            ? streak.completedStreakPoints
            : streak.totalStreakTargetPoints;
    final unlockDate =
        streak.completedUnlockAt ??
        DateTime.now().toUtc().add(const Duration(days: 7));
    final unlockDateStr = HomeFormatters.formatUnlockDateTime(unlockDate);

    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.92, end: 1.0),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF287CFA),
                      Color(0xFF0055D8),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '7-Day Streak Completed!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Congratulations! You've completed seven consecutive days.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              // Seven completed day indicators
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(7, (index) {
                    return Expanded(
                      child: Center(
                        child: DailyStreakDayNode(
                          dayNumber: index + 1,
                          currentStreakDay: 7,
                          circleSize: 28,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 18),
              // Total points earned & locked summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF0C2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      '+$totalPoints pts Earned & Locked',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7C370B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${streak.dailyPoints} pts × 7 consecutive days = $totalPoints pts locked',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFA85823),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: Color(0xFFEED694), height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock_clock_outlined,
                          size: 16,
                          color: Color(0xFF7C370B),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Expected unlock: $unlockDateStr',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7C370B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your completed 7-day streak allocation is locked for 7 days and will automatically transfer into your available wallet balance.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF934A19),
                        height: 1.38,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ShiiftexPrimaryButton(
                label: 'Continue',
                showTrailingArrow: false,
                onPressed: onContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
