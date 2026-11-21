import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';

class NotificationHeader extends StatelessWidget {
  final bool hasUnread;
  final bool isUpdating;
  final VoidCallback onClose;
  final VoidCallback onMarkAllAsRead;

  const NotificationHeader({
    super.key,
    required this.hasUnread,
    required this.isUpdating,
    required this.onClose,
    required this.onMarkAllAsRead,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 360;
    final horizontalPadding = compact ? 16.0 : 20.0;
    final closeSize = compact ? 36.0 : 40.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD0D5DD),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            14,
            horizontalPadding,
            12,
          ),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: 'Close notifications',
                child: Material(
                  color: AppColors.inputBackground,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const Key('notifications_close_button'),
                    customBorder: const CircleBorder(),
                    onTap: onClose,
                    child: SizedBox(
                      width: closeSize,
                      height: closeSize,
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                flex: 3,
                child: Text(
                  'Notifications',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 18 : 21,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 4,
                child: Material(
                  color: hasUnread
                      ? AppColors.inputBackground
                      : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    key: const Key('mark_all_as_read_button'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: (!hasUnread || isUpdating) ? null : onMarkAllAsRead,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 10 : 14,
                        vertical: 8,
                      ),
                      child: isUpdating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.textPrimary,
                                ),
                              ),
                            )
                          : Text(
                              'Mark all as read',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 11.5 : 13,
                                fontWeight: FontWeight.w600,
                                color: hasUnread
                                    ? AppColors.textPrimary
                                    : AppColors.textTertiary,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
