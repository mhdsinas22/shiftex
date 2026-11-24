import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/home/presentation/widgets/home_formatters.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_category.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_entity.dart';
import 'package:shiftex/features/notifications/presentation/widgets/unread_indicator.dart';

class NotificationFormatters {
  const NotificationFormatters._();

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Formats timestamps to match "Today, 02:45 PM" / "Yesterday, 06:00 PM".
  static String formatTimestamp(DateTime dateTime, {DateTime? now}) {
    final local = dateTime.toLocal();
    final ref = (now ?? DateTime.now()).toLocal();
    final todayDate = DateTime(ref.year, ref.month, ref.day);
    final itemDate = DateTime(local.year, local.month, local.day);
    final diffDays = todayDate.difference(itemDate).inDays;

    final hour12 = local.hour == 0
        ? 12
        : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '${hour12.toString().padLeft(2, '0')}:$minute $period';

    if (diffDays == 0) {
      return 'Today, $timeStr';
    }
    if (diffDays == 1) {
      return 'Yesterday, $timeStr';
    }
    final month = _months[local.month - 1];
    return '${local.day} $month, $timeStr';
  }
}

class NotificationCard extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback onTap;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
  });

  static final RegExp _highlightPattern = RegExp(
    r'(\+?\d[\d,]*\s*pts|\b\d[\d,]*(?=\s+locked points))',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 360;
    final isUnread = notification.isUnread;

    final titleColor =
        isUnread ? AppColors.textPrimary : const Color(0xFF475467);
    final bodyColor = AppColors.textSecondary;
    final cleanTitle = HomeFormatters.stripCurrencyCopy(notification.title);
    final cleanBody = HomeFormatters.stripCurrencyCopy(notification.body);

    return Semantics(
      button: true,
      label:
          '$cleanTitle. $cleanBody. ${isUnread ? "Unread" : "Read"}',
      child: Material(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          key: Key('notification_card_${notification.id}'),
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(compact ? 14 : 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CategoryIconBadge(notification: notification),
                SizedBox(width: compact ? 12 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    cleanTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: compact ? 14.5 : 15,
                                      fontWeight: isUnread
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: titleColor,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                                if (notification.badgeLabel != null &&
                                    notification.badgeLabel!.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  _NotificationBadgePill(
                                    label: notification.badgeLabel!,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          UnreadIndicator(isUnread: isUnread),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text.rich(
                        _buildRichBody(
                          body: cleanBody,
                          baseColor: bodyColor,
                          isUnread: isUnread,
                        ),
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.42,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        NotificationFormatters.formatTimestamp(
                          notification.createdAt,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextSpan _buildRichBody({
    required String body,
    required Color baseColor,
    required bool isUnread,
  }) {
    final matches = _highlightPattern.allMatches(body).toList();
    if (matches.isEmpty) {
      return TextSpan(
        text: body,
        style: TextStyle(
          color: baseColor,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    final useCreditGreen =
        notification.type == NotificationType.posPointsCredited ||
            notification.type == NotificationType.festivalBonusCredited;
    final highlightColor = useCreditGreen
        ? const Color(0xFF059669)
        : (isUnread ? AppColors.textPrimary : const Color(0xFF344054));

    final spans = <TextSpan>[];
    var cursor = 0;

    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: body.substring(cursor, match.start),
            style: TextStyle(
              color: baseColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        );
      }
      final matchedText = body.substring(match.start, match.end);
      spans.add(
        TextSpan(
          text: matchedText,
          style: TextStyle(
            color: highlightColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      cursor = match.end;
    }

    if (cursor < body.length) {
      spans.add(
        TextSpan(
          text: body.substring(cursor),
          style: TextStyle(
            color: baseColor,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    return TextSpan(children: spans);
  }
}

class _CategoryIconBadge extends StatelessWidget {
  final NotificationEntity notification;

  const _CategoryIconBadge({required this.notification});

  IconData _resolveIcon() {
    switch (notification.type) {
      case NotificationType.posPointsCredited:
        return Icons.account_balance_wallet_outlined;
      case NotificationType.dailyStreakClaimed:
      case NotificationType.streakMilestoneCompleted:
        return Icons.local_fire_department_rounded;
      case NotificationType.lockedPointsReleased:
        return Icons.lock_rounded;
      case NotificationType.claimGenerated:
      case NotificationType.claimRedeemed:
        return Icons.qr_code_2_rounded;
      case NotificationType.claimExpired:
        return Icons.timer_off_outlined;
      case NotificationType.claimRejected:
        return Icons.gpp_maybe_outlined;
      case NotificationType.festivalBonusCredited:
      case NotificationType.festivalAnnouncement:
        return Icons.auto_awesome_rounded;
      case NotificationType.campaignPublished:
      case NotificationType.promotionalOffer:
        return Icons.campaign_outlined;
      case NotificationType.accountApproved:
        return Icons.verified_user_outlined;
      case NotificationType.accountStatusChanged:
        return Icons.manage_accounts_outlined;
      case NotificationType.adminPointAdjustment:
        return Icons.tune_rounded;
      case NotificationType.systemAnnouncement:
        return Icons.notifications_none_rounded;
    }
  }

  Color _resolveIconColor() {
    if (notification.type == NotificationType.claimRejected) {
      return AppColors.errorRed;
    }
    if (notification.isUnread) {
      return AppColors.textPrimary;
    }
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFEAECF0),
          width: 0.9,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        _resolveIcon(),
        size: 20,
        color: _resolveIconColor(),
      ),
    );
  }
}

class _NotificationBadgePill extends StatelessWidget {
  final String label;

  const _NotificationBadgePill({required this.label});

  @override
  Widget build(BuildContext context) {
    final isFestive = label.toLowerCase().contains('festive');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: isFestive
            ? const Color(0xFFF3E8FF)
            : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isFestive
              ? const Color(0xFF7C3AED)
              : AppColors.primaryBlue,
        ),
      ),
    );
  }
}
