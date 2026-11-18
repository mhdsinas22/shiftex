import 'package:flutter_test/flutter_test.dart';
import 'package:shiftex/core/router/app_router.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/features/account_approval/domain/entities/approval_status.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';

void main() {
  final tNow = DateTime.utc(2026, 11, 16);

  CustomerProfileEntity buildProfile(AccountApprovalStatus status) {
    return CustomerProfileEntity(
      id: 'user-1',
      fullName: 'Rahul Sharma',
      email: 'rahul123@example.com',
      mobileNumber: '+919876543210',
      approvalStatus: status,
      createdAt: tNow,
      updatedAt: tNow,
    );
  }

  group('GoRouter Authentication & Approval Guard Redirect Tests', () {
    test('AuthenticationInitial holds navigation on /splash', () {
      expect(
        AppRouter.evaluateAuthRedirect(
          authState: const AuthenticationInitial(),
          matchedLocation: RoutesNames.home,
        ),
        RoutesNames.splash,
      );
      expect(
        AppRouter.evaluateAuthRedirect(
          authState: const AuthenticationInitial(),
          matchedLocation: RoutesNames.customerQr,
        ),
        RoutesNames.splash,
      );
      expect(
        AppRouter.evaluateAuthRedirect(
          authState: const AuthenticationInitial(),
          matchedLocation: RoutesNames.claimRewards,
        ),
        RoutesNames.splash,
      );
      expect(
        AppRouter.evaluateAuthRedirect(
          authState: const AuthenticationInitial(),
          matchedLocation: RoutesNames.splash,
        ),
        isNull,
      );
    });

    test('Unauthenticated users are blocked from /home, /customer-qr, and /pending-approval', () {
      expect(
        AppRouter.evaluateAuthRedirect(
          authState: const Unauthenticated(),
          matchedLocation: RoutesNames.home,
        ),
        RoutesNames.login,
      );
      expect(
        AppRouter.evaluateAuthRedirect(
          authState: const Unauthenticated(),
          matchedLocation: RoutesNames.customerQr,
        ),
        RoutesNames.login,
      );
      expect(
        AppRouter.evaluateAuthRedirect(
          authState: const Unauthenticated(),
          matchedLocation: RoutesNames.claimRewards,
        ),
        RoutesNames.login,
      );
      expect(
        AppRouter.evaluateAuthRedirect(
          authState: const Unauthenticated(),
          matchedLocation: RoutesNames.pendingApproval,
        ),
        RoutesNames.login,
      );
      expect(
        AppRouter.evaluateAuthRedirect(
          authState: const Unauthenticated(),
          matchedLocation: RoutesNames.setNewPassword,
        ),
        RoutesNames.login,
      );
      expect(
        AppRouter.evaluateAuthRedirect(
          authState: const Unauthenticated(),
          matchedLocation: RoutesNames.login,
        ),
        isNull,
      );
      expect(
        AppRouter.evaluateAuthRedirect(
          authState: const Unauthenticated(),
          matchedLocation: RoutesNames.register,
        ),
        isNull,
      );
    });

    test(
      'Pending, Rejected, and Suspended accounts CANNOT access /home and are redirected to /pending-approval',
      () {
        final pendingState = PendingApproval(
          buildProfile(AccountApprovalStatus.pending),
        );
        final rejectedState = AccountRejected(
          profile: buildProfile(AccountApprovalStatus.rejected),
          reason: 'Rejected by admin',
        );
        final suspendedState = AccountSuspended(
          buildProfile(AccountApprovalStatus.suspended),
        );

        for (final restrictedState in [
          pendingState,
          rejectedState,
          suspendedState,
        ]) {
          expect(
            AppRouter.evaluateAuthRedirect(
              authState: restrictedState,
              matchedLocation: RoutesNames.home,
            ),
            RoutesNames.pendingApproval,
          );
          expect(
            AppRouter.evaluateAuthRedirect(
              authState: restrictedState,
              matchedLocation: RoutesNames.customerQr,
            ),
            RoutesNames.pendingApproval,
          );
          expect(
            AppRouter.evaluateAuthRedirect(
              authState: restrictedState,
              matchedLocation: RoutesNames.claimRewards,
            ),
            RoutesNames.pendingApproval,
          );
          expect(
            AppRouter.evaluateAuthRedirect(
              authState: restrictedState,
              matchedLocation: RoutesNames.login,
            ),
            RoutesNames.pendingApproval,
          );
          expect(
            AppRouter.evaluateAuthRedirect(
              authState: restrictedState,
              matchedLocation: RoutesNames.pendingApproval,
            ),
            isNull,
          );
        }
      },
    );

    test(
      'Only approved customers in AuthenticationSuccess can access /home and /customer-qr',
      () {
        final approvedState = AuthenticationSuccess(
          buildProfile(AccountApprovalStatus.approved),
        );

        expect(
          AppRouter.evaluateAuthRedirect(
            authState: approvedState,
            matchedLocation: RoutesNames.home,
          ),
          isNull,
        );
        expect(
          AppRouter.evaluateAuthRedirect(
            authState: approvedState,
            matchedLocation: RoutesNames.customerQr,
          ),
          isNull,
        );
        expect(
          AppRouter.evaluateAuthRedirect(
            authState: approvedState,
            matchedLocation: RoutesNames.claimRewards,
          ),
          isNull,
        );
        expect(
          AppRouter.evaluateAuthRedirect(
            authState: AuthenticationLoading(
              currentProfile: buildProfile(AccountApprovalStatus.approved),
            ),
            matchedLocation: RoutesNames.customerQr,
          ),
          isNull,
        );
        expect(
          AppRouter.evaluateAuthRedirect(
            authState: AuthenticationLoading(
              currentProfile: buildProfile(AccountApprovalStatus.pending),
            ),
            matchedLocation: RoutesNames.customerQr,
          ),
          RoutesNames.splash,
        );
        expect(
          AppRouter.evaluateAuthRedirect(
            authState: approvedState,
            matchedLocation: RoutesNames.login,
          ),
          RoutesNames.home,
        );
        expect(
          AppRouter.evaluateAuthRedirect(
            authState: approvedState,
            matchedLocation: RoutesNames.pendingApproval,
          ),
          RoutesNames.home,
        );
      },
    );

    test(
      'PasswordResetVerified redirects to /set-new-password and blocks /home',
      () {
        const verifiedState = PasswordResetVerified(
          email: 'john.doe@example.com',
        );

        expect(
          AppRouter.evaluateAuthRedirect(
            authState: verifiedState,
            matchedLocation: RoutesNames.resetCode,
          ),
          RoutesNames.setNewPassword,
        );
        expect(
          AppRouter.evaluateAuthRedirect(
            authState: verifiedState,
            matchedLocation: RoutesNames.home,
          ),
          RoutesNames.setNewPassword,
        );
        expect(
          AppRouter.evaluateAuthRedirect(
            authState: verifiedState,
            matchedLocation: RoutesNames.setNewPassword,
          ),
          isNull,
        );
      },
    );
  });
}
