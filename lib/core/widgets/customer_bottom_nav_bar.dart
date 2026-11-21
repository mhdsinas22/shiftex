import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/home/presentation/widgets/home_bottom_nav_bar.dart';

class CustomerBottomNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const CustomerBottomNavBar({super.key, required this.navigationShell});
  void _onTabSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.white,
      body: navigationShell,
      bottomNavigationBar: HomeBottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onTabSelected: _onTabSelected,
      ),
    );
  }
}
