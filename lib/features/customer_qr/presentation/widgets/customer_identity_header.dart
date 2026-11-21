import 'package:flutter/material.dart';

import 'package:shiftex/features/home/presentation/widgets/home_header_bar.dart';

/// Top navigation header for the Personal QR Display page reusing SHIIFTEX's
/// shared brand header bar with a bottom hairline separator.
class CustomerIdentityHeader extends StatelessWidget {
  final String fullName;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileTap;

  const CustomerIdentityHeader({
    super.key,
    required this.fullName,
    required this.onNotificationTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: const Color(0xFFF5F7FA),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HomeHeaderBar(
            fullName: fullName,
            onNotificationTap: onNotificationTap,
            onProfileTap: onProfileTap,
          ),
          // Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: const Divider(
          //     height: 1,
          //     thickness: 1,
          //     color: AppColors.divider,
          //   ),
          // ),
        ],
      ),
    );
  }
}
