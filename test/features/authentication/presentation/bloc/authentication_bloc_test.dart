import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shiftex/core/errors/failures.dart';
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
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';

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
      id: 'uid-001',
      fullName: 'Rahul Sharma',
      email: 'rahul123@example.com',
      mobileNumber: '+919876543210',
      approvalStatus: status,
      rejectionReason: rejectionReason,
      createdAt: tNow,
      updatedAt: tNow,
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
    registerFallbackValue(
      const VerifyEmailOtpParams(email: '', otpCode: ''),
    );
    registerFallbackValue(const ResendEmailOtpParams(email: ''));
    registerFallbackValue(
      const LoginParams(identifier: '', password: ''),
    );
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

  group('AuthenticationBloc Tests', () {
    blocTest<AuthenticationBloc, AuthenticationState>(
      'emits [AuthenticationLoading, RegistrationSuccess, OtpVerificationRequired] on successful registration',
      build: () {
        when(
          () => mockRegisterUseCase(any()),
        ).thenAnswer((_) async => const Right('rahul123@example.com'));
        return buildBloc();
      },
      act:
          (bloc) => bloc.add(
            const RegisterRequested(
              firstName: 'Rahul',
              lastName: 'Sharma',
              mobileNumber: '+919876543210',
              email: 'Rahul123@example.com',
              password: 'Password1',
            ),
          ),
      expect:
          () => const [
            AuthenticationLoading(activeEmail: 'rahul123@example.com'),
            RegistrationSuccess(
              email: 'rahul123@example.com',
              fullName: 'Rahul Sharma',
              mobileNumber: '+919876543210',
            ),
            OtpVerificationRequired(
              email: 'rahul123@example.com',
              fullName: 'Rahul Sharma',
              mobileNumber: '+919876543210',
            ),
          ],
    );

    blocTest<AuthenticationBloc, AuthenticationState>(
      'emits [AuthenticationLoading, PendingApproval] when email OTP is verified (does NOT grant app access immediately)',
      build: () {
        when(() => mockVerifyEmailOtpUseCase(any())).thenAnswer(
          (_) async => Right(buildProfile(AccountApprovalStatus.pending)),
        );
        return buildBloc();
      },
      act:
          (bloc) => bloc.add(
            const VerifyEmailOtpRequested(
              email: 'rahul123@example.com',
              otpCode: '582491',
            ),
          ),
      expect:
          () => [
            const AuthenticationLoading(activeEmail: 'rahul123@example.com'),
            PendingApproval(buildProfile(AccountApprovalStatus.pending)),
          ],
    );

    blocTest<AuthenticationBloc, AuthenticationState>(
      'emits [AuthenticationLoading, PendingApproval] when a pending customer logs in',
      build: () {
        when(() => mockLoginUseCase(any())).thenAnswer(
          (_) async => Right(buildProfile(AccountApprovalStatus.pending)),
        );
        return buildBloc();
      },
      act:
          (bloc) => bloc.add(
            const LoginRequested(
              identifier: 'rahul123@example.com',
              password: 'Password1',
            ),
          ),
      expect:
          () => [
            const AuthenticationLoading(),
            PendingApproval(buildProfile(AccountApprovalStatus.pending)),
          ],
    );

    blocTest<AuthenticationBloc, AuthenticationState>(
      'emits [AuthenticationLoading, AccountRejected] when a rejected customer logs in',
      build: () {
        when(() => mockLoginUseCase(any())).thenAnswer(
          (_) async => Right(
            buildProfile(
              AccountApprovalStatus.rejected,
              rejectionReason: 'Incomplete KYC verification',
            ),
          ),
        );
        return buildBloc();
      },
      act:
          (bloc) => bloc.add(
            const LoginRequested(
              identifier: 'rahul123@example.com',
              password: 'Password1',
            ),
          ),
      expect:
          () => [
            const AuthenticationLoading(),
            AccountRejected(
              profile: buildProfile(
                AccountApprovalStatus.rejected,
                rejectionReason: 'Incomplete KYC verification',
              ),
              reason: 'Incomplete KYC verification',
            ),
          ],
    );

    blocTest<AuthenticationBloc, AuthenticationState>(
      'emits [AuthenticationLoading, AccountSuspended] when a suspended customer logs in',
      build: () {
        when(() => mockLoginUseCase(any())).thenAnswer(
          (_) async => Right(buildProfile(AccountApprovalStatus.suspended)),
        );
        return buildBloc();
      },
      act:
          (bloc) => bloc.add(
            const LoginRequested(
              identifier: 'rahul123@example.com',
              password: 'Password1',
            ),
          ),
      expect:
          () => [
            const AuthenticationLoading(),
            AccountSuspended(buildProfile(AccountApprovalStatus.suspended)),
          ],
    );

    blocTest<AuthenticationBloc, AuthenticationState>(
      'emits [AuthenticationLoading, AuthenticationSuccess] when an approved customer logs in',
      build: () {
        when(() => mockLoginUseCase(any())).thenAnswer(
          (_) async => Right(buildProfile(AccountApprovalStatus.approved)),
        );
        return buildBloc();
      },
      act:
          (bloc) => bloc.add(
            const LoginRequested(
              identifier: '+919876543210',
              password: 'Password1',
            ),
          ),
      expect:
          () => [
            const AuthenticationLoading(),
            AuthenticationSuccess(buildProfile(AccountApprovalStatus.approved)),
          ],
    );

    blocTest<AuthenticationBloc, AuthenticationState>(
      'CheckApprovalStatusRequested transitions from PendingApproval to AuthenticationSuccess once approved',
      build: () {
        when(() => mockGetApprovalStatusUseCase(any())).thenAnswer(
          (_) async => Right(buildProfile(AccountApprovalStatus.approved)),
        );
        return buildBloc();
      },
      seed: () => PendingApproval(buildProfile(AccountApprovalStatus.pending)),
      act: (bloc) => bloc.add(const CheckApprovalStatusRequested()),
      expect:
          () => [
            AuthenticationLoading(
              currentProfile: buildProfile(AccountApprovalStatus.pending),
            ),
            AuthenticationSuccess(buildProfile(AccountApprovalStatus.approved)),
          ],
    );

    blocTest<AuthenticationBloc, AuthenticationState>(
      'Complete password recovery flow: ForgotPassword -> VerifyResetOtp -> ResetPassword',
      build: () {
        when(
          () => mockForgotPasswordUseCase(any()),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => mockVerifyPasswordResetOtpUseCase(any()),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => mockResetPasswordUseCase(any()),
        ).thenAnswer((_) async => const Right(null));
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const ForgotPasswordRequested(email: 'john.doe@example.com'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(
          const VerifyPasswordResetOtpRequested(
            email: 'john.doe@example.com',
            otpCode: '491023',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const ResetPasswordRequested(newPassword: 'NewSecure1'));
      },
      expect:
          () => const [
            AuthenticationLoading(activeEmail: 'john.doe@example.com'),
            PasswordResetEmailSent(email: 'john.doe@example.com'),
            AuthenticationLoading(activeEmail: 'john.doe@example.com'),
            PasswordResetVerified(email: 'john.doe@example.com'),
            AuthenticationLoading(activeEmail: 'john.doe@example.com'),
            PasswordResetSuccess(),
          ],
    );

    blocTest<AuthenticationBloc, AuthenticationState>(
      'ForgotPassword surfaces RateLimitFailure when rate limit is exceeded',
      build: () {
        when(
          () => mockForgotPasswordUseCase(any()),
        ).thenAnswer((_) async => const Left(RateLimitFailure()));
        return buildBloc();
      },
      act:
          (bloc) => bloc.add(
            const ForgotPasswordRequested(email: 'john.doe@example.com'),
          ),
      expect:
          () => const [
            AuthenticationLoading(activeEmail: 'john.doe@example.com'),
            AuthenticationFailure(
              RateLimitFailure(),
              email: 'john.doe@example.com',
            ),
          ],
    );
  });
}
