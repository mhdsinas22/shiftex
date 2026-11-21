import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shiftex/core/constants/app_colors.dart';

class HomeBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const HomeBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isHome = currentIndex == 0;
    final isHistory = currentIndex == 2;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 12),
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTabSelected(0);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isHome ? Icons.home_rounded : Icons.home_outlined,
                        size: 22,
                        color: isHome
                            ? AppColors.primaryBlue
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Home',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isHome
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isHome
                              ? AppColors.primaryBlue
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Show personal QR code',
                child: Material(
                  color: AppColors.primaryBlue,
                  shape: const CircleBorder(),
                  elevation: 4,
                  shadowColor: AppColors.primaryBlue.withValues(alpha: 0.4),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTabSelected(1);
                    },
                    child: const SizedBox(
                      width: 54,
                      height: 54,
                      child: Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.white,
                        size: 25,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTabSelected(2);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isHistory
                            ? Icons.receipt_long_rounded
                            : Icons.receipt_long_outlined,
                        size: 22,
                        color: isHistory
                            ? AppColors.primaryBlue
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'History',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isHistory
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isHistory
                              ? AppColors.primaryBlue
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
