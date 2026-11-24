import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/network/network_info.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/core/services/secure_storage_service.dart';
import 'package:shiftex/core/theme/app_theme.dart';
import 'package:shiftex/features/account_approval/domain/entities/approval_status.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';
import 'package:shiftex/features/authentication/presentation/pages/forgot_password_page.dart';
import 'package:shiftex/features/change_email/data/datasources/change_email_remote_data_source.dart';
import 'package:shiftex/features/change_email/data/repositories/change_email_repository_impl.dart';
import 'package:shiftex/features/change_email/domain/entities/change_email_result_entity.dart';
import 'package:shiftex/features/change_email/domain/usecases/change_email_usecase.dart';
import 'package:shiftex/features/change_email/presentation/bloc/change_email_bloc.dart';
import 'package:shiftex/features/change_email/presentation/bloc/change_email_event.dart';
import 'package:shiftex/features/change_email/presentation/bloc/change_email_state.dart';
import 'package:shiftex/features/change_email/presentation/pages/change_email_page.dart';
import 'package:shiftex/features/home/presentation/widgets/customer_profile_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockNetworkInfo extends Mock implements NetworkInfo {}

class _MockSecureStorageService extends Mock implements SecureStorageService {}

class _MockUser extends Mock implements User {}

class _MockSession extends Mock implements Session {}

class _MockAuthResponse extends Mock implements AuthResponse {}

class _MockUserResponse extends Mock implements UserResponse {}

class _MockResendResponse extends Mock implements ResendResponse {}

class _MockChangeEmailUseCase extends Mock implements ChangeEmailUseCase {}

class _MockVerifyEmailChangeOtpUseCase extends Mock
    implements VerifyEmailChangeOtpUseCase {}

class _MockResendEmailChangeUseCase extends Mock
    implements ResendEmailChangeUseCase {}

class _MockCheckEmailChangeStatusUseCase extends Mock
    implements CheckEmailChangeStatusUseCase {}

class _MockAuthenticationBloc
    extends MockBloc<AuthenticationEvent, AuthenticationState>
    implements AuthenticationBloc {}

class _FakeChangeEmailParams extends Fake implements ChangeEmailParams {}

class _FakeVerifyEmailChangeOtpParams extends Fake
    implements VerifyEmailChangeOtpParams {}

class _FakeResendEmailChangeParams extends Fake
    implements ResendEmailChangeParams {}

class _FakeCheckEmailChangeStatusParams extends Fake
    implements CheckEmailChangeStatusParams {}

class _FakeUserAttributes extends Fake implements UserAttributes {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeChangeEmailParams());
    registerFallbackValue(_FakeVerifyEmailChangeOtpParams());
    registerFallbackValue(_FakeResendEmailChangeParams());
    registerFallbackValue(_FakeCheckEmailChangeStatusParams());
    registerFallbackValue(_FakeUserAttributes());
    registerFallbackValue(OtpType.emailChange);
  });

  group('ChangeEmailRemoteDataSource & Repository Tests', () {
    late _MockSupabaseClient mockSupabaseClient;
    late _MockGoTrueClient mockAuthClient;
    late _MockNetworkInfo mockNetworkInfo;
    late _MockSecureStorageService mockSecureStorage;
    late _MockUser mockUser;
    late _MockUser mockUpdatedUser;
    late _MockSession mockSession;
    late _MockAuthResponse mockAuthResponse;
    late _MockUserResponse mockUserResponse;
    late _MockResendResponse mockResendResponse;
    late ChangeEmailRemoteDataSourceImpl remoteDataSource;
    late ChangeEmailRepositoryImpl repository;

    const existingUserId = 'user-uuid-1234-5678';
    const currentEmail = 'rahul@example.com';
    const newEmail = 'rahul.new@example.com';

    setUp(() {
      mockSupabaseClient = _MockSupabaseClient();
      mockAuthClient = _MockGoTrueClient();
      mockNetworkInfo = _MockNetworkInfo();
      mockSecureStorage = _MockSecureStorageService();
      mockUser = _MockUser();
      mockUpdatedUser = _MockUser();
      mockSession = _MockSession();
      mockAuthResponse = _MockAuthResponse();
      mockUserResponse = _MockUserResponse();
      mockResendResponse = _MockResendResponse();

      when(() => mockSupabaseClient.auth).thenReturn(mockAuthClient);
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);

      when(() => mockUser.id).thenReturn(existingUserId);
      when(() => mockUser.email).thenReturn(currentEmail);
      when(() => mockUser.newEmail).thenReturn(null);

      when(() => mockUpdatedUser.id).thenReturn(existingUserId);
      when(() => mockUpdatedUser.email).thenReturn(currentEmail);
      when(() => mockUpdatedUser.newEmail).thenReturn(newEmail);

      when(() => mockSession.isExpired).thenReturn(false);
      when(() => mockAuthResponse.user).thenReturn(mockUser);
      when(() => mockAuthResponse.session).thenReturn(mockSession);
      when(() => mockUserResponse.user).thenReturn(mockUpdatedUser);

      when(
        () => mockSecureStorage.getRememberMe(),
      ).thenAnswer((_) async => true);
      when(
        () => mockSecureStorage.getRememberedIdentifier(),
      ).thenAnswer((_) async => currentEmail);
      when(
        () => mockSecureStorage.saveRememberMe(
          rememberMe: any(named: 'rememberMe'),
          identifier: any(named: 'identifier'),
        ),
      ).thenAnswer((_) async {});

      remoteDataSource = ChangeEmailRemoteDataSourceImpl(
        mockSupabaseClient,
        secureStorageService: mockSecureStorage,
      );
      repository = ChangeEmailRepositoryImpl(
        remoteDataSource: remoteDataSource,
        networkInfo: mockNetworkInfo,
      );
    });

    test(
      'returns SessionExpiredFailure when no authenticated session exists',
      () async {
        when(() => mockAuthClient.currentSession).thenReturn(null);
        when(() => mockAuthClient.currentUser).thenReturn(null);

        final result = await repository.requestEmailChange(
          currentPassword: 'Password1!',
          newEmail: newEmail,
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<SessionExpiredFailure>()),
          (_) => fail('Expected SessionExpiredFailure'),
        );
        verifyNever(
          () => mockAuthClient.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
      },
    );

    test(
      'returns NetworkFailure immediately when device is offline',
      () async {
        when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);

        final result = await repository.requestEmailChange(
          currentPassword: 'Password1!',
          newEmail: newEmail,
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<NetworkFailure>()),
          (_) => fail('Expected NetworkFailure'),
        );
        verifyNever(() => mockAuthClient.currentSession);
      },
    );

    test(
      'verifies current password, calls updateUser(UserAttributes(email: newEmail)) in-place, preserves existing user UUID, and returns pendingVerification when confirmation is enabled',
      () async {
        when(() => mockAuthClient.currentSession).thenReturn(mockSession);
        when(() => mockAuthClient.currentUser).thenReturn(mockUser);
        when(
          () => mockAuthClient.signInWithPassword(
            email: currentEmail,
            password: 'Password1!',
          ),
        ).thenAnswer((_) async => mockAuthResponse);
        when(
          () => mockAuthClient.updateUser(any()),
        ).thenAnswer((_) async => mockUserResponse);

        final result = await repository.requestEmailChange(
          currentPassword: 'Password1!',
          newEmail: '  RAHUL.NEW@EXAMPLE.COM ',
        );

        expect(result.isRight(), isTrue);
        result.fold(
          (failure) => fail('Expected Right, got $failure'),
          (entity) {
            expect(entity.userId, existingUserId);
            expect(entity.currentEmail, currentEmail);
            expect(entity.targetEmail, newEmail);
            expect(entity.status, ChangeEmailStatus.pendingVerification);
            expect(entity.isPendingVerification, isTrue);
          },
        );

        verifyInOrder([
          () => mockAuthClient.signInWithPassword(
            email: currentEmail,
            password: 'Password1!',
          ),
          () => mockAuthClient.updateUser(
            any(
              that: isA<UserAttributes>().having(
                (attrs) => attrs.email,
                'email',
                newEmail,
              ),
            ),
          ),
        ]);
        // Never creates a new account or signs out existing session.
        verifyNever(
          () => mockAuthClient.signUp(
            password: any(named: 'password'),
            email: any(named: 'email'),
          ),
        );
        verifyNever(() => mockAuthClient.signOut());
        // Remembered email is not overwritten while verification is pending.
        verifyNever(
          () => mockSecureStorage.saveRememberMe(
            rememberMe: any(named: 'rememberMe'),
            identifier: any(named: 'identifier'),
          ),
        );
      },
    );

    test(
      'completes immediately and updates remembered email when Supabase email confirmation is disabled',
      () async {
        when(() => mockUpdatedUser.email).thenReturn(newEmail);
        when(() => mockUpdatedUser.newEmail).thenReturn(null);
        when(() => mockAuthClient.currentSession).thenReturn(mockSession);
        when(() => mockAuthClient.currentUser).thenReturn(mockUser);
        when(
          () => mockAuthClient.signInWithPassword(
            email: currentEmail,
            password: 'Password1!',
          ),
        ).thenAnswer((_) async => mockAuthResponse);
        when(
          () => mockAuthClient.updateUser(any()),
        ).thenAnswer((_) async => mockUserResponse);

        final result = await repository.requestEmailChange(
          currentPassword: 'Password1!',
          newEmail: newEmail,
        );

        expect(result.isRight(), isTrue);
        result.fold(
          (failure) => fail('Expected Right, got $failure'),
          (entity) {
            expect(entity.userId, existingUserId);
            expect(entity.currentEmail, newEmail);
            expect(entity.targetEmail, newEmail);
            expect(entity.status, ChangeEmailStatus.completed);
            expect(entity.isCompleted, isTrue);
          },
        );
        verify(
          () => mockSecureStorage.saveRememberMe(
            rememberMe: true,
            identifier: newEmail,
          ),
        ).called(1);
      },
    );

    test(
      'verifies 6-digit OTP via verifyOTP(type: OtpType.emailChange) and preserves existing user UUID',
      () async {
        when(() => mockUpdatedUser.email).thenReturn(newEmail);
        when(() => mockUpdatedUser.newEmail).thenReturn(null);
        when(() => mockAuthClient.currentSession).thenReturn(mockSession);
        when(() => mockAuthClient.currentUser).thenReturn(mockUser);

        final verifyAuthResponse = _MockAuthResponse();
        when(() => verifyAuthResponse.user).thenReturn(mockUpdatedUser);
        when(() => verifyAuthResponse.session).thenReturn(mockSession);

        when(
          () => mockAuthClient.verifyOTP(
            email: newEmail,
            token: '482910',
            type: OtpType.emailChange,
          ),
        ).thenAnswer((_) async => verifyAuthResponse);

        final result = await repository.verifyEmailChangeOtp(
          newEmail: newEmail,
          otpCode: '482910',
        );

        expect(result.isRight(), isTrue);
        result.fold(
          (failure) => fail('Expected Right, got $failure'),
          (entity) {
            expect(entity.userId, existingUserId);
            expect(entity.currentEmail, newEmail);
            expect(entity.targetEmail, newEmail);
            expect(entity.status, ChangeEmailStatus.completed);
          },
        );
        verify(
          () => mockSecureStorage.saveRememberMe(
            rememberMe: true,
            identifier: newEmail,
          ),
        ).called(1);
      },
    );

    test(
      'refreshes status via checkEmailChangeStatus after user clicks email confirmation link',
      () async {
        when(() => mockUpdatedUser.email).thenReturn(newEmail);
        when(() => mockUpdatedUser.newEmail).thenReturn(null);
        when(() => mockAuthClient.currentSession).thenReturn(mockSession);
        when(() => mockAuthClient.currentUser).thenReturn(mockUser);

        final refreshedResponse = _MockAuthResponse();
        when(() => refreshedResponse.user).thenReturn(mockUpdatedUser);
        when(() => refreshedResponse.session).thenReturn(mockSession);

        when(
          () => mockAuthClient.refreshSession(),
        ).thenAnswer((_) async => refreshedResponse);

        final result = await repository.checkEmailChangeStatus(
          targetEmail: newEmail,
        );

        expect(result.isRight(), isTrue);
        result.fold(
          (failure) => fail('Expected Right, got $failure'),
          (entity) {
            expect(entity.userId, existingUserId);
            expect(entity.currentEmail, newEmail);
            expect(entity.targetEmail, newEmail);
            expect(entity.status, ChangeEmailStatus.completed);
          },
        );
      },
    );

    test(
      'resends email change confirmation via resend(type: OtpType.emailChange)',
      () async {
        when(() => mockAuthClient.currentSession).thenReturn(mockSession);
        when(() => mockAuthClient.currentUser).thenReturn(mockUser);
        when(
          () => mockAuthClient.resend(
            email: newEmail,
            type: OtpType.emailChange,
          ),
        ).thenAnswer((_) async => mockResendResponse);

        final result = await repository.resendEmailChangeVerification(
          newEmail: newEmail,
        );

        expect(result, const Right<Failure, Unit>(unit));
        verify(
          () => mockAuthClient.resend(
            email: newEmail,
            type: OtpType.emailChange,
          ),
        ).called(1);
      },
    );

    test(
      'maps wrong password, duplicate email, same email, expired OTP, invalid OTP, and network errors cleanly',
      () async {
        when(() => mockAuthClient.currentSession).thenReturn(mockSession);
        when(() => mockAuthClient.currentUser).thenReturn(mockUser);

        // 1. Wrong current password
        when(
          () => mockAuthClient.signInWithPassword(
            email: currentEmail,
            password: 'WrongPassword1!',
          ),
        ).thenThrow(
          const AuthException(
            'Invalid login credentials',
            code: 'invalid_credentials',
          ),
        );

        final wrongPassResult = await repository.requestEmailChange(
          currentPassword: 'WrongPassword1!',
          newEmail: newEmail,
        );
        wrongPassResult.fold((failure) {
          expect(failure, isA<InvalidCredentialsFailure>());
          expect(
            failure.message,
            'Current password is incorrect. Please check and try again.',
          );
        }, (_) => fail('Expected InvalidCredentialsFailure'));

        // Allow signInWithPassword to succeed for subsequent updateUser tests
        when(
          () => mockAuthClient.signInWithPassword(
            email: currentEmail,
            password: 'Password1!',
          ),
        ).thenAnswer((_) async => mockAuthResponse);

        // 2. Email already in use
        when(() => mockAuthClient.updateUser(any())).thenThrow(
          const AuthException(
            'A user with this email address has already been registered',
            code: 'email_exists',
          ),
        );
        final duplicateResult = await repository.requestEmailChange(
          currentPassword: 'Password1!',
          newEmail: newEmail,
        );
        duplicateResult.fold((failure) {
          expect(failure, isA<EmailAlreadyRegisteredFailure>());
          expect(
            failure.message,
            'An account with this email address already exists.',
          );
        }, (_) => fail('Expected EmailAlreadyRegisteredFailure'));

        // 3. Same email as current
        final sameEmailResult = await repository.requestEmailChange(
          currentPassword: 'Password1!',
          newEmail: currentEmail,
        );
        sameEmailResult.fold((failure) {
          expect(failure, isA<ValidationFailure>());
          expect(
            failure.message,
            'New email must be different from your current email',
          );
        }, (_) => fail('Expected ValidationFailure'));

        // 4. Expired OTP / confirmation token
        when(
          () => mockAuthClient.verifyOTP(
            email: any(named: 'email'),
            token: '123456',
            type: OtpType.emailChange,
          ),
        ).thenThrow(
          const AuthException('Token has expired', code: 'otp_expired'),
        );
        final expiredOtpResult = await repository.verifyEmailChangeOtp(
          newEmail: newEmail,
          otpCode: '123456',
        );
        expiredOtpResult.fold(
          (failure) => expect(failure, isA<ExpiredOtpFailure>()),
          (_) => fail('Expected ExpiredOtpFailure'),
        );

        // 5. Invalid OTP code
        when(
          () => mockAuthClient.verifyOTP(
            email: any(named: 'email'),
            token: '654321',
            type: OtpType.emailChange,
          ),
        ).thenThrow(
          const AuthException('Token is invalid', code: 'invalid_otp'),
        );
        final invalidOtpResult = await repository.verifyEmailChangeOtp(
          newEmail: newEmail,
          otpCode: '654321',
        );
        invalidOtpResult.fold(
          (failure) => expect(failure, isA<InvalidOtpFailure>()),
          (_) => fail('Expected InvalidOtpFailure'),
        );

        // 6. Never displays pendingVerification/success if Supabase did not accept email change
        when(() => mockUpdatedUser.email).thenReturn(currentEmail);
        when(() => mockUpdatedUser.newEmail).thenReturn(null);
        when(
          () => mockAuthClient.updateUser(any()),
        ).thenAnswer((_) async => mockUserResponse);
        final notAcceptedResult = await repository.requestEmailChange(
          currentPassword: 'Password1!',
          newEmail: newEmail,
        );
        notAcceptedResult.fold((failure) {
          expect(failure, isA<ServerFailure>());
          expect(
            failure.message,
            contains('Supabase did not accept the email change request'),
          );
        }, (_) => fail('Expected ServerFailure when email change not accepted'));

        // 7. Secure Email Change two-step OTP verification (currentEmail + newEmail)
        when(() => mockUpdatedUser.email).thenReturn(currentEmail);
        when(() => mockUpdatedUser.newEmail).thenReturn(newEmail);
        when(() => mockUpdatedUser.emailChangeSentAt).thenReturn(
          '2026-11-24T15:56:11Z',
        );
        final step1Response = _MockAuthResponse();
        when(() => step1Response.user).thenReturn(mockUpdatedUser);
        when(() => step1Response.session).thenReturn(mockSession);

        // User enters the 6-digit OTP from their OLD/CURRENT email first:
        // primary attempt on newEmail throws One-time token not found,
        // fallback attempt on currentEmail succeeds!
        when(
          () => mockAuthClient.verifyOTP(
            email: newEmail,
            token: '111222',
            type: OtpType.emailChange,
          ),
        ).thenThrow(
          const AuthException('One-time token not found', code: 'otp_expired'),
        );
        when(
          () => mockAuthClient.verifyOTP(
            email: currentEmail,
            token: '111222',
            type: OtpType.emailChange,
          ),
        ).thenAnswer((_) async => step1Response);
        when(
          () => mockAuthClient.getUser(),
        ).thenAnswer((_) async => mockUserResponse);

        final step1Result = await repository.verifyEmailChangeOtp(
          newEmail: newEmail,
          otpCode: '111222',
          currentEmail: currentEmail,
        );
        expect(step1Result.isRight(), isTrue);
        step1Result.fold(
          (failure) => fail('Expected Step 1 Right, got $failure'),
          (entity) {
            expect(entity.userId, existingUserId);
            expect(entity.status, ChangeEmailStatus.pendingVerification);
            expect(entity.currentEmailVerified, isTrue);
            expect(entity.newEmailVerified, isFalse);
            expect(entity.requiresCurrentEmailVerification, isTrue);
          },
        );

        // Step 2: User enters the 6-digit OTP from their NEW email -> completes!
        when(() => mockUpdatedUser.email).thenReturn(newEmail);
        when(() => mockUpdatedUser.newEmail).thenReturn(null);
        when(
          () => mockAuthClient.verifyOTP(
            email: newEmail,
            token: '333444',
            type: OtpType.emailChange,
          ),
        ).thenAnswer((_) async => step1Response);

        final step2Result = await repository.verifyEmailChangeOtp(
          newEmail: newEmail,
          otpCode: '333444',
          currentEmail: currentEmail,
          currentEmailAlreadyVerified: true,
        );
        expect(step2Result.isRight(), isTrue);
        step2Result.fold(
          (failure) => fail('Expected Step 2 Right, got $failure'),
          (entity) {
            expect(entity.userId, existingUserId);
            expect(entity.status, ChangeEmailStatus.completed);
            expect(entity.currentEmail, newEmail);
            expect(entity.newEmailVerified, isTrue);
            expect(entity.currentEmailVerified, isTrue);
          },
        );

        // 8. Socket / network failure during updateUser
        when(
          () => mockAuthClient.updateUser(any()),
        ).thenThrow(const SocketException('Connection reset'));
        final socketResult = await repository.requestEmailChange(
          currentPassword: 'Password1!',
          newEmail: newEmail,
        );
        socketResult.fold(
          (failure) => expect(failure, isA<NetworkFailure>()),
          (_) => fail('Expected NetworkFailure'),
        );
      },
    );

    test('never leaks plaintext passwords via toString()', () {
      const params = ChangeEmailParams(
        currentPassword: 'SecretPassword123!',
        newEmail: newEmail,
      );
      const event = CurrentPasswordForEmailChanged('SecretPassword123!');
      final form = ChangeEmailFormData.evaluate(
        currentEmail: currentEmail,
        newEmail: newEmail,
        confirmEmail: newEmail,
        currentPassword: 'SecretPassword123!',
        otpCode: '123456',
        pendingTargetEmail: newEmail,
        obscureCurrentPassword: true,
        newEmailTouched: true,
        confirmEmailTouched: true,
        passwordTouched: true,
        otpTouched: true,
      );

      expect(params.toString(), isNot(contains('SecretPassword123!')));
      expect(event.toString(), isNot(contains('SecretPassword123!')));
      expect(form.toString(), isNot(contains('SecretPassword123!')));
    });
  });

  group('ChangeEmailBloc Tests', () {
    late _MockChangeEmailUseCase mockChangeEmailUseCase;
    late _MockVerifyEmailChangeOtpUseCase mockVerifyOtpUseCase;
    late _MockResendEmailChangeUseCase mockResendUseCase;
    late _MockCheckEmailChangeStatusUseCase mockCheckStatusUseCase;

    const existingUserId = 'user-uuid-1234-5678';
    const currentEmail = 'rahul@example.com';
    const newEmail = 'rahul.new@example.com';

    ChangeEmailBloc buildBloc() {
      return ChangeEmailBloc(
        changeEmailUseCase: mockChangeEmailUseCase,
        verifyEmailChangeOtpUseCase: mockVerifyOtpUseCase,
        resendEmailChangeUseCase: mockResendUseCase,
        checkEmailChangeStatusUseCase: mockCheckStatusUseCase,
      );
    }

    setUp(() {
      mockChangeEmailUseCase = _MockChangeEmailUseCase();
      mockVerifyOtpUseCase = _MockVerifyEmailChangeOtpUseCase();
      mockResendUseCase = _MockResendEmailChangeUseCase();
      mockCheckStatusUseCase = _MockCheckEmailChangeStatusUseCase();
    });

    blocTest<ChangeEmailBloc, ChangeEmailState>(
      'validates new email format, confirm email match, same-as-current check, and password presence',
      build: buildBloc,
      act: (bloc) {
        bloc.add(const InitializeChangeEmail(currentEmail));
        bloc.add(const NewEmailChanged(currentEmail)); // same as current
        bloc.add(const NewEmailChanged(newEmail));
        bloc.add(const ConfirmNewEmailChanged('mismatch@example.com'));
        bloc.add(const ConfirmNewEmailChanged(newEmail));
        bloc.add(const CurrentPasswordForEmailChanged('Password1!'));
      },
      verify: (bloc) {
        final state = bloc.state;
        expect(state, isA<ChangeEmailValidationChanged>());
        expect(state.form.currentEmail, currentEmail);
        expect(state.form.isDifferentFromCurrent, isTrue);
        expect(state.form.emailsMatch, isTrue);
        expect(state.form.isValid, isTrue);
      },
    );

    blocTest<ChangeEmailBloc, ChangeEmailState>(
      'blocks submission when new email is identical to current registered email',
      build: buildBloc,
      act: (bloc) {
        bloc.add(const InitializeChangeEmail(currentEmail));
        bloc.add(const NewEmailChanged(currentEmail));
        bloc.add(const ConfirmNewEmailChanged(currentEmail));
        bloc.add(const CurrentPasswordForEmailChanged('Password1!'));
      },
      verify: (bloc) {
        expect(bloc.state.form.isDifferentFromCurrent, isFalse);
        expect(bloc.state.form.isValid, isFalse);
        expect(
          bloc.state.form.newEmailError,
          'New email must be different from your current email',
        );
      },
    );

    blocTest<ChangeEmailBloc, ChangeEmailState>(
      'emits Loading -> PendingVerification -> Success after OTP verification and scrubs password from state',
      build: () {
        when(() => mockChangeEmailUseCase(any())).thenAnswer(
          (_) async => const Right(
            ChangeEmailResultEntity(
              userId: existingUserId,
              currentEmail: currentEmail,
              targetEmail: newEmail,
              status: ChangeEmailStatus.pendingVerification,
              message: 'Verification code sent.',
            ),
          ),
        );
        when(() => mockVerifyOtpUseCase(any())).thenAnswer(
          (_) async => const Right(
            ChangeEmailResultEntity(
              userId: existingUserId,
              currentEmail: newEmail,
              targetEmail: newEmail,
              status: ChangeEmailStatus.completed,
              message: 'Email verified and updated.',
            ),
          ),
        );
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const InitializeChangeEmail(currentEmail));
        bloc.add(const NewEmailChanged(newEmail));
        bloc.add(const ConfirmNewEmailChanged(newEmail));
        bloc.add(const CurrentPasswordForEmailChanged('Password1!'));
        bloc.add(const SubmitChangeEmail());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EmailChangeOtpChanged('482910'));
        bloc.add(const VerifyChangeEmailOtpRequested());
      },
      verify: (bloc) {
        final state = bloc.state;
        expect(state, isA<ChangeEmailSuccess>());
        final success = state as ChangeEmailSuccess;
        expect(success.userId, existingUserId);
        expect(success.confirmedEmail, newEmail);
        expect(success.form.currentPassword, isEmpty);
        expect(success.form.currentEmail, newEmail);
      },
    );
  });

  group('ChangeEmailPage & Profile Navigation Widget Tests', () {
    late _MockChangeEmailUseCase mockChangeEmailUseCase;
    late _MockVerifyEmailChangeOtpUseCase mockVerifyOtpUseCase;
    late _MockResendEmailChangeUseCase mockResendUseCase;
    late _MockCheckEmailChangeStatusUseCase mockCheckStatusUseCase;

    const existingUserId = 'user-uuid-1234-5678';
    const currentEmail = 'rahul@example.com';
    const newEmail = 'rahul.new@example.com';

    ChangeEmailBloc createBloc() {
      return ChangeEmailBloc(
        changeEmailUseCase: mockChangeEmailUseCase,
        verifyEmailChangeOtpUseCase: mockVerifyOtpUseCase,
        resendEmailChangeUseCase: mockResendUseCase,
        checkEmailChangeStatusUseCase: mockCheckStatusUseCase,
      );
    }

    setUp(() {
      mockChangeEmailUseCase = _MockChangeEmailUseCase();
      mockVerifyOtpUseCase = _MockVerifyEmailChangeOtpUseCase();
      mockResendUseCase = _MockResendEmailChangeUseCase();
      mockCheckStatusUseCase = _MockCheckEmailChangeStatusUseCase();
    });

    Widget buildStandalonePage(ChangeEmailBloc bloc, {Size? size}) {
      final child = MaterialApp(
        theme: AppTheme.lightTheme,
        home: ChangeEmailPage(
          bloc: bloc,
          initialCurrentEmail: currentEmail,
        ),
      );
      if (size == null) return child;
      return MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      );
    }

    testWidgets(
      'displays current email read-only, validates inputs, transitions to Pending Verification, verifies 6-digit OTP, and shows Success view',
      (tester) async {
        when(() => mockChangeEmailUseCase(any())).thenAnswer(
          (_) async => const Right(
            ChangeEmailResultEntity(
              userId: existingUserId,
              currentEmail: currentEmail,
              targetEmail: newEmail,
              status: ChangeEmailStatus.pendingVerification,
              message:
                  'We sent a verification code and confirmation link to rahul.new@example.com.',
            ),
          ),
        );
        when(() => mockVerifyOtpUseCase(any())).thenAnswer(
          (_) async => const Right(
            ChangeEmailResultEntity(
              userId: existingUserId,
              currentEmail: newEmail,
              targetEmail: newEmail,
              status: ChangeEmailStatus.completed,
              message:
                  'Your email address has been verified and updated to rahul.new@example.com.',
            ),
          ),
        );

        final bloc = createBloc();
        addTearDown(bloc.close);

        await tester.pumpWidget(buildStandalonePage(bloc));
        await tester.pumpAndSettle();

        expect(find.text('Change Email'), findsAtLeastNWidgets(1));
        expect(find.text('Update your registered email'), findsOneWidget);
        expect(find.text('Update Registered Email'), findsOneWidget);
        expect(find.text(currentEmail), findsOneWidget);
        expect(find.text('Current'), findsOneWidget);
        expect(find.text('How Email Verification Works'), findsOneWidget);

        // Submit button initially disabled
        final initialButton = tester.widget<ElevatedButton>(
          find.descendant(
            of: find.byKey(const ValueKey('change_email_submit_button')),
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(initialButton.onPressed, isNull);

        // Enter new email, confirm email, and current password
        await tester.enterText(
          find.byKey(const ValueKey('change_email_new_field')),
          newEmail,
        );
        await tester.enterText(
          find.byKey(const ValueKey('change_email_confirm_field')),
          newEmail,
        );
        await tester.enterText(
          find.byKey(const ValueKey('change_email_password_field')),
          'Password1!',
        );
        await tester.pumpAndSettle();

        expect(find.text('Email addresses match'), findsOneWidget);

        final submitFinder = find.byKey(
          const ValueKey('change_email_submit_button'),
        );
        await tester.ensureVisible(submitFinder);
        await tester.pumpAndSettle();

        await tester.tap(submitFinder);
        await tester.pumpAndSettle();

        // Pending verification view is displayed with confirmation banner
        expect(
          find.byKey(const ValueKey('change_email_pending_view')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const ValueKey('change_email_pending_confirmation_banner'),
          ),
          findsOneWidget,
        );
        expect(find.text('Verification Code Sent'), findsOneWidget);
        expect(find.text('Verify Your New Email'), findsOneWidget);
        expect(find.text('Pending Confirmation'), findsOneWidget);
        expect(find.text('Active email: $currentEmail'), findsOneWidget);
        expect(find.text('Pending new email: $newEmail'), findsOneWidget);

        // Enter 6-digit OTP and verify
        await tester.enterText(
          find.byKey(const ValueKey('change_email_otp_field')),
          '482910',
        );
        await tester.pumpAndSettle();

        final verifyButton = find.byKey(
          const ValueKey('change_email_verify_otp_button'),
        );
        await tester.ensureVisible(verifyButton);
        await tester.tap(verifyButton);
        await tester.pumpAndSettle();

        // Success view is displayed
        expect(
          find.byKey(const ValueKey('change_email_success_view')),
          findsOneWidget,
        );
        expect(find.text('Email Updated Successfully'), findsOneWidget);
        expect(
          find.text('Active email: $newEmail • Account & rewards preserved.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'displays error banner with Forgot Password action when current password is wrong, and navigates from Profile Sheet -> Change Email',
      (tester) async {
        when(() => mockChangeEmailUseCase(any())).thenAnswer(
          (_) async => const Left(
            InvalidCredentialsFailure(
              'Current password is incorrect. Please check and try again.',
            ),
          ),
        );

        final mockAuthBloc = _MockAuthenticationBloc();
        final now = DateTime.utc(2026, 11, 24);
        final profile = CustomerProfileEntity(
          id: existingUserId,
          fullName: 'Rahul Sharma',
          email: currentEmail,
          mobileNumber: '+919876543210',
          approvalStatus: AccountApprovalStatus.approved,
          createdAt: now,
          updatedAt: now,
        );
        when(() => mockAuthBloc.state).thenReturn(AuthenticationSuccess(profile));
        whenListen<AuthenticationState>(
          mockAuthBloc,
          const Stream<AuthenticationState>.empty(),
          initialState: AuthenticationSuccess(profile),
        );

        final bloc = createBloc();
        addTearDown(bloc.close);

        final router = GoRouter(
          initialLocation: RoutesNames.home,
          routes: [
            GoRoute(
              path: RoutesNames.home,
              builder: (context, state) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      final activeRouter = GoRouter.maybeOf(context);
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => CustomerProfileSheet(
                          fallbackFullName: 'Rahul Sharma',
                          fallbackEmail: currentEmail,
                          fallbackMobile: '+919876543210',
                          onChangeEmail: () {
                            activeRouter?.push(RoutesNames.changeEmail);
                          },
                          onChangePassword: () {},
                          onSignOut: () {},
                        ),
                      );
                    },
                    child: const Text('Open Profile'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: RoutesNames.changeEmail,
              builder: (context, state) => ChangeEmailPage(bloc: bloc),
            ),
            GoRoute(
              path: RoutesNames.forgotPassword,
              builder: (context, state) => ForgotPasswordPage(
                initialEmail: state.uri.queryParameters['email'],
                fromChangePassword:
                    state.uri.queryParameters['from'] == 'change-password',
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          BlocProvider<AuthenticationBloc>.value(
            value: mockAuthBloc,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Profile'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('profile_change_email_tile')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('profile_change_email_tile')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Update Registered Email'), findsOneWidget);
        expect(find.text(currentEmail), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('change_email_new_field')),
          newEmail,
        );
        await tester.enterText(
          find.byKey(const ValueKey('change_email_confirm_field')),
          newEmail,
        );
        await tester.enterText(
          find.byKey(const ValueKey('change_email_password_field')),
          'WrongPassword1!',
        );
        await tester.pumpAndSettle();

        final submitFinder = find.byKey(
          const ValueKey('change_email_submit_button'),
        );
        await tester.ensureVisible(submitFinder);
        await tester.tap(submitFinder);
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Current password is incorrect. Please check and try again.',
          ),
          findsAtLeastNWidgets(1),
        );
        expect(
          find.byKey(
            const ValueKey('change_email_failure_forgot_password_button'),
          ),
          findsOneWidget,
        );
      },
    );

    for (final viewport in const [
      Size(320, 568),
      Size(375, 812),
      Size(430, 932),
    ]) {
      testWidgets(
        'renders ChangeEmailPage without overflow at ${viewport.width.toInt()}x${viewport.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final bloc = createBloc();
          addTearDown(bloc.close);

          await tester.pumpWidget(buildStandalonePage(bloc, size: viewport));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Update Registered Email'), findsOneWidget);
        },
      );
    }
  });
}
