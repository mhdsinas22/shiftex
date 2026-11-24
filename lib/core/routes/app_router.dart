import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/core/widgets/customer_bottom_nav_bar.dart';
import 'package:shiftex/features/account_approval/presentation/pages/pending_approval_page.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';
import 'package:shiftex/features/authentication/presentation/pages/forgot_password_page.dart';
import 'package:shiftex/features/authentication/presentation/pages/login_page.dart';
import 'package:shiftex/features/authentication/presentation/pages/registration_page.dart';
import 'package:shiftex/features/authentication/presentation/pages/reset_code_page.dart';
import 'package:shiftex/features/authentication/presentation/pages/set_new_password_page.dart';
import 'package:shiftex/features/authentication/presentation/pages/verify_email_otp_page.dart';
import 'package:shiftex/features/activity_history/presentation/pages/activity_history_page.dart';
import 'package:shiftex/features/change_password/presentation/pages/change_password_page.dart';
import 'package:shiftex/features/claim_rewards/presentation/pages/claim_rewards_page.dart';
import 'package:shiftex/features/customer_qr/presentation/pages/customer_qr_page.dart';
import 'package:shiftex/features/home/presentation/pages/home_page.dart';
import 'package:shiftex/features/notifications/presentation/pages/notifications_page.dart';
import 'package:shiftex/features/splash/page/splash_screen.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AppRouter {
  final AuthenticationBloc authenticationBloc;
  late final GoRouter router;
  late final GoRouterRefreshStream _refreshListenable;

  AppRouter({required this.authenticationBloc}) {
    _refreshListenable = GoRouterRefreshStream(authenticationBloc.stream);
    router = GoRouter(
      initialLocation: RoutesNames.splash,
      refreshListenable: _refreshListenable,
      redirect: (context, state) {
        return evaluateAuthRedirect(
          authState: authenticationBloc.state,
          matchedLocation: state.matchedLocation,
          queryParameters: state.uri.queryParameters,
        );
      },
      routes: [
        GoRoute(
          path: RoutesNames.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: RoutesNames.login,
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: RoutesNames.register,
          builder: (context, state) => const RegistrationPage(),
        ),
        GoRoute(
          path: RoutesNames.verifyEmail,
          builder: (context, state) {
            final email = state.uri.queryParameters['email'] ?? '';
            return VerifyEmailOtpPage(email: email);
          },
        ),
        GoRoute(
          path: RoutesNames.pendingApproval,
          builder: (context, state) => const PendingApprovalPage(),
        ),
        GoRoute(
          path: RoutesNames.forgotPassword,
          builder: (context, state) {
            final email = state.uri.queryParameters['email'];
            final fromChangePassword =
                state.uri.queryParameters['from'] == 'change-password';
            return ForgotPasswordPage(
              initialEmail: email,
              fromChangePassword: fromChangePassword,
            );
          },
        ),
        GoRoute(
          path: RoutesNames.resetCode,
          builder: (context, state) {
            final email = state.uri.queryParameters['email'] ?? '';
            final fromChangePassword =
                state.uri.queryParameters['from'] == 'change-password';
            return ResetCodePage(
              email: email,
              fromChangePassword: fromChangePassword,
            );
          },
        ),
        GoRoute(
          path: RoutesNames.setNewPassword,
          builder: (context, state) => const SetNewPasswordPage(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return CustomerBottomNavBar(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutesNames.home,
                  builder: (context, state) => HomePage(
                    initialSection: state.uri.queryParameters['section'],
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutesNames.customerQr,
                  builder: (context, state) => const CustomerQrPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutesNames.activityHistory,
                  builder: (context, state) => const ActivityHistoryPage(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: RoutesNames.claimRewards,
          builder: (context, state) => const ClaimRewardsPage(),
        ),
        GoRoute(
          path: RoutesNames.notifications,
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            opaque: false,
            barrierDismissible: true,
            barrierColor: Colors.transparent,
            transitionDuration: const Duration(milliseconds: 260),
            reverseTransitionDuration: const Duration(milliseconds: 220),
            child: const NotificationsPage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.14),
                      end: Offset.zero,
                    ).animate(curved),
                    child: FadeTransition(opacity: curved, child: child),
                  );
                },
          ),
        ),
        GoRoute(
          path: RoutesNames.changePassword,
          builder: (context, state) => const ChangePasswordPage(),
        ),
      ],
    );
  }

  void dispose() {
    _refreshListenable.dispose();
  }

  /// Pure, deterministic authentication & approval guard evaluator.
  /// Never grants access to `/home` unless `authState` is `AuthenticationSuccess`
  /// backed by a server-verified approved `CustomerProfileEntity`.
  static String? evaluateAuthRedirect({
    required AuthenticationState authState,
    required String matchedLocation,
    Map<String, String> queryParameters = const {},
  }) {
    const publicAuthRoutes = <String>{
      RoutesNames.login,
      RoutesNames.register,
      RoutesNames.verifyEmail,
      RoutesNames.forgotPassword,
      RoutesNames.resetCode,
    };

    // 1. Resolving initial session state -> hold at /splash
    if (authState is AuthenticationInitial) {
      return matchedLocation == RoutesNames.splash ? null : RoutesNames.splash;
    }

    // 2. Loading state -> stay on current screen unless trying to access protected customer routes without an approved profile
    if (authState is AuthenticationLoading) {
      if (matchedLocation == RoutesNames.home ||
          matchedLocation == RoutesNames.customerQr ||
          matchedLocation == RoutesNames.claimRewards ||
          matchedLocation == RoutesNames.activityHistory ||
          matchedLocation == RoutesNames.notifications ||
          matchedLocation == RoutesNames.changePassword) {
        final profile = authState.currentProfile;
        if (profile == null || !profile.isApproved) {
          return RoutesNames.splash;
        }
      }
      return null;
    }

    // 3. Approved customer -> grant access to customer routes and redirect away from auth/pending screens
    if (authState is AuthenticationSuccess) {
      if (!authState.profile.isApproved) {
        return matchedLocation == RoutesNames.pendingApproval
            ? null
            : RoutesNames.pendingApproval;
      }
      final isForgotFromChangePassword =
          matchedLocation == RoutesNames.forgotPassword &&
          queryParameters['from'] == 'change-password';
      final isAllowedRoute =
          matchedLocation == RoutesNames.home ||
          matchedLocation == RoutesNames.customerQr ||
          matchedLocation == RoutesNames.claimRewards ||
          matchedLocation == RoutesNames.activityHistory ||
          matchedLocation == RoutesNames.notifications ||
          matchedLocation == RoutesNames.changePassword ||
          isForgotFromChangePassword;
      return isAllowedRoute ? null : RoutesNames.home;
    }

    // 4. Pending, Rejected, or Suspended customer -> strictly lock to /pending-approval
    if (authState is PendingApproval ||
        authState is AccountRejected ||
        authState is AccountSuspended) {
      return matchedLocation == RoutesNames.pendingApproval
          ? null
          : RoutesNames.pendingApproval;
    }

    // 5. Email OTP verification required
    if (authState is OtpVerificationRequired) {
      if (matchedLocation == RoutesNames.verifyEmail ||
          matchedLocation == RoutesNames.register ||
          matchedLocation == RoutesNames.login) {
        return null;
      }
      return Uri(
        path: RoutesNames.verifyEmail,
        queryParameters: authState.email.isNotEmpty
            ? {'email': authState.email}
            : null,
      ).toString();
    }

    if (authState is RegistrationSuccess) {
      if (matchedLocation == RoutesNames.verifyEmail) return null;
      return Uri(
        path: RoutesNames.verifyEmail,
        queryParameters: authState.email.isNotEmpty
            ? {'email': authState.email}
            : null,
      ).toString();
    }

    // 6. Password recovery states
    if (authState is PasswordResetVerified) {
      if (matchedLocation == RoutesNames.setNewPassword ||
          matchedLocation == RoutesNames.login) {
        return null;
      }
      return RoutesNames.setNewPassword;
    }

    if (authState is PasswordResetEmailSent) {
      if (matchedLocation == RoutesNames.resetCode ||
          matchedLocation == RoutesNames.forgotPassword ||
          matchedLocation == RoutesNames.login) {
        return null;
      }
      return Uri(
        path: RoutesNames.resetCode,
        queryParameters: authState.email.isNotEmpty
            ? {'email': authState.email}
            : null,
      ).toString();
    }

    if (authState is PasswordResetSuccess) {
      return matchedLocation == RoutesNames.login ? null : RoutesNames.login;
    }

    // 7. Error state while on pending approval screen (e.g. offline status check)
    if (authState is AuthenticationFailure &&
        authState.previousProfile != null &&
        !authState.previousProfile!.isApproved) {
      return matchedLocation == RoutesNames.pendingApproval
          ? null
          : RoutesNames.pendingApproval;
    }

    // 8. Unauthenticated or failure on public flow -> block /home, /pending-approval, /set-new-password, /splash
    if (publicAuthRoutes.contains(matchedLocation)) {
      return null;
    }

    return RoutesNames.login;
  }
}
