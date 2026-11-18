import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/core/utils/usecase.dart';
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
import 'package:shiftex/features/customer_qr/data/datasources/customer_qr_remote_data_source.dart';
import 'package:shiftex/features/customer_qr/data/models/customer_qr_model.dart';
import 'package:shiftex/features/customer_qr/domain/entities/customer_qr_entity.dart';
import 'package:shiftex/features/customer_qr/domain/usecases/get_customer_personal_qr_usecase.dart';
import 'package:shiftex/features/customer_qr/domain/usecases/revoke_customer_personal_qr_usecase.dart';
import 'package:shiftex/features/customer_qr/presentation/bloc/customer_qr_bloc.dart';
import 'package:shiftex/features/customer_qr/presentation/bloc/customer_qr_event.dart';
import 'package:shiftex/features/customer_qr/presentation/bloc/customer_qr_state.dart';
import 'package:shiftex/features/customer_qr/presentation/pages/customer_qr_page.dart';
import 'package:shiftex/features/home/domain/entities/daily_streak_entity.dart';
import 'package:shiftex/features/home/domain/entities/home_dashboard_entity.dart';
import 'package:shiftex/features/home/domain/entities/wallet_summary_entity.dart';
import 'package:shiftex/features/home/domain/usecases/generate_claim_qr_usecase.dart';
import 'package:shiftex/features/home/domain/usecases/get_home_dashboard_usecase.dart';
import 'package:shiftex/features/home/domain/usecases/track_advertisement_event_usecase.dart';
import 'package:shiftex/features/home/presentation/bloc/home_bloc.dart';
import 'package:shiftex/features/home/presentation/pages/home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockGetCustomerPersonalQrUseCase extends Mock
    implements GetCustomerPersonalQrUseCase {}

class _MockRevokeCustomerPersonalQrUseCase extends Mock
    implements RevokeCustomerPersonalQrUseCase {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockGetHomeDashboardUseCase extends Mock
    implements GetHomeDashboardUseCase {}

class _MockGenerateClaimQrUseCase extends Mock
    implements GenerateClaimQrUseCase {}

class _MockTrackAdvertisementEventUseCase extends Mock
    implements TrackAdvertisementEventUseCase {}

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
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  final tNow = DateTime.utc(2026, 11, 17, 9, 0);

  CustomerQrEntity buildQrEntity({
    String customerId = '99999999-aaaa-bbbb-cccc-111111111111',
    String fullName = 'Vishnu K.',
    String membershipId = 'SHFT-8921-VK',
    String tokenCode = 'ACC-8921-VK01',
    String qrPayload = 'SHIIFTEX:ACCRUAL:V1:ACC-8921-VK01:4F8B2C1D9E7A6543',
    String status = 'active',
    bool allowDeduction = false,
    String tokenPurpose = 'accrual',
    DateTime? expiresAt,
  }) {
    return CustomerQrEntity(
      customerId: customerId,
      fullName: fullName,
      membershipId: membershipId,
      membershipTier: 'Pebble Black Member',
      tokenId: 'tok-accrual-1',
      tokenCode: tokenCode,
      qrPayload: qrPayload,
      tokenPurpose: tokenPurpose,
      allowDeduction: allowDeduction,
      status: status,
      expiresAt: expiresAt ?? tNow.add(const Duration(minutes: 15)),
      createdAt: tNow,
    );
  }

  HomeDashboardEntity buildHomeDashboard() {
    return HomeDashboardEntity(
      customerId: '99999999-aaaa-bbbb-cccc-111111111111',
      fullName: 'Vishnu K.',
      email: 'vishnu@example.com',
      mobileNumber: '+919876543210',
      wallet: const WalletSummaryEntity(
        customerCode: 'SHFT-8921-VK',
        membershipTier: 'Pebble Black Member',
        availablePoints: 2450,
        lockedPoints: 550,
        lifetimeEarnedPoints: 3000,
        lifetimeRedeemedPoints: 0,
        pointsEarnedToday: 15,
        pointsToInrRate: 0.10,
      ),
      nextUnlockAllocation: null,
      lockedAllocations: const [],
      streak: DailyStreakEntity(
        dailyLoginEnabled: true,
        dailyPoints: 15,
        currentStreakDay: 4,
        claimedToday: true,
        daysRemaining: 3,
        cycleDate: '2026-11-17',
        nextResetAt: tNow.add(const Duration(hours: 18)),
        justCompletedDay7: false,
        completedStreakPoints: 0,
      ),
      advertisements: const [],
      recentTransactions: const [],
    );
  }

  AuthenticationBloc buildIdleAuthBloc() {
    final mockAuthRepo = _MockAuthenticationRepository();
    when(
      () => mockAuthRepo.authSessionEvents,
    ).thenAnswer((_) => const Stream.empty());

    return AuthenticationBloc(
      registerUseCase: _MockRegisterUseCase(),
      verifyEmailOtpUseCase: _MockVerifyEmailOtpUseCase(),
      resendEmailOtpUseCase: _MockResendEmailOtpUseCase(),
      loginUseCase: _MockLoginUseCase(),
      logoutUseCase: _MockLogoutUseCase(),
      forgotPasswordUseCase: _MockForgotPasswordUseCase(),
      verifyPasswordResetOtpUseCase: _MockVerifyPasswordResetOtpUseCase(),
      resetPasswordUseCase: _MockResetPasswordUseCase(),
      getCurrentSessionProfileUseCase: _MockGetCurrentSessionProfileUseCase(),
      getApprovalStatusUseCase: _MockGetApprovalStatusUseCase(),
      authRepository: mockAuthRepo,
    );
  }

  setUpAll(() {
    registerFallbackValue(const GetCustomerPersonalQrParams());
    registerFallbackValue(const GetHomeDashboardParams());
    registerFallbackValue(const NoParams());
    registerFallbackValue(
      const TrackAdvertisementEventParams(
        advertisementId: '',
        eventType: 'impression',
      ),
    );
  });

  group('Customer QR Domain, Security & Data Tests', () {
    test(
      'Model parses RPC payload and enforces accrual-only non-PII contract',
      () {
        final model = CustomerQrModel.fromJson({
          'customer_id': '99999999-aaaa-bbbb-cccc-111111111111',
          'full_name': 'Vishnu K.',
          'membership_id': 'SHFT-8921-VK',
          'membership_tier': 'Pebble Black Member',
          'token_id': 'tok-1',
          'token_code': 'ACC-8921-VK01',
          'qr_payload': 'SHIIFTEX:ACCRUAL:V1:ACC-8921-VK01:4F8B2C1D9E7A6543',
          'token_purpose': 'accrual',
          'allow_deduction': false,
          'status': 'active',
          'expires_at': tNow.add(const Duration(minutes: 15)).toIso8601String(),
          'created_at': tNow.toIso8601String(),
        });

        expect(model.fullName, 'Vishnu K.');
        expect(model.membershipId, 'SHFT-8921-VK');
        expect(model.isAccrualOnly, isTrue);
        expect(model.isExpiredAt(tNow), isFalse);
        expect(model.isExpiredAt(tNow.add(const Duration(minutes: 16))), isTrue);

        // Ensure opaque token does not encode PII, passwords, or wallet balances
        expect(model.qrPayload, startsWith('SHIIFTEX:ACCRUAL:V1:'));
        expect(model.qrPayload.toLowerCase(), isNot(contains('vishnu')));
        expect(model.qrPayload, isNot(contains('@')));
        expect(model.qrPayload, isNot(contains('9876543210')));
        expect(model.qrPayload, isNot(contains('2450')));
      },
    );

    test(
      'RemoteDataSource rejects unauthenticated sessions cleanly',
      () async {
        final mockSupabase = _MockSupabaseClient();
        final mockAuth = _MockGoTrueClient();
        when(() => mockSupabase.auth).thenReturn(mockAuth);
        when(() => mockAuth.currentUser).thenReturn(null);

        final dataSource = CustomerQrRemoteDataSourceImpl(mockSupabase);

        expect(
          () => dataSource.getCustomerPersonalQr(),
          throwsA(isA<AppAuthException>()),
        );
        expect(
          () => dataSource.revokePersonalQr(),
          throwsA(isA<AppAuthException>()),
        );
      },
    );
  });

  group('CustomerQrBloc Unit Tests', () {
    late _MockGetCustomerPersonalQrUseCase mockGetQrUseCase;
    late _MockRevokeCustomerPersonalQrUseCase mockRevokeQrUseCase;

    setUp(() {
      mockGetQrUseCase = _MockGetCustomerPersonalQrUseCase();
      mockRevokeQrUseCase = _MockRevokeCustomerPersonalQrUseCase();
    });

    blocTest<CustomerQrBloc, CustomerQrState>(
      'emits loading -> loaded with customer personal accrual QR',
      build: () {
        when(
          () => mockGetQrUseCase(any()),
        ).thenAnswer((_) async => Right(buildQrEntity()));
        return CustomerQrBloc(
          getCustomerPersonalQrUseCase: mockGetQrUseCase,
          revokeCustomerPersonalQrUseCase: mockRevokeQrUseCase,
          clockProvider: () => tNow,
        );
      },
      act: (bloc) => bloc.add(const CustomerQrLoadRequested()),
      expect: () => [
        const CustomerQrState(status: CustomerQrStatus.loading),
        CustomerQrState(
          status: CustomerQrStatus.loaded,
          qrData: buildQrEntity(),
          isExpired: false,
        ),
      ],
    );

    blocTest<CustomerQrBloc, CustomerQrState>(
      'copies membership ID (never auth UUID) and emits feedback message',
      build: () {
        final copiedValues = <String>[];
        when(
          () => mockGetQrUseCase(any()),
        ).thenAnswer((_) async => Right(buildQrEntity()));

        return CustomerQrBloc(
          getCustomerPersonalQrUseCase: mockGetQrUseCase,
          revokeCustomerPersonalQrUseCase: mockRevokeQrUseCase,
          clockProvider: () => tNow,
          copyToClipboard: (value) async {
            copiedValues.add(value);
            expect(value, 'SHFT-8921-VK');
            expect(value, isNot('99999999-aaaa-bbbb-cccc-111111111111'));
          },
        );
      },
      act: (bloc) async {
        bloc.add(const CustomerQrLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CustomerIdCopyRequested());
      },
      expect: () => [
        const CustomerQrState(status: CustomerQrStatus.loading),
        CustomerQrState(
          status: CustomerQrStatus.loaded,
          qrData: buildQrEntity(),
          isExpired: false,
        ),
        CustomerQrState(
          status: CustomerQrStatus.loaded,
          qrData: buildQrEntity(),
          isExpired: false,
          infoMessage: 'Customer ID SHFT-8921-VK copied to clipboard.',
          feedbackSequence: 1,
        ),
      ],
    );

    blocTest<CustomerQrBloc, CustomerQrState>(
      'handles clipboard failures gracefully without losing QR state',
      build: () {
        when(
          () => mockGetQrUseCase(any()),
        ).thenAnswer((_) async => Right(buildQrEntity()));

        return CustomerQrBloc(
          getCustomerPersonalQrUseCase: mockGetQrUseCase,
          revokeCustomerPersonalQrUseCase: mockRevokeQrUseCase,
          clockProvider: () => tNow,
          copyToClipboard: (_) async {
            throw PlatformException(code: 'clipboard_error');
          },
        );
      },
      act: (bloc) async {
        bloc.add(const CustomerQrLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CustomerIdCopyRequested());
      },
      expect: () => [
        const CustomerQrState(status: CustomerQrStatus.loading),
        CustomerQrState(
          status: CustomerQrStatus.loaded,
          qrData: buildQrEntity(),
          isExpired: false,
        ),
        CustomerQrState(
          status: CustomerQrStatus.loaded,
          qrData: buildQrEntity(),
          isExpired: false,
          errorMessage:
              'Unable to copy customer ID right now. Please try again.',
          feedbackSequence: 1,
        ),
      ],
    );

    blocTest<CustomerQrBloc, CustomerQrState>(
      'automatically refreshes expired QR token on expiry check',
      build: () {
        final expiredQr = buildQrEntity(
          tokenCode: 'ACC-OLD1-0001',
          qrPayload: 'SHIIFTEX:ACCRUAL:V1:ACC-OLD1-0001:AAAA',
          expiresAt: tNow.subtract(const Duration(minutes: 1)),
        );
        final refreshedQr = buildQrEntity(
          tokenCode: 'ACC-NEW2-0002',
          qrPayload: 'SHIIFTEX:ACCRUAL:V1:ACC-NEW2-0002:BBBB',
          expiresAt: tNow.add(const Duration(minutes: 15)),
        );

        when(
          () => mockGetQrUseCase(const GetCustomerPersonalQrParams()),
        ).thenAnswer((_) async => Right(expiredQr));
        when(
          () => mockGetQrUseCase(
            const GetCustomerPersonalQrParams(forceRegenerate: true),
          ),
        ).thenAnswer((_) async => Right(refreshedQr));

        return CustomerQrBloc(
          getCustomerPersonalQrUseCase: mockGetQrUseCase,
          revokeCustomerPersonalQrUseCase: mockRevokeQrUseCase,
          clockProvider: () => tNow,
        );
      },
      act: (bloc) async {
        bloc.add(const CustomerQrLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(CustomerQrExpiryChecked(now: tNow));
      },
      expect: () => [
        const CustomerQrState(status: CustomerQrStatus.loading),
        CustomerQrState(
          status: CustomerQrStatus.loaded,
          qrData: buildQrEntity(
            tokenCode: 'ACC-OLD1-0001',
            qrPayload: 'SHIIFTEX:ACCRUAL:V1:ACC-OLD1-0001:AAAA',
            expiresAt: tNow.subtract(const Duration(minutes: 1)),
          ),
          isExpired: true,
        ),
        CustomerQrState(
          status: CustomerQrStatus.refreshing,
          qrData: buildQrEntity(
            tokenCode: 'ACC-OLD1-0001',
            qrPayload: 'SHIIFTEX:ACCRUAL:V1:ACC-OLD1-0001:AAAA',
            expiresAt: tNow.subtract(const Duration(minutes: 1)),
          ),
          isExpired: true,
        ),
        CustomerQrState(
          status: CustomerQrStatus.loaded,
          qrData: buildQrEntity(
            tokenCode: 'ACC-NEW2-0002',
            qrPayload: 'SHIIFTEX:ACCRUAL:V1:ACC-NEW2-0002:BBBB',
            expiresAt: tNow.add(const Duration(minutes: 15)),
          ),
          isExpired: false,
          infoMessage: 'Expired QR refreshed automatically.',
          feedbackSequence: 1,
        ),
      ],
    );

    blocTest<CustomerQrBloc, CustomerQrState>(
      'emits error state when initial load fails',
      build: () {
        when(() => mockGetQrUseCase(any())).thenAnswer(
          (_) async => const Left(ServerFailure('Network request failed')),
        );
        return CustomerQrBloc(
          getCustomerPersonalQrUseCase: mockGetQrUseCase,
          revokeCustomerPersonalQrUseCase: mockRevokeQrUseCase,
          clockProvider: () => tNow,
        );
      },
      act: (bloc) => bloc.add(const CustomerQrLoadRequested()),
      expect: () => [
        const CustomerQrState(status: CustomerQrStatus.loading),
        const CustomerQrState(
          status: CustomerQrStatus.error,
          errorMessage: 'Network request failed',
          feedbackSequence: 1,
        ),
      ],
    );

    blocTest<CustomerQrBloc, CustomerQrState>(
      'revokes active QR code and marks state inactive',
      build: () {
        when(
          () => mockGetQrUseCase(any()),
        ).thenAnswer((_) async => Right(buildQrEntity()));
        when(
          () => mockRevokeQrUseCase(any()),
        ).thenAnswer((_) async => const Right(true));
        return CustomerQrBloc(
          getCustomerPersonalQrUseCase: mockGetQrUseCase,
          revokeCustomerPersonalQrUseCase: mockRevokeQrUseCase,
          clockProvider: () => tNow,
        );
      },
      act: (bloc) async {
        bloc.add(const CustomerQrLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CustomerQrRevokeRequested());
      },
      expect: () => [
        const CustomerQrState(status: CustomerQrStatus.loading),
        CustomerQrState(
          status: CustomerQrStatus.loaded,
          qrData: buildQrEntity(),
          isExpired: false,
        ),
        CustomerQrState(
          status: CustomerQrStatus.refreshing,
          qrData: buildQrEntity(),
          isExpired: false,
        ),
        CustomerQrState(
          status: CustomerQrStatus.loaded,
          qrData: buildQrEntity(status: 'revoked'),
          isExpired: true,
          infoMessage:
              'Current QR code revoked. Refresh to generate a new pass.',
          feedbackSequence: 1,
        ),
      ],
    );
  });

  group('Customer QR Page Widget & Navigation Tests', () {
    late _MockGetCustomerPersonalQrUseCase mockGetQrUseCase;
    late _MockRevokeCustomerPersonalQrUseCase mockRevokeQrUseCase;

    setUp(() {
      mockGetQrUseCase = _MockGetCustomerPersonalQrUseCase();
      mockRevokeQrUseCase = _MockRevokeCustomerPersonalQrUseCase();
    });

    testWidgets(
      'renders Add Points pass, Copy ID confirmation, Done navigation, and earning steps',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final copiedValues = <String>[];
        when(
          () => mockGetQrUseCase(any()),
        ).thenAnswer((_) async => Right(buildQrEntity()));

        final authBloc = buildIdleAuthBloc();
        final homeBloc = HomeBloc(
          getHomeDashboardUseCase: _MockGetHomeDashboardUseCase(),
          generateClaimQrUseCase: _MockGenerateClaimQrUseCase(),
          trackAdvertisementEventUseCase: _MockTrackAdvertisementEventUseCase(),
        );
        final qrBloc = CustomerQrBloc(
          getCustomerPersonalQrUseCase: mockGetQrUseCase,
          revokeCustomerPersonalQrUseCase: mockRevokeQrUseCase,
          clockProvider: () => tNow,
          copyToClipboard: (value) async => copiedValues.add(value),
        );

        addTearDown(() async {
          await qrBloc.close();
          await homeBloc.close();
          await authBloc.close();
        });

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<AuthenticationBloc>.value(value: authBloc),
              BlocProvider<HomeBloc>.value(value: homeBloc),
            ],
            child: MaterialApp(home: CustomerQrPage(bloc: qrBloc)),
          ),
        );
        await _pumpFrames(tester);

        expect(find.text('Add Points'), findsOneWidget);
        expect(
          find.text(
            'Present this QR code to the cashier to\ncredit points to your account',
          ),
          findsOneWidget,
        );
        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.text('Vishnu K.'), findsOneWidget);
        expect(find.text('SHFT-8921-VK'), findsOneWidget);
        expect(find.text('Copy ID'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(
          find.text('Accrual pass only • Cannot charge or deduct'),
          findsOneWidget,
        );

        expect(find.text('How Earning Works'), findsOneWidget);
        expect(find.text('3 simple steps'), findsOneWidget);
        expect(find.text('Present Pass at Checkout'), findsOneWidget);
        expect(find.text('Cashier Scans & Enters Bill'), findsOneWidget);
        expect(find.text('Instant Account Credit'), findsOneWidget);
        expect(
          find.text(
            "Points arrive in your available or future balance according to the Admin's allocation rules.",
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Copy ID'));
        await _pumpFrames(tester);

        expect(copiedValues, ['SHFT-8921-VK']);
        expect(
          find.text('Customer ID SHFT-8921-VK copied to clipboard.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'navigates from Home bottom nav center QR button to Personal QR Display and back via Done',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mockGetHomeDashboardUseCase = _MockGetHomeDashboardUseCase();
        when(
          () => mockGetHomeDashboardUseCase(any()),
        ).thenAnswer((_) async => Right(buildHomeDashboard()));
        when(
          () => mockGetQrUseCase(any()),
        ).thenAnswer((_) async => Right(buildQrEntity()));

        final authBloc = buildIdleAuthBloc();
        final homeBloc = HomeBloc(
          getHomeDashboardUseCase: mockGetHomeDashboardUseCase,
          generateClaimQrUseCase: _MockGenerateClaimQrUseCase(),
          trackAdvertisementEventUseCase: _MockTrackAdvertisementEventUseCase(),
        );
        final qrBloc = CustomerQrBloc(
          getCustomerPersonalQrUseCase: mockGetQrUseCase,
          revokeCustomerPersonalQrUseCase: mockRevokeQrUseCase,
          clockProvider: () => tNow,
        );

        final router = GoRouter(
          initialLocation: RoutesNames.home,
          routes: [
            GoRoute(
              path: RoutesNames.home,
              builder: (_, _) => HomePage(homeBloc: homeBloc),
            ),
            GoRoute(
              path: RoutesNames.customerQr,
              builder: (_, _) => CustomerQrPage(bloc: qrBloc),
            ),
          ],
        );

        addTearDown(() async {
          router.dispose();
          await qrBloc.close();
          await homeBloc.close();
          await authBloc.close();
        });

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<AuthenticationBloc>.value(value: authBloc),
              BlocProvider<HomeBloc>.value(value: homeBloc),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await _pumpFrames(tester);

        expect(find.text('Hello, Vishnu'), findsOneWidget);

        // Tap center QR button in bottom navigation bar -> opens /customer-qr
        await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded));
        await _pumpFrames(tester);

        expect(find.text('Add Points'), findsOneWidget);
        expect(find.text('How Earning Works'), findsOneWidget);

        // Tap Done -> returns cleanly to Home
        await tester.ensureVisible(find.text('Done'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        expect(find.text('Hello, Vishnu'), findsOneWidget);
        expect(find.text('Add Points'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'displays error recovery card cleanly and retries on Retry button',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(375, 812));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        int callCount = 0;
        when(() => mockGetQrUseCase(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return const Left(
              ServerFailure('Unable to reach rewards server.'),
            );
          }
          return Right(buildQrEntity());
        });

        final qrBloc = CustomerQrBloc(
          getCustomerPersonalQrUseCase: mockGetQrUseCase,
          revokeCustomerPersonalQrUseCase: mockRevokeQrUseCase,
          clockProvider: () => tNow,
        );
        addTearDown(() => qrBloc.close());

        await tester.pumpWidget(
          MaterialApp(home: CustomerQrPage(bloc: qrBloc)),
        );
        await _pumpFrames(tester);

        expect(find.text('Unable to reach rewards server.'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        await tester.tap(find.text('Retry'));
        await _pumpFrames(tester);

        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.text('SHFT-8921-VK'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    for (final viewport in [
      const Size(320, 568),
      const Size(375, 812),
      const Size(430, 932),
    ]) {
      testWidgets(
        'renders without overflow at ${viewport.width.toInt()}x${viewport.height.toInt()}',
        (WidgetTester tester) async {
          await tester.binding.setSurfaceSize(viewport);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          when(
            () => mockGetQrUseCase(any()),
          ).thenAnswer((_) async => Right(buildQrEntity()));

          final qrBloc = CustomerQrBloc(
            getCustomerPersonalQrUseCase: mockGetQrUseCase,
            revokeCustomerPersonalQrUseCase: mockRevokeQrUseCase,
            clockProvider: () => tNow,
          );
          addTearDown(() => qrBloc.close());

          await tester.pumpWidget(
            MaterialApp(home: CustomerQrPage(bloc: qrBloc)),
          );
          await _pumpFrames(tester);

          expect(find.text('Add Points'), findsOneWidget);
          expect(find.text('How Earning Works'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
