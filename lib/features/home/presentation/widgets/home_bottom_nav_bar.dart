import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/home/presentation/bloc/home_state.dart';

class HomeBottomNavBar extends StatelessWidget {
  final HomeTab selectedTab;
  final ValueChanged<HomeTab> onTabSelected;
  final VoidCallback onScanQrTap;

  const HomeBottomNavBar({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
    required this.onScanQrTap,
  });

  @override
  Widget build(BuildContext context) {
    final isHome = selectedTab == HomeTab.home;
    final isHistory = selectedTab == HomeTab.history;

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
                  onTap: () => onTabSelected(HomeTab.home),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isHome ? Icons.home_rounded : Icons.home_outlined,
                        size: 22,
                        color:
                            isHome
                                ? AppColors.primaryBlue
                                : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Home',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              isHome ? FontWeight.w700 : FontWeight.w500,
                          color:
                              isHome
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
                    onTap: onScanQrTap,
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
                  onTap: () => onTabSelected(HomeTab.history),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isHistory
                            ? Icons.receipt_long_rounded
                            : Icons.receipt_long_outlined,
                        size: 22,
                        color:
                            isHistory
                                ? AppColors.primaryBlue
                                : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'History',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              isHistory ? FontWeight.w700 : FontWeight.w500,
                          color:
                              isHistory
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
