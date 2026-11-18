import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';

class DailyStreakDayNode extends StatelessWidget {
  final int dayNumber;
  final int currentStreakDay;
  final double circleSize;

  const DailyStreakDayNode({
    super.key,
    required this.dayNumber,
    required this.currentStreakDay,
    this.circleSize = 34.0,
  });

  @override
  Widget build(BuildContext context) {
    final isPastCompleted =
        dayNumber < currentStreakDay ||
        (currentStreakDay == 7 && dayNumber <= 7);
    final isToday = dayNumber == currentStreakDay && currentStreakDay < 7;
    final isDay7Milestone = dayNumber == 7 && !isPastCompleted && !isToday;

    final String label = isToday ? 'Today' : 'D$dayNumber';
    final Color labelColor =
        isToday
            ? AppColors.primaryBlue
            : (isDay7Milestone
                ? const Color(0xFF7C3AED)
                : AppColors.textSecondary);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCircle(
          isPastCompleted: isPastCompleted,
          isToday: isToday,
          isDay7Milestone: isDay7Milestone,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight:
                isToday || isDay7Milestone ? FontWeight.w700 : FontWeight.w600,
            color: labelColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCircle({
    required bool isPastCompleted,
    required bool isToday,
    required bool isDay7Milestone,
  }) {
    if (isPastCompleted) {
      return Container(
        width: circleSize,
        height: circleSize,
        decoration: const BoxDecoration(
          color: AppColors.primaryButtonDark,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check_rounded,
          color: AppColors.white,
          size: circleSize * 0.5,
        ),
      );
    }

    if (isToday) {
      return Container(
        width: circleSize,
        height: circleSize,
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.28),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          Icons.local_fire_department_rounded,
          color: AppColors.white,
          size: circleSize * 0.52,
        ),
      );
    }

    if (isDay7Milestone) {
      return Container(
        width: circleSize,
        height: circleSize,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFC084FC),
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.stars_rounded,
          color: const Color(0xFF7C3AED),
          size: circleSize * 0.52,
        ),
      );
    }

    return Container(
      width: circleSize,
      height: circleSize,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '$dayNumber',
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
