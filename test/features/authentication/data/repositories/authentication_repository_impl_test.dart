import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/account_approval/data/datasources/account_approval_remote_data_source.dart';
import 'package:shiftex/features/account_approval/data/models/customer_profile_model.dart';
import 'package:shiftex/features/account_approval/data/repositories/account_approval_repository_impl.dart';
import 'package:shiftex/features/account_approval/domain/entities/approval_status.dart';
import 'package:shiftex/features/authentication/data/datasources/authentication_remote_data_source.dart';
import 'package:shiftex/features/authentication/data/repositories/authentication_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthRemoteDataSource extends Mock
    implements AuthenticationRemoteDataSource {}

class MockApprovalRemoteDataSource extends Mock
    implements AccountApprovalRemoteDataSource {}

void main() {
  late MockAuthRemoteDataSource mockAuthDataSource;
  late MockApprovalRemoteDataSource mockApprovalDataSource;
  late AuthenticationRepositoryImpl authRepository;
  late AccountApprovalRepositoryImpl approvalRepository;

  final tPendingProfile = CustomerProfileModel(
    id: 'user-123',
    fullName: 'Rahul Sharma',
    email: 'rahul123@example.com',
    mobileNumber: '+919876543210',
    approvalStatus: AccountApprovalStatus.pending,
    createdAt: DateTime.utc(2026, 11, 16),
    updatedAt: DateTime.utc(2026, 11, 16),
  );

  setUp(() {
    mockAuthDataSource = MockAuthRemoteDataSource();
    mockApprovalDataSource = MockApprovalRemoteDataSource();
    authRepository = AuthenticationRepositoryImpl(mockAuthDataSource);
    approvalRepository = AccountApprovalRepositoryImpl(mockApprovalDataSource);
  });

  group('AuthenticationRepositoryImpl Tests', () {
    test('register returns normalized email on success', () async {
      when(
        () => mockAuthDataSource.register(
          firstName: any(named: 'firstName'),
          lastName: any(named: 'lastName'),
          mobileNumber: any(named: 'mobileNumber'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => 'rahul123@example.com');

      final result = await authRepository.register(
        firstName: 'Rahul',
        lastName: 'Sharma',
        mobileNumber: '+919876543210',
        email: 'Rahul123@example.com',
        password: 'Password1',
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (email) => expect(email, 'rahul123@example.com'),
      );
    });

    test(
      'register maps duplicate email AuthException to EmailAlreadyRegisteredFailure',
      () async {
        when(
          () => mockAuthDataSource.register(
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            mobileNumber: any(named: 'mobileNumber'),
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const AuthException(
            'User already registered',
            code: 'user_already_exists',
          ),
        );

        final result = await authRepository.register(
          firstName: 'Rahul',
          lastName: 'Sharma',
          mobileNumber: '+919876543210',
          email: 'rahul123@example.com',
          password: 'Password1',
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<EmailAlreadyRegisteredFailure>()),
          (_) => fail('Expected Left'),
        );
      },
    );

    test(
      'register maps duplicate mobile trigger exception to MobileAlreadyRegisteredFailure',
      () async {
        when(
          () => mockAuthDataSource.register(
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            mobileNumber: any(named: 'mobileNumber'),
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const AuthException(
            'MOBILE_ALREADY_REGISTERED: This mobile number is already registered.',
          ),
        );

        final result = await authRepository.register(
          firstName: 'Rahul',
          lastName: 'Sharma',
          mobileNumber: '+919876543210',
          email: 'rahul123@example.com',
          password: 'Password1',
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<MobileAlreadyRegisteredFailure>()),
          (_) => fail('Expected Left'),
        );
      },
    );

    test(
      'verifyEmailOtp returns pending CustomerProfileEntity on success',
      () async {
        when(
          () => mockAuthDataSource.verifyEmailOtp(
            email: any(named: 'email'),
            otpCode: any(named: 'otpCode'),
            fullName: any(named: 'fullName'),
            mobileNumber: any(named: 'mobileNumber'),
          ),
        ).thenAnswer((_) async => tPendingProfile);

        final result = await authRepository.verifyEmailOtp(
          email: 'rahul123@example.com',
          otpCode: '582491',
        );

        expect(result.isRight(), isTrue);
        result.fold(
          (_) => fail('Expected Right'),
          (profile) {
            expect(profile.approvalStatus, AccountApprovalStatus.pending);
            expect(profile.isApproved, isFalse);
          },
        );
      },
    );

    test(
      'login maps unverified email exception to EmailNotVerifiedFailure with email',
      () async {
        when(
          () => mockAuthDataSource.login(
            identifier: any(named: 'identifier'),
            password: any(named: 'password'),
            rememberMe: any(named: 'rememberMe'),
          ),
        ).thenThrow(
          const AppAuthException(
            'Please verify your email address before signing in.',
            code: 'email_not_verified',
            email: 'rahul123@example.com',
          ),
        );

        final result = await authRepository.login(
          identifier: 'rahul123@example.com',
          password: 'Password1',
          rememberMe: true,
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) {
            expect(failure, isA<EmailNotVerifiedFailure>());
            expect(
              (failure as EmailNotVerifiedFailure).email,
              'rahul123@example.com',
            );
          },
          (_) => fail('Expected Left'),
        );
      },
    );
  });

  group('AccountApprovalRepositoryImpl Tests', () {
    test('fetchCurrentCustomerProfile returns server profile', () async {
      when(
        () => mockApprovalDataSource.fetchCurrentCustomerProfile(),
      ).thenAnswer((_) async => tPendingProfile);

      final result = await approvalRepository.fetchCurrentCustomerProfile();
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (profile) => expect(profile.id, 'user-123'),
      );
    });
  });
}
