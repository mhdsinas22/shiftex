import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/widgets/shiiftex_primary_button.dart';
import 'package:shiftex/features/home/domain/entities/home_dashboard_entity.dart';

class CustomerProfileSheet extends StatelessWidget {
  final HomeDashboardEntity? dashboard;
  final String fallbackFullName;
  final String fallbackEmail;
  final String fallbackMobile;
  final VoidCallback onSignOut;

  const CustomerProfileSheet({
    super.key,
    this.dashboard,
    required this.fallbackFullName,
    required this.fallbackEmail,
    required this.fallbackMobile,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final fullName = dashboard?.fullName ?? fallbackFullName;
    final email = dashboard?.email ?? fallbackEmail;
    final mobile = dashboard?.mobileNumber ?? fallbackMobile;
    final customerCode = dashboard?.wallet.customerCode ?? 'SHFT-MEMBER';
    final tier = dashboard?.wallet.membershipTier ?? 'Pebble Black Member';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.dragHandle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryButtonDark,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$tier • $customerCode',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.mail_outline_rounded,
                        size: 17,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          email,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 17,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          mobile,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ShiiftexPrimaryButton(
              label: 'Sign Out',
              leadingIcon: Icons.logout_rounded,
              showTrailingArrow: false,
              onPressed: () {
                Navigator.of(context).pop();
                onSignOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}
