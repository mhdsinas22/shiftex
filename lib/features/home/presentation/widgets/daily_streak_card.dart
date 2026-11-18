import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';
import 'package:shiftex/features/home/domain/entities/daily_streak_entity.dart';
import 'package:shiftex/features/home/presentation/widgets/daily_streak_day_node.dart';

class DailyStreakCard extends StatelessWidget {
  final DailyStreakEntity streak;

  const DailyStreakCard({
    super.key,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final currentDay = streak.currentStreakDay.clamp(0, 7);
    final daysLeft = streak.daysRemaining;
    final subtitleText =
        streak.claimedToday
            ? 'Claimed +${streak.dailyPoints} pts today • ${daysLeft == 0 ? 'Streak complete!' : '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left'}'
            : 'Check in daily • +${streak.dailyPoints} pts per day (${streak.totalStreakTargetPoints} pts on Day 7)';

    final footerRightText =
        daysLeft == 0
            ? '${streak.totalStreakTargetPoints} pts locked'
            : '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} to bonus';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(responsive.isSmallWidth ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFF4F46E5),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$currentDay Day Streak 🔥',
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxNodeWidth = constraints.maxWidth / 7;
                final circleSize = math.min(
                  35.0,
                  math.max(26.0, maxNodeWidth - 6),
                );

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    return Expanded(
                      child: Center(
                        child: DailyStreakDayNode(
                          dayNumber: index + 1,
                          currentStreakDay: currentDay,
                          circleSize: circleSize,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 15,
                    color: AppColors.primaryBlue,
                  ),
                  SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Next streak unlocks at 06:00 AM',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                footerRightText,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
