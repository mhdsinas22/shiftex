import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/core/widgets/sign_out_dialog.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';
import 'package:shiftex/features/home/domain/entities/home_dashboard_entity.dart';
import 'package:shiftex/features/home/presentation/widgets/customer_profile_sheet.dart';

void openProfileSheet(
  HomeDashboardEntity? dashboard,
  CustomerProfileEntity? authProfile,
  BuildContext context,
) {
  final router = GoRouter.maybeOf(context);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return CustomerProfileSheet(
        dashboard: dashboard,
        fallbackFullName: authProfile?.fullName ?? 'Member',
        fallbackEmail: authProfile?.email ?? '',
        fallbackMobile: authProfile?.mobileNumber ?? '',
        onChangePassword: () {
          router?.push(RoutesNames.changePassword);
        },
        onSignOut: () {
          signOutDialog(context);
        },
      );
    },
  );
}
