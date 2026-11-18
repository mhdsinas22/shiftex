import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_assets.dart';
import 'package:shiftex/core/constants/app_colors.dart';

class HomeHeaderBar extends StatelessWidget {
  final String fullName;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileTap;

  const HomeHeaderBar({
    super.key,
    required this.fullName,
    required this.onNotificationTap,
    required this.onProfileTap,
  });

  String get _initials {
    final parts =
        fullName
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
            child: Image.asset(
              AppAssets.splashlogpng,
              fit: BoxFit.contain,
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Notification button
            Material(
              color: AppColors.white,
              shape: const CircleBorder(),
              elevation: 0,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onNotificationTap,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.divider,
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.textPrimary,
                    size: 21,
                  ),
                ),
              ),
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
                      colors: [
                        Color(0xFF344054),
                        Color(0xFF101828),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.white,
                      width: 2,
                    ),
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
