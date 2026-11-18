import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/extensions/context_extensions.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';
import 'package:shiftex/core/widgets/shiiftex_info_bottom_sheet.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';
import 'package:shiftex/features/claim_rewards/presentation/widgets/claim_amount_bottom_sheet.dart';
import 'package:shiftex/features/home/domain/entities/customer_qr_token_entity.dart';
import 'package:shiftex/features/home/domain/entities/daily_streak_entity.dart';
import 'package:shiftex/features/home/domain/entities/home_dashboard_entity.dart';
import 'package:shiftex/features/home/domain/entities/wallet_summary_entity.dart';
import 'package:shiftex/features/home/presentation/bloc/home_bloc.dart';
import 'package:shiftex/features/home/presentation/bloc/home_event.dart';
import 'package:shiftex/features/home/presentation/bloc/home_state.dart';
import 'package:shiftex/features/home/presentation/widgets/available_balance_card.dart';
import 'package:shiftex/features/home/presentation/widgets/customer_greeting_section.dart';
import 'package:shiftex/features/home/presentation/widgets/customer_profile_sheet.dart';
import 'package:shiftex/features/home/presentation/widgets/daily_streak_card.dart';
import 'package:go_router/go_router.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/features/customer_qr/presentation/pages/customer_qr_page.dart';
import 'package:shiftex/features/home/presentation/widgets/home_bottom_nav_bar.dart';
import 'package:shiftex/features/home/presentation/widgets/home_header_bar.dart';
import 'package:shiftex/features/home/presentation/widgets/home_state_views.dart';
import 'package:shiftex/features/home/presentation/widgets/locked_points_card.dart';
import 'package:shiftex/features/home/presentation/widgets/recent_rewards_section.dart';
import 'package:shiftex/features/home/presentation/widgets/single_use_claim_qr_sheet.dart';
import 'package:shiftex/features/home/presentation/widgets/streak_celebration_dialog.dart';
import 'package:shiftex/features/home/presentation/widgets/transactions_history_view.dart';
import 'package:shiftex/injection_container.dart';

class HomePage extends StatefulWidget {
  final HomeBloc? homeBloc;

  const HomePage({super.key, this.homeBloc});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeBloc? _bloc;
  bool _ownsBloc = false;
  bool _isQrModalOpen = false;
  bool _isCelebrationDialogOpen = false;

  @override
  void initState() {
    super.initState();
    HomeBloc? resolved;
    if (widget.homeBloc != null) {
      resolved = widget.homeBloc;
      _ownsBloc = false;
    } else {
      try {
        resolved = context.read<HomeBloc>();
        _ownsBloc = false;
      } catch (_) {
        if (getIt.isRegistered<HomeBloc>()) {
          resolved = getIt<HomeBloc>();
          _ownsBloc = true;
        }
      }
    }

    _bloc = resolved;
    if (_bloc != null && _bloc!.state.status == HomeStatus.initial) {
      _bloc!.add(const HomeDashboardLoadRequested());
    }
  }

  @override
  void dispose() {
    if (_ownsBloc) {
      _bloc?.close();
    }
    super.dispose();
  }

  CustomerProfileEntity? _authProfile(BuildContext context) {
    try {
      final authState = context.read<AuthenticationBloc>().state;
      if (authState is AuthenticationSuccess) {
        return authState.profile;
      }
    } catch (_) {}
    return null;
  }

  HomeDashboardEntity _resolveDashboard(
    HomeState state,
    CustomerProfileEntity? authProfile,
  ) {
    if (state.dashboard != null) {
      return state.dashboard!;
    }
    final uid = authProfile?.id ?? '0000';
    final cleanUid = uid.replaceAll('-', '');
    final codeSuffix = cleanUid.length >= 4
        ? cleanUid.substring(0, 4).toUpperCase()
        : '0000';

    return HomeDashboardEntity(
      customerId: uid,
      fullName: authProfile?.fullName ?? 'Member',
      email: authProfile?.email ?? '',
      mobileNumber: authProfile?.mobileNumber ?? '',
      wallet: WalletSummaryEntity(
        customerCode: 'SHFT-$codeSuffix',
        membershipTier: 'Pebble Black Member',
        availablePoints: 0,
        lockedPoints: 0,
        lifetimeEarnedPoints: 0,
        lifetimeRedeemedPoints: 0,
        pointsEarnedToday: 0,
        pointsToInrRate: 0.10,
      ),
      lockedAllocations: const [],
      streak: DailyStreakEntity(
        dailyLoginEnabled: true,
        dailyPoints: 15,
        currentStreakDay: 1,
        claimedToday: false,
        daysRemaining: 6,
        cycleDate: '',
        nextResetAt: DateTime.now().toUtc().add(const Duration(hours: 12)),
        justCompletedDay7: false,
        completedStreakPoints: 0,
      ),
      recentTransactions: const [],
      advertisements: const [],
    );
  }

  Future<void> _showQrBottomSheet(
    CustomerQrTokenEntity qrToken,
    double pointsToInrRate,
  ) async {
    if (_isQrModalOpen || !mounted) return;
    _isQrModalOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.90,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) {
        return SingleUseClaimQrSheet(
          qrToken: qrToken,
          pointsToInrRate: pointsToInrRate,
          onClose: () => Navigator.of(sheetContext).pop(),
        );
      },
    );
    _isQrModalOpen = false;
    if (mounted) {
      _bloc?.add(const HomeClaimQrModalDismissed());
    }
  }

  Future<void> _showStreakCelebrationPopup(DailyStreakEntity streak) async {
    if (_isCelebrationDialogOpen || !mounted) return;
    _isCelebrationDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StreakCelebrationDialog(
          streak: streak,
          onContinue: () => Navigator.of(dialogContext).pop(),
        );
      },
    );
    _isCelebrationDialogOpen = false;
    if (mounted) {
      _bloc?.add(const HomeStreakCelebrationDismissed());
    }
  }

  void _openProfileSheet(
    HomeDashboardEntity? dashboard,
    CustomerProfileEntity? authProfile,
  ) {
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
          onSignOut: () {
            context.read<AuthenticationBloc>().add(const LogoutRequested());
          },
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    HomeState state,
    CustomerProfileEntity? authProfile,
  ) {
    final responsive = ResponsiveLayout.of(context);
    final hPad = responsive.sheetHorizontalPadding;
    final dashboard = _resolveDashboard(state, authProfile);
    final isInitialLoading =
        state.status == HomeStatus.loading && state.dashboard == null;
    final isInitialError =
        state.status == HomeStatus.error && state.dashboard == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      extendBody: true,
      bottomNavigationBar: HomeBottomNavBar(
        selectedTab: state.selectedTab,
        onTabSelected: (tab) => _bloc?.add(HomeTabChanged(tab)),
        onScanQrTap: () {
          final router = GoRouter.maybeOf(context);
          if (router != null) {
            router.push(RoutesNames.customerQr);
          } else {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CustomerQrPage()),
            );
          }
        },
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primaryBlue,
          onRefresh: () async {
            _bloc?.add(const HomeDashboardRefreshRequested());
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 110),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: responsive.maxContentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HomeHeaderBar(
                      fullName: dashboard.fullName,
                      onNotificationTap: () {
                        ShiiftexInfoBottomSheet.show(
                          context,
                          title: 'Notifications',
                          message: dashboard.streak.claimedToday
                              ? 'Today\'s daily streak check-in (+${dashboard.streak.dailyPoints} pts) is active. Next streak cycle resets at 06:00 AM IST.'
                              : 'Welcome to your Shiiftex rewards dashboard! Check in daily to complete your 7-day streak.',
                        );
                      },
                      onProfileTap: () =>
                          _openProfileSheet(state.dashboard, authProfile),
                    ),
                    const SizedBox(height: 18),
                    if (state.selectedTab == HomeTab.history)
                      TransactionsHistoryView(
                        dashboard: dashboard,
                        onBackToHome: () {
                          _bloc?.add(const HomeTabChanged(HomeTab.home));
                        },
                      )
                    else ...[
                      CustomerGreetingSection(
                        firstName: dashboard.firstName,
                        membershipTier: dashboard.wallet.membershipTier,
                        customerCode: dashboard.wallet.customerCode,
                      ),
                      const SizedBox(height: 18),
                      if (isInitialLoading)
                        const HomeLoadingSkeleton()
                      else if (isInitialError)
                        HomeErrorCard(
                          message:
                              state.errorMessage ??
                              'Unable to load your dashboard.',
                          onRetry: () {
                            _bloc?.add(const HomeDashboardLoadRequested());
                          },
                        )
                      else ...[
                        AvailableBalanceCard(
                          wallet: dashboard.wallet,
                          onClaimRewardsTap: () {
                            claimAmountBottomSheet(
                              context,
                              initialAvailablePoints:
                                  dashboard.wallet.availablePoints,
                              initialPointsToInrRate:
                                  dashboard.wallet.pointsToInrRate,
                              initialLockedPoints:
                                  dashboard.wallet.lockedPoints,
                              onFlowClosed: () {
                                if (mounted) {
                                  _bloc?.add(
                                    const HomeDashboardLoadRequested(
                                      performDailyCheckIn: false,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        LockedPointsCard(
                          wallet: dashboard.wallet,
                          nextAllocation: dashboard.nextUnlockAllocation,
                        ),
                        const SizedBox(height: 16),
                        DailyStreakCard(streak: dashboard.streak),

                        const SizedBox(height: 16),
                        RecentRewardsSection(
                          transactions: dashboard.recentTransactions,
                          pointsToInrRate: dashboard.wallet.pointsToInrRate,
                          onViewAllTap: () {
                            _bloc?.add(const HomeTabChanged(HomeTab.history));
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProfile = _authProfile(context);
    if (_bloc == null) {
      return _buildScaffold(
        context,
        const HomeState(status: HomeStatus.loaded),
        authProfile,
      );
    }

    return BlocProvider<HomeBloc>.value(
      value: _bloc!,
      child: BlocConsumer<HomeBloc, HomeState>(
        listener: (context, state) {
          if (state.feedbackMessage != null &&
              state.feedbackMessage!.isNotEmpty) {
            context.showFeedbackSnackBar(
              state.feedbackMessage!,
              isError: false,
            );
          } else if (state.errorMessage != null &&
              state.errorMessage!.isNotEmpty &&
              state.dashboard != null) {
            context.showFeedbackSnackBar(state.errorMessage!);
          }

          if (state.showStreakCelebration && state.dashboard != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showStreakCelebrationPopup(state.dashboard!.streak);
              }
            });
          }

          if (state.qrModalStatus == QrModalStatus.ready &&
              state.activeQrToken != null) {
            final rate = state.dashboard?.wallet.pointsToInrRate ?? 0.10;
            final token = state.activeQrToken!;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showQrBottomSheet(token, rate);
              }
            });
          }
        },
        builder: (context, state) {
          return _buildScaffold(context, state, authProfile);
        },
      ),
    );
  }
}
