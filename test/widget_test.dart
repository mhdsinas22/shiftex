import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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

class MockRegisterUseCase extends Mock implements RegisterUseCase {}

class MockVerifyEmailOtpUseCase extends Mock implements VerifyEmailOtpUseCase {}

class MockResendEmailOtpUseCase extends Mock implements ResendEmailOtpUseCase {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockForgotPasswordUseCase extends Mock implements ForgotPasswordUseCase {}

class MockVerifyPasswordResetOtpUseCase extends Mock
    implements VerifyPasswordResetOtpUseCase {}

class MockResetPasswordUseCase extends Mock implements ResetPasswordUseCase {}

class MockGetCurrentSessionProfileUseCase extends Mock
    implements GetCurrentSessionProfileUseCase {}

class MockGetApprovalStatusUseCase extends Mock
    implements GetApprovalStatusUseCase {}

class MockAuthenticationRepository extends Mock
    implements AuthenticationRepository {}

Future<void> pumpTransition(WidgetTester tester) async {
  await tester.pump();
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  late MockRegisterUseCase mockRegisterUseCase;
  late MockVerifyEmailOtpUseCase mockVerifyEmailOtpUseCase;
  late MockResendEmailOtpUseCase mockResendEmailOtpUseCase;
  late MockLoginUseCase mockLoginUseCase;
  late MockLogoutUseCase mockLogoutUseCase;
  late MockForgotPasswordUseCase mockForgotPasswordUseCase;
  late MockVerifyPasswordResetOtpUseCase mockVerifyPasswordResetOtpUseCase;
  late MockResetPasswordUseCase mockResetPasswordUseCase;
  late MockGetCurrentSessionProfileUseCase mockGetCurrentSessionProfileUseCase;
  late MockGetApprovalStatusUseCase mockGetApprovalStatusUseCase;
  late MockAuthenticationRepository mockAuthRepository;

  final tNow = DateTime.utc(2026, 11, 16);

  CustomerProfileEntity buildProfile(
    AccountApprovalStatus status, {
    String? rejectionReason,
  }) {
    return CustomerProfileEntity(
      id: 'uid-100',
      fullName: 'Rahul Sharma',
      email: 'rahul123@example.com',
      mobileNumber: '+919876543210',
      approvalStatus: status,
      rejectionReason: rejectionReason,
      createdAt: tNow,
      updatedAt: tNow,
    );
  }

  AuthenticationBloc createBloc() {
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

  setUpAll(() {
    registerFallbackValue(
      const RegisterParams(
        firstName: '',
        lastName: '',
        mobileNumber: '',
        email: '',
        password: '',
      ),
    );
    registerFallbackValue(const VerifyEmailOtpParams(email: '', otpCode: ''));
    registerFallbackValue(const ResendEmailOtpParams(email: ''));
    registerFallbackValue(const LoginParams(identifier: '', password: ''));
    registerFallbackValue(const ForgotPasswordParams(email: ''));
    registerFallbackValue(
      const VerifyPasswordResetOtpParams(email: '', otpCode: ''),
    );
    registerFallbackValue(const ResetPasswordParams(newPassword: ''));
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    mockRegisterUseCase = MockRegisterUseCase();
    mockVerifyEmailOtpUseCase = MockVerifyEmailOtpUseCase();
    mockResendEmailOtpUseCase = MockResendEmailOtpUseCase();
    mockLoginUseCase = MockLoginUseCase();
    mockLogoutUseCase = MockLogoutUseCase();
    mockForgotPasswordUseCase = MockForgotPasswordUseCase();
    mockVerifyPasswordResetOtpUseCase = MockVerifyPasswordResetOtpUseCase();
    mockResetPasswordUseCase = MockResetPasswordUseCase();
    mockGetCurrentSessionProfileUseCase = MockGetCurrentSessionProfileUseCase();
    mockGetApprovalStatusUseCase = MockGetApprovalStatusUseCase();
    mockAuthRepository = MockAuthenticationRepository();

    when(
      () => mockAuthRepository.authSessionEvents,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockGetCurrentSessionProfileUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => mockLogoutUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
  });

  testWidgets(
    'Full Registration -> Email OTP -> Waiting for Approval -> Approved Home Flow',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      final authBloc = createBloc();
      addTearDown(() async {
        await authBloc.close();
        await tester.binding.setSurfaceSize(null);
      });

      when(
        () => mockRegisterUseCase(any()),
      ).thenAnswer((_) async => const Right('rahul123@example.com'));
      when(() => mockVerifyEmailOtpUseCase(any())).thenAnswer(
        (_) async => Right(buildProfile(AccountApprovalStatus.pending)),
      );
      when(() => mockGetApprovalStatusUseCase(any())).thenAnswer(
        (_) async => Right(buildProfile(AccountApprovalStatus.approved)),
      );

      await tester.pumpWidget(Shiftexapp(authenticationBloc: authBloc));
      authBloc.add(const AuthSessionChanged());
      await pumpTransition(tester);

      // Starts on Screen 4: Login ("Welcome back")
      expect(find.text('Welcome back'), findsOneWidget);
      expect(
        find.text('₹50 registration bonus awaits new members'),
        findsOneWidget,
      );

      // Navigate to Screen 1: Registration ("Create an account")
      await tapVisible(tester, find.text('Create an account'));
      await pumpTransition(tester);
      expect(find.text('Create an account'), findsOneWidget);

      // Fill out registration fields
      await tester.enterText(
        find.widgetWithText(TextFormField, 'First name'),
        'Rahul',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Last name'),
        'Sharma',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mobile number'),
        '9876543210',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'name@example.com'),
        'rahul123@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Create password'),
        'Password1',
      );
      await tester.pump();

      await tapVisible(tester, find.text('Create account'));
      await pumpTransition(tester);

      // Screen 2: Email OTP Verification ("Verify your profile")
      expect(find.text('Verify your profile'), findsOneWidget);
      expect(find.text('Secure Gateway'), findsOneWidget);

      // Enter 6-digit OTP via custom keypad
      for (final digit in ['5', '8', '2', '4', '9', '1']) {
        await tapVisible(tester, find.text(digit).last);
        await tester.pump();
      }

      await tapVisible(tester, find.text('Verify & Continue'));
      await pumpTransition(tester);

      // Screen 3: Waiting for Admin Approval
      expect(find.text('Waiting for Approval'), findsOneWidget);
      expect(find.text('Pending Admin Approval'), findsOneWidget);
      expect(find.text('Expected review: Within 24 hours'), findsOneWidget);

      // Tap "Refresh Status" -> Admin approved -> Redirects to /home
      await tapVisible(tester, find.text('Refresh Status'));
      await pumpTransition(tester);

      expect(find.text('Hello, Rahul'), findsOneWidget);
      expect(find.text('Available Balance'), findsOneWidget);
    },
  );

  testWidgets(
    'Full Password Recovery Flow: Login -> Forgot Password -> Enter Reset Code -> Set New Password -> Login',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      final authBloc = createBloc();
      addTearDown(() async {
        await authBloc.close();
        await tester.binding.setSurfaceSize(null);
      });

      when(
        () => mockForgotPasswordUseCase(any()),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => mockVerifyPasswordResetOtpUseCase(any()),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => mockResetPasswordUseCase(any()),
      ).thenAnswer((_) async => const Right(null));

      await tester.pumpWidget(Shiftexapp(authenticationBloc: authBloc));
      authBloc.add(const AuthSessionChanged());
      await pumpTransition(tester);

      // Tap "Forgot password?" on Login screen
      await tapVisible(tester, find.text('Forgot password?'));
      await pumpTransition(tester);

      // Screen 5: Forgot password?
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('ACCOUNT RECOVERY'), findsOneWidget);
      expect(find.text('Send reset link to Email'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Enter your registered email address',
        ),
        'john.doe@example.com',
      );
      await tester.pump();

      await tapVisible(tester, find.text('Send Reset Code'));
      await pumpTransition(tester);

      // Screen 6: Enter reset code
      expect(find.text('Enter reset code'), findsOneWidget);
      expect(find.text('RESET CODE'), findsOneWidget);

      for (final digit in ['4', '9', '1', '2', '3', '6']) {
        await tapVisible(tester, find.text(digit).last);
        await tester.pump();
      }

      await tapVisible(tester, find.text('Verify Code'));
      await pumpTransition(tester);

      // Set New Password Screen
      expect(find.text('Set new password'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        'NewPassword1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm new password'),
        'NewPassword1',
      );
      await tester.pump();

      await tapVisible(tester, find.text('Update Password'));
      await pumpTransition(tester);

      // Redirected back to Login
      expect(find.text('Welcome back'), findsOneWidget);
    },
  );

  testWidgets(
    'Rejected and Suspended accounts are blocked from accessing /home on login',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      final authBloc = createBloc();
      addTearDown(() async {
        await authBloc.close();
        await tester.binding.setSurfaceSize(null);
      });

      when(() => mockLoginUseCase(any())).thenAnswer(
        (_) async => Right(
          buildProfile(
            AccountApprovalStatus.rejected,
            rejectionReason: 'Document verification failed',
          ),
        ),
      );

      await tester.pumpWidget(Shiftexapp(authenticationBloc: authBloc));
      authBloc.add(const AuthSessionChanged());
      await pumpTransition(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mobile number or email'),
        'rahul123@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter your password'),
        'Password1',
      );
      await tester.pump();

      await tapVisible(tester, find.text('Sign In'));
      await pumpTransition(tester);

      expect(find.text('Approval Declined'), findsOneWidget);
      expect(find.text('Registration Rejected'), findsOneWidget);
      expect(find.text('Document verification failed'), findsOneWidget);
      expect(find.text('Welcome to Shiiftex'), findsNothing);
    },
  );
}
