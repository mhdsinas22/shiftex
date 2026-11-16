import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/account_approval/domain/entities/approval_status.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';
import 'package:shiftex/features/account_approval/domain/usecases/get_approval_status_usecase.dart';
import 'package:shiftex/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:shiftex/features/authentication/domain/usecases/forgot_password_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/get_current_session_profile_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/login_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/logout_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/register_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/resend_email_otp_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/reset_password_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/verify_email_otp_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/verify_password_reset_otp_usecase.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/shiftexapp.dart';

class _MockRegisterUseCase extends Mock implements RegisterUseCase {}

class _MockVerifyEmailOtpUseCase extends Mock
    implements VerifyEmailOtpUseCase {}

class _MockResendEmailOtpUseCase extends Mock
    implements ResendEmailOtpUseCase {}

class _MockLoginUseCase extends Mock implements LoginUseCase {}

class _MockLogoutUseCase extends Mock implements LogoutUseCase {}

class _MockForgotPasswordUseCase extends Mock
    implements ForgotPasswordUseCase {}

class _MockVerifyPasswordResetOtpUseCase extends Mock
    implements VerifyPasswordResetOtpUseCase {}

class _MockResetPasswordUseCase extends Mock implements ResetPasswordUseCase {}

class _MockGetCurrentSessionProfileUseCase extends Mock
    implements GetCurrentSessionProfileUseCase {}

class _MockGetApprovalStatusUseCase extends Mock
    implements GetApprovalStatusUseCase {}

class _MockAuthenticationRepository extends Mock
    implements AuthenticationRepository {}

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  late _MockRegisterUseCase mockRegisterUseCase;
  late _MockVerifyEmailOtpUseCase mockVerifyEmailOtpUseCase;
  late _MockResendEmailOtpUseCase mockResendEmailOtpUseCase;
  late _MockLoginUseCase mockLoginUseCase;
  late _MockLogoutUseCase mockLogoutUseCase;
  late _MockForgotPasswordUseCase mockForgotPasswordUseCase;
  late _MockVerifyPasswordResetOtpUseCase mockVerifyPasswordResetOtpUseCase;
  late _MockResetPasswordUseCase mockResetPasswordUseCase;
  late _MockGetCurrentSessionProfileUseCase
  mockGetCurrentSessionProfileUseCase;
  late _MockGetApprovalStatusUseCase mockGetApprovalStatusUseCase;
  late _MockAuthenticationRepository mockAuthRepository;

  final tNow = DateTime.utc(2026, 11, 16);

  setUpAll(() {
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    mockRegisterUseCase = _MockRegisterUseCase();
    mockVerifyEmailOtpUseCase = _MockVerifyEmailOtpUseCase();
    mockResendEmailOtpUseCase = _MockResendEmailOtpUseCase();
    mockLoginUseCase = _MockLoginUseCase();
    mockLogoutUseCase = _MockLogoutUseCase();
    mockForgotPasswordUseCase = _MockForgotPasswordUseCase();
    mockVerifyPasswordResetOtpUseCase = _MockVerifyPasswordResetOtpUseCase();
    mockResetPasswordUseCase = _MockResetPasswordUseCase();
    mockGetCurrentSessionProfileUseCase =
        _MockGetCurrentSessionProfileUseCase();
    mockGetApprovalStatusUseCase = _MockGetApprovalStatusUseCase();
    mockAuthRepository = _MockAuthenticationRepository();

    when(
      () => mockAuthRepository.authSessionEvents,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockGetCurrentSessionProfileUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
  });

  AuthenticationBloc buildBloc() {
    return AuthenticationBloc(
      registerUseCase: mockRegisterUseCase,
      verifyEmailOtpUseCase: mockVerifyEmailOtpUseCase,
      resendEmailOtpUseCase: mockResendEmailOtpUseCase,
      loginUseCase: mockLoginUseCase,
      logoutUseCase: mockLogoutUseCase,
      forgotPasswordUseCase: mockForgotPasswordUseCase,
      verifyPasswordResetOtpUseCase: mockVerifyPasswordResetOtpUseCase,
      resetPasswordUseCase: mockResetPasswordUseCase,
      getCurrentSessionProfileUseCase: mockGetCurrentSessionProfileUseCase,
      getApprovalStatusUseCase: mockGetApprovalStatusUseCase,
      authRepository: mockAuthRepository,
    );
  }

  const testViewports = <String, Size>{
    'Small Mobile (320x568)': Size(320, 568),
    'Compact Android (360x640)': Size(360, 640),
    'Medium Mobile (375x812)': Size(375, 812),
    'Large Mobile (430x932)': Size(430, 932),
    'Wide / Foldable (640x900)': Size(640, 900),
  };

  group('Multi-Viewport Mobile Responsiveness Audit', () {
    for (final entry in testViewports.entries) {
      testWidgets(
        'All public screens render without overflow on ${entry.key}',
        (WidgetTester tester) async {
          await tester.binding.setSurfaceSize(entry.value);
          final bloc = buildBloc();
          addTearDown(() async {
            await bloc.close();
            await tester.binding.setSurfaceSize(null);
          });

          await tester.pumpWidget(Shiftexapp(authenticationBloc: bloc));
          bloc.add(const AuthSessionChanged());
          await _pumpFrames(tester);

          // 1. Login Page
          expect(find.text('Welcome back'), findsOneWidget);
          expect(tester.takeException(), isNull);

          // 2. Registration Page
          final navContext = tester.element(find.byType(Scaffold).first);
          Router.of(navContext).routerDelegate;
          await tester.ensureVisible(find.text('Create an account'));
          await tester.pump();
          await tester.tap(find.text('Create an account'));
          await _pumpFrames(tester);
          expect(find.text('Create an account'), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Test Country Code Bottom Sheet on this viewport
          await tester.ensureVisible(find.text('+91'));
          await tester.pump();
          await tester.tap(find.text('+91'));
          await _pumpFrames(tester);
          expect(find.text('Select Country Code'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('India'));
          await _pumpFrames(tester);

          // Navigate back to Login -> Forgot Password
          await tester.ensureVisible(find.text('Log in'));
          await tester.pump();
          await tester.tap(find.text('Log in'));
          await _pumpFrames(tester);

          await tester.ensureVisible(find.text('Forgot password?'));
          await tester.pump();
          await tester.tap(find.text('Forgot password?'));
          await _pumpFrames(tester);
          expect(find.text('Forgot password?'), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Open Support Bottom Sheet on this viewport
          await tester.ensureVisible(
            find.text('Need help? Contact Shiiftex Support'),
          );
          await tester.pump();
          await tester.tap(find.text('Need help? Contact Shiiftex Support'));
          await _pumpFrames(tester);
          expect(find.text('Shiiftex Support'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Close'));
          await _pumpFrames(tester);
        },
      );
    }

    testWidgets(
      'PendingApprovalPage renders without overflow on compact 320x568 viewport',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        when(() => mockGetCurrentSessionProfileUseCase(any())).thenAnswer(
          (_) async => Right(
            CustomerProfileEntity(
              id: 'u-1',
              fullName: 'Rahul Sharma',
              email: 'rahul@example.com',
              mobileNumber: '+919876543210',
              approvalStatus: AccountApprovalStatus.pending,
              createdAt: tNow,
              updatedAt: tNow,
            ),
          ),
        );

        final bloc = buildBloc();
        addTearDown(() async {
          await bloc.close();
          await tester.binding.setSurfaceSize(null);
        });

        await tester.pumpWidget(Shiftexapp(authenticationBloc: bloc));
        bloc.add(const AuthSessionChanged());
        await _pumpFrames(tester);

        expect(find.text(RoutesNames.pendingApproval), findsNothing);
        expect(find.text('Waiting for Approval'), findsOneWidget);
        expect(find.text('Pending Admin Approval'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
