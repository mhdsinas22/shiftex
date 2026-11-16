import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/constants/app_strings.dart';
import 'package:shiftex/core/extensions/context_extensions.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';
import 'package:shiftex/core/widgets/shiiftex_auth_scaffold.dart';
import 'package:shiftex/core/widgets/shiiftex_logo_badge.dart';
import 'package:shiftex/core/widgets/shiiftex_primary_button.dart';
import 'package:shiftex/features/account_approval/domain/entities/approval_status.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';

class PendingApprovalPage extends StatelessWidget {
  const PendingApprovalPage({super.key});

  CustomerProfileEntity? _extractProfile(AuthenticationState state) {
    if (state is PendingApproval) return state.profile;
    if (state is AccountRejected) return state.profile;
    if (state is AccountSuspended) return state.profile;
    if (state is AuthenticationLoading) return state.currentProfile;
    if (state is AuthenticationFailure) return state.previousProfile;
    if (state is AuthenticationSuccess) return state.profile;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final vGap = responsive.scaleVertical(24);

    return BlocConsumer<AuthenticationBloc, AuthenticationState>(
      listener: (context, state) {
        if (state is AuthenticationSuccess) {
          context.go(RoutesNames.home);
        } else if (state is Unauthenticated) {
          context.go(RoutesNames.login);
        } else if (state is PendingApproval && state.statusMessage != null) {
          context.showFeedbackSnackBar(
            state.statusMessage!,
            isError: false,
          );
        } else if (state is AuthenticationFailure) {
          context.showFeedbackSnackBar(state.failure.message);
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthenticationLoading;
        final profile = _extractProfile(state);
        final status =
            profile?.approvalStatus ??
            (state is AccountRejected
                ? AccountApprovalStatus.rejected
                : (state is AccountSuspended
                    ? AccountApprovalStatus.suspended
                    : AccountApprovalStatus.pending));
        final rejectionReason =
            state is AccountRejected
                ? state.reason
                : profile?.rejectionReason;

        final heading = switch (status) {
          AccountApprovalStatus.rejected => 'Approval Declined',
          AccountApprovalStatus.suspended => 'Account Suspended',
          _ => AppStrings.waitingForApprovalHeading,
        };

        final subtitle = switch (status) {
          AccountApprovalStatus.rejected =>
            'Your registration was reviewed by our\nadministrator.',
          AccountApprovalStatus.suspended =>
            'Access to your Shiiftex account is currently\nrestricted.',
          _ => AppStrings.waitingForApprovalSubtitle,
        };

        return ShiiftexAuthScaffold(
          headerBadge: const ShiiftexLogoBadge(
            variant: ShiiftexLogoVariant.full,
            size: 76,
          ),
          title: heading,
          subtitle: subtitle,
          sheetChild: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              Center(
                child: _StatusBadgePill(status: status),
              ),
              SizedBox(height: vGap),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  _buildBodyMessage(status, rejectionReason),
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: responsive.isSmallWidth ? 14.5 : 15.8,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.48,
                  ),
                ),
              ),
              SizedBox(height: vGap),
              _buildInfoCard(status, rejectionReason, responsive),
              SizedBox(height: vGap),
              ShiiftexPrimaryButton(
                label: AppStrings.refreshStatus,
                leadingIcon: Icons.sync_rounded,
                showTrailingArrow: false,
                isLoading: isLoading,
                onPressed: () {
                  context.read<AuthenticationBloc>().add(
                    const CheckApprovalStatusRequested(),
                  );
                },
              ),
              SizedBox(height: responsive.scaleVertical(14)),
              Center(
                child: TextButton(
                  onPressed:
                      isLoading
                          ? null
                          : () {
                            context.read<AuthenticationBloc>().add(
                              const LogoutRequested(),
                            );
                          },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    minimumSize: const Size(120, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    AppStrings.backToLogin,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _buildBodyMessage(
    AccountApprovalStatus status,
    String? rejectionReason,
  ) {
    switch (status) {
      case AccountApprovalStatus.rejected:
        return 'Your account registration could not be approved by our administrator at this time. Please review the reason below or contact Shiiftex Support for assistance.';
      case AccountApprovalStatus.suspended:
        return 'Your customer account has been suspended by an administrator. Protected rewards vault features are currently unavailable.';
      case AccountApprovalStatus.pending:
      case AccountApprovalStatus.approved:
        return AppStrings.pendingApprovalBody;
    }
  }

  Widget _buildInfoCard(
    AccountApprovalStatus status,
    String? rejectionReason,
    ResponsiveLayout responsive,
  ) {
    final cardPad = responsive.isSmallWidth ? 16.0 : 20.0;

    if (status == AccountApprovalStatus.rejected) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(cardPad),
        decoration: BoxDecoration(
          color: AppColors.rejectedBadgeBg.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppColors.rejectedBadgeText,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Administrator Note',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              (rejectionReason != null && rejectionReason.trim().isNotEmpty)
                  ? rejectionReason
                  : 'Verification details did not meet approval criteria.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.2,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    if (status == AccountApprovalStatus.suspended) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(cardPad),
        decoration: BoxDecoration(
          color: AppColors.suspendedBadgeBg.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_person_outlined,
                  size: 20,
                  color: AppColors.suspendedBadgeText,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Access Restricted',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Please reach out to Shiiftex Support to review your account standing.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.2,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(cardPad),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.watch_later_rounded,
                size: 20,
                color: AppColors.primaryBlue,
              ),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  AppStrings.expectedReviewTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            AppStrings.expectedReviewSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadgePill extends StatelessWidget {
  final AccountApprovalStatus status;

  const _StatusBadgePill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor, icon, label) = switch (status) {
      AccountApprovalStatus.rejected => (
        AppColors.rejectedBadgeBg,
        AppColors.rejectedBadgeText,
        Icons.cancel_outlined,
        'Registration Rejected',
      ),
      AccountApprovalStatus.suspended => (
        AppColors.suspendedBadgeBg,
        AppColors.suspendedBadgeText,
        Icons.block_rounded,
        'Account Suspended',
      ),
      _ => (
        AppColors.pendingBadgeBg,
        AppColors.pendingBadgeText,
        Icons.hourglass_bottom_rounded,
        AppStrings.pendingAdminApprovalBadge,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: textColor),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: textColor,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
