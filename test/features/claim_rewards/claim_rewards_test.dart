import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/core/errors/failures.dart';
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
import 'package:shiftex/features/claim_rewards/data/datasources/claim_rewards_remote_data_source.dart';
import 'package:shiftex/features/claim_rewards/data/models/claim_rewards_models.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/claim_operation_result_entity.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/claim_wallet_context_entity.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/reward_claim_entity.dart';
import 'package:shiftex/features/claim_rewards/domain/usecases/cancel_reward_claim_usecase.dart';
import 'package:shiftex/features/claim_rewards/domain/usecases/create_reward_claim_usecase.dart';
import 'package:shiftex/features/claim_rewards/domain/usecases/get_claim_rewards_context_usecase.dart';
import 'package:shiftex/features/claim_rewards/domain/usecases/get_customer_claim_status_usecase.dart';
import 'package:shiftex/features/claim_rewards/presentation/bloc/claim_rewards_bloc.dart';
import 'package:shiftex/features/claim_rewards/presentation/bloc/claim_rewards_event.dart';
import 'package:shiftex/features/claim_rewards/presentation/bloc/claim_rewards_state.dart';
import 'package:shiftex/features/claim_rewards/presentation/widgets/choose_claim_amount_sheet.dart';
import 'package:shiftex/features/claim_rewards/presentation/widgets/single_use_claim_qr_sheet.dart';
import 'package:shiftex/features/home/domain/entities/daily_streak_entity.dart';
import 'package:shiftex/features/home/domain/entities/home_dashboard_entity.dart';
import 'package:shiftex/features/home/domain/entities/wallet_summary_entity.dart';
import 'package:shiftex/features/home/domain/usecases/generate_claim_qr_usecase.dart';
import 'package:shiftex/features/home/domain/usecases/get_home_dashboard_usecase.dart';
import 'package:shiftex/features/home/domain/usecases/track_advertisement_event_usecase.dart';
import 'package:shiftex/features/home/presentation/bloc/home_bloc.dart';
import 'package:shiftex/features/home/presentation/pages/home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockGetClaimRewardsContextUseCase extends Mock
    implements GetClaimRewardsContextUseCase {}

class _MockCreateRewardClaimUseCase extends Mock
    implements CreateRewardClaimUseCase {}

class _MockGetCustomerClaimStatusUseCase extends Mock
    implements GetCustomerClaimStatusUseCase {}

class _MockCancelRewardClaimUseCase extends Mock
    implements CancelRewardClaimUseCase {}

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
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  final tNow = DateTime.utc(2026, 11, 17, 10, 0);

  ClaimWalletContextEntity buildContext({
    int availablePoints = 2450,
    int reservedPoints = 0,
    int lockedPoints = 550,
    double rate = 0.10,
    RewardClaimEntity? activePendingClaim,
  }) {
    return ClaimWalletContextEntity(
      customerCode: 'SHFT-8921',
      membershipTier: 'Pebble Black Member',
      availablePoints: availablePoints,
      reservedPoints: reservedPoints,
      lockedPoints: lockedPoints,
      pointsToInrRate: rate,
      activePendingClaim: activePendingClaim,
    );
  }

  RewardClaimEntity buildClaim({
    String id = 'claim-1',
    String claimReference = 'CLM-9942-X7B',
    String? qrPayload,
    int points = 250,
    double rate = 0.10,
    RewardClaimStatus status = RewardClaimStatus.pending,
    DateTime? expiresAt,
    String? billNumber,
    String? branchName,
  }) {
    final effectivePayload =
        qrPayload ?? 'SHIIFTEX:CLAIM:V1:$claimReference:9F8E7D6C5B4A';
    return RewardClaimEntity(
      id: id,
      userId: 'user-8921',
      qrTokenId: 'tok-claim-1',
      claimReference: claimReference,
      qrPayload: effectivePayload,
      points: points,
      pointsToInrRate: rate,
      discountAmount: ((points * rate) * 100).roundToDouble() / 100.0,
      status: status,
      expiresAt: expiresAt ?? tNow.add(const Duration(minutes: 5)),
      createdAt: tNow,
      redeemedAt: status == RewardClaimStatus.redeemed ? tNow : null,
      billNumber: billNumber,
      branchName: branchName,
      releasedAt:
          (status == RewardClaimStatus.expired ||
                  status == RewardClaimStatus.cancelled)
              ? tNow
              : null,
    );
  }

  HomeDashboardEntity buildDashboard({
    int availablePoints = 2450,
    int lockedPoints = 550,
    double rate = 0.10,
  }) {
    return HomeDashboardEntity(
      customerId: 'user-8921',
      fullName: 'Vishnu K.',
      email: 'vishnu@example.com',
      mobileNumber: '+919876543210',
      wallet: WalletSummaryEntity(
        customerCode: 'SHFT-8921',
        membershipTier: 'Pebble Black Member',
        availablePoints: availablePoints,
        lockedPoints: lockedPoints,
        lifetimeEarnedPoints: availablePoints + lockedPoints,
        lifetimeRedeemedPoints: 0,
        pointsEarnedToday: 15,
        pointsToInrRate: rate,
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
    registerFallbackValue(const NoParams());
    registerFallbackValue(const CreateRewardClaimParams(points: 100));
    registerFallbackValue(
      const GetCustomerClaimStatusParams(claimId: 'claim-1'),
    );
    registerFallbackValue(const CancelRewardClaimParams(claimId: 'claim-1'));
    registerFallbackValue(const GetHomeDashboardParams());
    registerFallbackValue(
      const TrackAdvertisementEventParams(
        advertisementId: '',
        eventType: 'impression',
      ),
    );
  });

  group('Claim Rewards Domain, Admin Compatibility & Data Tests', () {
    test(
      'Model parses backend claim + reservation wallet JSON and verifies Admin scanner payload contract',
      () {
        final result = ClaimOperationResultModel.fromJson({
          'claim': {
            'id': 'claim-uuid-1',
            'user_id': 'cust-uuid-1',
            'qr_token_id': 'tok-uuid-1',
            'claim_reference': 'CLM-9942-X7B',
            'qr_payload': 'SHIIFTEX:CLAIM:V1:CLM-9942-X7B:9F8E7D6C5B4A',
            'points': 250,
            'points_to_inr_rate': '0.1000',
            'discount_amount': '25.00',
            'status': 'pending',
            'expires_at': tNow.add(const Duration(minutes: 5)).toIso8601String(),
            'created_at': tNow.toIso8601String(),
          },
          'wallet': {
            'customer_code': 'SHFT-8921',
            'membership_tier': 'Pebble Black Member',
            'available_points': 2200,
            'reserved_points': 250,
            'locked_points': 550,
          },
        });

        expect(result.claim.claimReference, 'CLM-9942-X7B');
        expect(result.claim.hasSecurePayload, isTrue);
        expect(
          result.claim.qrPayload,
          startsWith('SHIIFTEX:CLAIM:V1:CLM-9942-X7B:'),
        );
        expect(result.claim.discountAmount, closeTo(25.0, 0.001));
        expect(result.claim.status, RewardClaimStatus.pending);
        expect(result.wallet.availablePoints, 2200);
        expect(result.wallet.reservedPoints, 250);
        expect(result.wallet.lockedPoints, 550);
      },
    );

    test(
      'Custom Admin conversion rates are respected dynamically without hardcoding',
      () {
        final ctx = buildContext(availablePoints: 400, rate: 0.25);
        expect(ctx.pointsPerOneInr, 4);
        expect(ctx.availableInr, closeTo(100.0, 0.001));
        expect(ctx.discountForPoints(250), closeTo(62.50, 0.001));
        expect(ctx.remainingPointsAfter(250), 150);
        expect(ctx.remainingInrAfter(250), closeTo(37.50, 0.001));
      },
    );

    test(
      'RemoteDataSource rejects unauthenticated calls across all claim RPCs',
      () async {
        final mockSupabase = _MockSupabaseClient();
        final mockAuth = _MockGoTrueClient();
        when(() => mockSupabase.auth).thenReturn(mockAuth);
        when(() => mockAuth.currentUser).thenReturn(null);

        final dataSource = ClaimRewardsRemoteDataSourceImpl(mockSupabase);

        expect(
          () => dataSource.getClaimRewardsContext(),
          throwsA(isA<AppAuthException>()),
        );
        expect(
          () => dataSource.createRewardClaim(points: 100),
          throwsA(isA<AppAuthException>()),
        );
        expect(
          () => dataSource.getCustomerClaimStatus(claimId: 'claim-1'),
          throwsA(isA<AppAuthException>()),
        );
        expect(
          () => dataSource.cancelRewardClaim(claimId: 'claim-1'),
          throwsA(isA<AppAuthException>()),
        );
      },
    );
  });

  group('ClaimRewardsBloc Tests (Selection, Reservations, Expiry, Errors)', () {
    late _MockGetClaimRewardsContextUseCase mockGetContext;
    late _MockCreateRewardClaimUseCase mockCreateClaim;
    late _MockGetCustomerClaimStatusUseCase mockGetStatus;
    late _MockCancelRewardClaimUseCase mockCancelClaim;

    setUp(() {
      mockGetContext = _MockGetClaimRewardsContextUseCase();
      mockCreateClaim = _MockCreateRewardClaimUseCase();
      mockGetStatus = _MockGetCustomerClaimStatusUseCase();
      mockCancelClaim = _MockCancelRewardClaimUseCase();
    });

    blocTest<ClaimRewardsBloc, ClaimRewardsState>(
      'loads wallet context, supports presets, Claim Full, custom validation, and rejects locked/excess points',
      build: () {
        when(() => mockGetContext(any())).thenAnswer(
          (_) async => Right(
            buildContext(availablePoints: 2450, lockedPoints: 550, rate: 0.10),
          ),
        );
        return ClaimRewardsBloc(
          getClaimRewardsContextUseCase: mockGetContext,
          createRewardClaimUseCase: mockCreateClaim,
          getCustomerClaimStatusUseCase: mockGetStatus,
          cancelRewardClaimUseCase: mockCancelClaim,
          clockProvider: () => tNow,
        );
      },
      act: (bloc) async {
        bloc.add(const ClaimRewardsStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ClaimPresetSelected(500));
        bloc.add(const ClaimCustomAmountChanged('300'));
        bloc.add(const ClaimCustomAmountChanged('0'));
        bloc.add(const ClaimCustomAmountChanged('12.5'));
        bloc.add(const ClaimCustomAmountChanged('2500')); // > 2450 instant
        bloc.add(const ClaimFullRequested());
      },
      verify: (bloc) {
        final st = bloc.state;
        expect(st.status, ClaimRewardsStatus.loaded);
        expect(st.availablePoints, 2450);
        expect(st.lockedPoints, 550);
        expect(st.selectedPoints, 2450);
        expect(st.customAmountInput, '2450');
        expect(st.discountAmount, closeTo(245.0, 0.001));
        expect(st.remainingBalance, 0);
        expect(st.canGenerateClaim, isTrue);
      },
    );

    blocTest<ClaimRewardsBloc, ClaimRewardsState>(
      'rejects attempting to spend locked points when instant balance is smaller',
      build: () {
        when(() => mockGetContext(any())).thenAnswer(
          (_) async => Right(
            buildContext(availablePoints: 100, lockedPoints: 900, rate: 0.10),
          ),
        );
        return ClaimRewardsBloc(
          getClaimRewardsContextUseCase: mockGetContext,
          createRewardClaimUseCase: mockCreateClaim,
          getCustomerClaimStatusUseCase: mockGetStatus,
          cancelRewardClaimUseCase: mockCancelClaim,
          clockProvider: () => tNow,
        );
      },
      act: (bloc) async {
        bloc.add(const ClaimRewardsStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ClaimPresetSelected(250));
      },
      verify: (bloc) {
        expect(bloc.state.selectedPoints, 100);
        expect(
          bloc.state.inputValidationError,
          '250 pts exceeds your 100 instant available points.',
        );
        expect(bloc.state.canGenerateClaim, isFalse);
      },
    );

    blocTest<ClaimRewardsBloc, ClaimRewardsState>(
      'prevents multiple simultaneous claim requests while generatingClaim is in flight',
      build: () {
        final completer = Completer<Either<Failure, ClaimOperationResultEntity>>();
        when(() => mockGetContext(any())).thenAnswer(
          (_) async => Right(buildContext(availablePoints: 2450)),
        );
        when(() => mockCreateClaim(any())).thenAnswer((_) => completer.future);

        final bloc = ClaimRewardsBloc(
          getClaimRewardsContextUseCase: mockGetContext,
          createRewardClaimUseCase: mockCreateClaim,
          getCustomerClaimStatusUseCase: mockGetStatus,
          cancelRewardClaimUseCase: mockCancelClaim,
          clockProvider: () => tNow,
        );

        Future<void>.delayed(const Duration(milliseconds: 20)).then((_) {
          completer.complete(
            Right(
              ClaimOperationResultEntity(
                claim: buildClaim(points: 250),
                wallet: buildContext(availablePoints: 2200, reservedPoints: 250),
              ),
            ),
          );
        });
        return bloc;
      },
      act: (bloc) async {
        bloc.add(const ClaimRewardsStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ClaimGenerateRequested(idempotencyKey: 'k1'));
        bloc.add(const ClaimGenerateRequested(idempotencyKey: 'k2'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      verify: (bloc) {
        verify(() => mockCreateClaim(any())).called(1);
        expect(bloc.state.status, ClaimRewardsStatus.claimGenerated);
        expect(bloc.state.availablePoints, 2200);
        expect(bloc.state.reservedPoints, 250);
      },
    );

    blocTest<ClaimRewardsBloc, ClaimRewardsState>(
      'handles expiry, releases reserved points, supports cancellation and redeemed status sync',
      build: () {
        final pendingClaim = buildClaim(
          points: 250,
          expiresAt: tNow.add(const Duration(minutes: 5)),
        );
        final expiredClaim = buildClaim(
          points: 250,
          status: RewardClaimStatus.expired,
          expiresAt: tNow,
        );
        final redeemedClaim = buildClaim(
          id: 'claim-2',
          points: 100,
          status: RewardClaimStatus.redeemed,
          billNumber: 'BILL-8841',
          branchName: 'MG Road Branch',
        );

        when(() => mockGetContext(any())).thenAnswer(
          (_) async => Right(buildContext(availablePoints: 2450)),
        );
        when(() => mockCreateClaim(any())).thenAnswer(
          (_) async => Right(
            ClaimOperationResultEntity(
              claim: pendingClaim,
              wallet: buildContext(availablePoints: 2200, reservedPoints: 250),
            ),
          ),
        );
        when(() => mockGetStatus(any())).thenAnswer((invocation) async {
          final params =
              invocation.positionalArguments.first
                  as GetCustomerClaimStatusParams;
          if (params.claimId == 'claim-1') {
            return Right(
              ClaimOperationResultEntity(
                claim: expiredClaim,
                wallet: buildContext(availablePoints: 2450, reservedPoints: 0),
              ),
            );
          }
          return Right(
            ClaimOperationResultEntity(
              claim: redeemedClaim,
              wallet: buildContext(availablePoints: 2350, reservedPoints: 0),
            ),
          );
        });
        when(() => mockCancelClaim(any())).thenAnswer(
          (_) async => Right(
            ClaimOperationResultEntity(
              claim: buildClaim(
                points: 250,
                status: RewardClaimStatus.cancelled,
              ),
              wallet: buildContext(availablePoints: 2450, reservedPoints: 0),
            ),
          ),
        );

        return ClaimRewardsBloc(
          getClaimRewardsContextUseCase: mockGetContext,
          createRewardClaimUseCase: mockCreateClaim,
          getCustomerClaimStatusUseCase: mockGetStatus,
          cancelRewardClaimUseCase: mockCancelClaim,
          clockProvider: () => tNow,
        );
      },
      act: (bloc) async {
        bloc.add(const ClaimRewardsStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ClaimGenerateRequested());
        await Future<void>.delayed(Duration.zero);
        // Simulate countdown expiration -> releases reservation back to 2450
        bloc.add(
          ClaimCountdownTicked(now: tNow.add(const Duration(minutes: 6))),
        );
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.status, ClaimRewardsStatus.expired);
        expect(bloc.state.availablePoints, 2450);
        expect(bloc.state.reservedPoints, 0);

        // Cancel flow releases points back
        bloc.add(const ClaimCancelRequested('claim-1'));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.status, ClaimRewardsStatus.loaded);
        expect(bloc.state.availablePoints, 2450);

        // Redeemed sync via pending resumed claim
        bloc.add(ClaimPendingResumed(buildClaim(id: 'claim-2', points: 100)));
        bloc.add(const ClaimStatusCheckRequested());
      },
      verify: (bloc) {
        expect(bloc.state.status, ClaimRewardsStatus.redeemed);
        expect(bloc.state.currentClaim?.billNumber, 'BILL-8841');
        expect(bloc.state.availablePoints, 2350);
      },
    );

    blocTest<ClaimRewardsBloc, ClaimRewardsState>(
      'retains sheet state with error message when claim generation fails over network',
      build: () {
        when(() => mockGetContext(any())).thenAnswer(
          (_) async => Right(buildContext(availablePoints: 2450)),
        );
        when(
          () => mockCreateClaim(any()),
        ).thenAnswer((_) async => const Left(NetworkFailure()));
        return ClaimRewardsBloc(
          getClaimRewardsContextUseCase: mockGetContext,
          createRewardClaimUseCase: mockCreateClaim,
          getCustomerClaimStatusUseCase: mockGetStatus,
          cancelRewardClaimUseCase: mockCancelClaim,
          clockProvider: () => tNow,
        );
      },
      act: (bloc) async {
        bloc.add(const ClaimRewardsStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ClaimGenerateRequested());
      },
      verify: (bloc) {
        expect(bloc.state.status, ClaimRewardsStatus.loaded);
        expect(bloc.state.currentClaim, isNull);
        expect(bloc.state.errorMessage, contains('Unable to connect'));
      },
    );
  });

  group('Claim Rewards UI, Bottom Sheet Transition & Multi-Screen Tests', () {
    late _MockGetClaimRewardsContextUseCase mockGetContext;
    late _MockCreateRewardClaimUseCase mockCreateClaim;
    late _MockGetCustomerClaimStatusUseCase mockGetStatus;
    late _MockCancelRewardClaimUseCase mockCancelClaim;

    setUp(() {
      mockGetContext = _MockGetClaimRewardsContextUseCase();
      mockCreateClaim = _MockCreateRewardClaimUseCase();
      mockGetStatus = _MockGetCustomerClaimStatusUseCase();
      mockCancelClaim = _MockCancelRewardClaimUseCase();
    });

    testWidgets(
      'Claim Rewards button opens Choose Claim Amount sheet -> presets/Claim Full -> Generate Claim QR -> Single-Use Claim QR -> Done',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final liveExpiry = DateTime.now().toUtc().add(
          const Duration(minutes: 5),
        );
        final mockGetHome = _MockGetHomeDashboardUseCase();
        when(
          () => mockGetHome(any()),
        ).thenAnswer((_) async => Right(buildDashboard()));
        when(() => mockGetContext(any())).thenAnswer(
          (_) async => Right(buildContext(availablePoints: 2450, rate: 0.10)),
        );
        when(() => mockCreateClaim(any())).thenAnswer(
          (_) async => Right(
            ClaimOperationResultEntity(
              claim: buildClaim(
                points: 500,
                claimReference: 'CLM-9942-X7B',
                expiresAt: liveExpiry,
              ),
              wallet: buildContext(availablePoints: 1950, reservedPoints: 500),
            ),
          ),
        );

        final authBloc = buildIdleAuthBloc();
        final homeBloc = HomeBloc(
          getHomeDashboardUseCase: mockGetHome,
          generateClaimQrUseCase: _MockGenerateClaimQrUseCase(),
          trackAdvertisementEventUseCase: _MockTrackAdvertisementEventUseCase(),
        );
        final claimBloc = ClaimRewardsBloc(
          getClaimRewardsContextUseCase: mockGetContext,
          createRewardClaimUseCase: mockCreateClaim,
          getCustomerClaimStatusUseCase: mockGetStatus,
          cancelRewardClaimUseCase: mockCancelClaim,
        );

        addTearDown(() async {
          await claimBloc.close();
          await homeBloc.close();
          await authBloc.close();
        });

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<AuthenticationBloc>.value(value: authBloc),
              BlocProvider<HomeBloc>.value(value: homeBloc),
              BlocProvider<ClaimRewardsBloc>.value(value: claimBloc),
            ],
            child: MaterialApp(home: HomePage(homeBloc: homeBloc)),
          ),
        );
        await _pumpFrames(tester);

        // 1. Tap Claim Rewards on Home Dashboard
        await tester.tap(find.text('Claim Rewards'));
        await _pumpFrames(tester);

        expect(find.text('Choose Claim Amount'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ChooseClaimAmountSheet),
            matching: find.text('Instant Points'),
          ),
          findsOneWidget,
        );
        expect(find.text('Claim Full'), findsOneWidget);
        expect(find.textContaining('₹'), findsNothing);

        // 2. Tap 500 pts preset -> summary updates cleanly with points only
        await tester.tap(find.text('500 pts'));
        await _pumpFrames(tester);
        expect(find.text('Instant Points Claim'), findsOneWidget);
        expect(find.text('1,950 pts'), findsOneWidget);
        expect(find.textContaining('₹'), findsNothing);

        // 2b. Tap Claim Full -> fills full instant balance (locked points excluded)
        await tester.tap(find.text('Claim Full'));
        await _pumpFrames(tester);
        expect(find.text('0 pts'), findsOneWidget);
        expect(find.textContaining('₹'), findsNothing);

        // 2c. Enter custom valid point amount -> summary updates dynamically
        await tester.enterText(find.byType(TextField), '500');
        await _pumpFrames(tester);
        expect(find.text('1,950 pts'), findsOneWidget);

        // 3. Tap Generate Claim QR -> transitions smoothly to Single-Use Claim QR sheet
        await tester.ensureVisible(find.text('Generate Claim QR'));
        await tester.tap(find.text('Generate Claim QR'));
        await _pumpFrames(tester);

        expect(find.text('Single-Use Claim QR'), findsOneWidget);
        expect(find.text('500 pts Instant Claim'), findsOneWidget);
        expect(find.textContaining('₹'), findsNothing);
        expect(find.text('ACTIVE • SINGLE-USE'), findsOneWidget);
        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.text('CLM-9942-X7B'), findsOneWidget);
        expect(
          find.text(
            'One-time encrypted code. Automatically invalidates after cash register scan or after 5 minutes.',
          ),
          findsOneWidget,
        );

        // 4. Tap Done -> closes modal without cancelling pending claim in backend
        await tester.ensureVisible(find.text('Done'));
        await tester.tap(find.text('Done'));
        await _pumpFrames(tester);

        expect(find.text('Single-Use Claim QR'), findsNothing);
        verifyNever(() => mockCancelClaim(any()));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'displays Expired state & Generate New Claim button when claim expires, plus Redeemed status refresh',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final expiredClaim = buildClaim(
          points: 250,
          status: RewardClaimStatus.expired,
          expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 5)),
        );
        when(() => mockGetContext(any())).thenAnswer(
          (_) async => Right(buildContext(availablePoints: 2450)),
        );

        final claimBloc = ClaimRewardsBloc(
          getClaimRewardsContextUseCase: mockGetContext,
          createRewardClaimUseCase: mockCreateClaim,
          getCustomerClaimStatusUseCase: mockGetStatus,
          cancelRewardClaimUseCase: mockCancelClaim,
        );
        claimBloc.add(ClaimPendingResumed(expiredClaim));
        addTearDown(() => claimBloc.close());

        bool generatedNewCalled = false;
        await tester.pumpWidget(
          BlocProvider<ClaimRewardsBloc>.value(
            value: claimBloc,
            child: MaterialApp(
              home: Scaffold(
                body: SingleUseClaimQrSheet(
                  enableLiveTicker: false,
                  onDone: () {},
                  onGenerateNew: () => generatedNewCalled = true,
                ),
              ),
            ),
          ),
        );
        await _pumpFrames(tester);

        expect(find.text('This Claim QR Has Expired'), findsOneWidget);
        expect(find.text('Generate New Claim'), findsOneWidget);

        await tester.tap(find.text('Generate New Claim'));
        await _pumpFrames(tester);
        expect(generatedNewCalled, isTrue);

        // Now verify redeemed state UI
        when(() => mockGetStatus(any())).thenAnswer(
          (_) async => Right(
            ClaimOperationResultEntity(
              claim: buildClaim(
                points: 250,
                status: RewardClaimStatus.redeemed,
                billNumber: 'B-102',
                branchName: 'Indiranagar',
              ),
              wallet: buildContext(availablePoints: 2200),
            ),
          ),
        );
        claimBloc.add(
          ClaimPendingResumed(
            buildClaim(
              points: 250,
              expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 4)),
            ),
          ),
        );
        await _pumpFrames(tester);

        await tester.tap(find.text('Refresh Claim Status'));
        await _pumpFrames(tester);

        expect(find.text('Claim Redeemed!'), findsOneWidget);
        expect(find.text('Bill #B-102 • Indiranagar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    for (final viewport in [
      const Size(320, 568),
      const Size(375, 812),
      const Size(430, 932),
    ]) {
      testWidgets(
        'ChooseClaimAmountSheet & SingleUseClaimQrSheet render without overflow at ${viewport.width.toInt()}x${viewport.height.toInt()}',
        (WidgetTester tester) async {
          await tester.binding.setSurfaceSize(viewport);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final pending = buildClaim(
            points: 250,
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 4)),
          );
          when(() => mockGetContext(any())).thenAnswer(
            (_) async => Right(
              buildContext(
                availablePoints: 2200,
                reservedPoints: 250,
                activePendingClaim: pending,
              ),
            ),
          );

          final claimBloc = ClaimRewardsBloc(
            getClaimRewardsContextUseCase: mockGetContext,
            createRewardClaimUseCase: mockCreateClaim,
            getCustomerClaimStatusUseCase: mockGetStatus,
            cancelRewardClaimUseCase: mockCancelClaim,
          );
          claimBloc.add(const ClaimRewardsStarted());
          addTearDown(() => claimBloc.close());

          await tester.pumpWidget(
            BlocProvider<ClaimRewardsBloc>.value(
              value: claimBloc,
              child: MaterialApp(
                home: Scaffold(
                  body: ChooseClaimAmountSheet(
                    onClose: () {},
                    onClaimReady: () {},
                  ),
                ),
              ),
            ),
          );
          await _pumpFrames(tester);
          expect(find.text('Choose Claim Amount'), findsOneWidget);
          expect(tester.takeException(), isNull);

          claimBloc.add(ClaimPendingResumed(pending));
          await tester.pumpWidget(
            BlocProvider<ClaimRewardsBloc>.value(
              value: claimBloc,
              child: MaterialApp(
                home: Scaffold(
                  body: SingleUseClaimQrSheet(
                    enableLiveTicker: false,
                    onDone: () {},
                    onGenerateNew: () {},
                  ),
                ),
              ),
            ),
          );
          await _pumpFrames(tester);
          expect(find.text('Single-Use Claim QR'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
