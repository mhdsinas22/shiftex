import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';

/// Compact 8px circular unread indicator matching the Notifications UI reference.
class UnreadIndicator extends StatelessWidget {
  final bool isUnread;

  const UnreadIndicator({
    super.key,
    required this.isUnread,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isUnread ? 1.0 : 0.0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: isUnread ? 1.0 : 0.4,
        child: isUnread
            ? Semantics(
                label: 'Unread notification',
                child: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 5, left: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
