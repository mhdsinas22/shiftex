import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/core/constants/app_assets.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:shiftex/features/notifications/presentation/bloc/notification_state.dart';

class HomeHeaderBar extends StatelessWidget {
  final String fullName;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileTap;
  final int? unreadCount;

  const HomeHeaderBar({
    super.key,
    required this.fullName,
    required this.onNotificationTap,
    required this.onProfileTap,
    this.unreadCount,
  });

  NotificationBloc? _tryReadNotificationBloc(BuildContext context) {
    try {
      return context.read<NotificationBloc>();
    } catch (_) {
      return null;
    }
  }

  String get _initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'S';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // SHIIFTEX circular logo badge
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: ClipOval(
            child: Image.asset(AppAssets.splashlogpng, fit: BoxFit.contain),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Notification button with reactive unread count badge
            Builder(
              builder: (context) {
                if (unreadCount != null) {
                  return _NotificationBellButton(
                    unreadCount: unreadCount!,
                    onTap: onNotificationTap,
                  );
                }
                final notifBloc = _tryReadNotificationBloc(context);
                if (notifBloc == null) {
                  return _NotificationBellButton(
                    unreadCount: 0,
                    onTap: onNotificationTap,
                  );
                }
                return BlocSelector<NotificationBloc, NotificationState, int>(
                  bloc: notifBloc,
                  selector: (state) => state.unreadCount,
                  builder: (context, count) {
                    return _NotificationBellButton(
                      unreadCount: count,
                      onTap: onNotificationTap,
                    );
                  },
                );
              },
            ),
            const SizedBox(width: 10),
            // Profile avatar button
            Semantics(
              button: true,
              label: 'Customer profile and account options',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onProfileTap,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF344054), Color(0xFF101828)],
                    ),
                    border: Border.all(color: AppColors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _NotificationBellButton({
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeText = unreadCount > 99 ? '99+' : '$unreadCount';
    return Semantics(
      button: true,
      label: unreadCount > 0
          ? 'Notifications, $unreadCount unread'
          : 'Notifications',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: AppColors.white,
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              key: const Key('notification_bell_button'),
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider, width: 1),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.textPrimary,
                  size: 21,
                ),
              ),
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              top: -2,
              right: -2,
              child: IgnorePointer(
                child: Container(
                  key: const Key('notification_bell_badge'),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.white, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
