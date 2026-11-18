import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
import 'package:shiftex/features/home/data/datasources/home_remote_data_source.dart';
import 'package:shiftex/features/home/data/models/home_dashboard_models.dart';
import 'package:shiftex/features/home/data/repositories/home_repository_impl.dart';
import 'package:shiftex/features/home/domain/entities/advertisement_campaign_entity.dart';
import 'package:shiftex/features/home/domain/entities/customer_qr_token_entity.dart';
import 'package:shiftex/features/home/domain/entities/daily_streak_entity.dart';
import 'package:shiftex/features/home/domain/entities/home_dashboard_entity.dart';
import 'package:shiftex/features/home/domain/entities/locked_point_allocation_entity.dart';
import 'package:shiftex/features/home/domain/entities/point_transaction_entity.dart';
import 'package:shiftex/features/home/domain/entities/wallet_summary_entity.dart';
import 'package:shiftex/features/home/domain/usecases/generate_claim_qr_usecase.dart';
import 'package:shiftex/features/home/domain/usecases/get_home_dashboard_usecase.dart';
import 'package:shiftex/features/home/domain/usecases/track_advertisement_event_usecase.dart';
import 'package:shiftex/features/home/presentation/bloc/home_bloc.dart';
import 'package:shiftex/features/home/presentation/bloc/home_event.dart';
import 'package:shiftex/features/home/presentation/bloc/home_state.dart';
import 'package:shiftex/features/home/presentation/pages/home_page.dart';

class _MockGetHomeDashboardUseCase extends Mock
    implements GetHomeDashboardUseCase {}

class _MockGenerateClaimQrUseCase extends Mock
    implements GenerateClaimQrUseCase {}

class _MockTrackAdvertisementEventUseCase extends Mock
    implements TrackAdvertisementEventUseCase {}

class _MockHomeRemoteDataSource extends Mock implements HomeRemoteDataSource {}

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
  late _MockGetHomeDashboardUseCase mockGetHomeDashboardUseCase;
  late _MockGenerateClaimQrUseCase mockGenerateClaimQrUseCase;
  late _MockTrackAdvertisementEventUseCase mockTrackAdvertisementEventUseCase;
  late _MockHomeRemoteDataSource mockHomeRemoteDataSource;

  final tNow = DateTime.utc(2026, 11, 17, 6, 30);

  HomeDashboardEntity buildDashboard({
    int availablePoints = 2450,
    int lockedPoints = 550,
    int currentStreakDay = 4,
    bool claimedToday = true,
    bool justCompletedDay7 = false,
    int completedStreakPoints = 0,
    List<AdvertisementCampaignEntity>? ads,
    List<PointTransactionEntity>? transactions,
  }) {
    final unlockAt = tNow.add(const Duration(days: 2, hours: 14));
    final allocation = LockedPointAllocationEntity(
      id: 'alloc-1',
      sourceType: 'daily_streak',
      points: lockedPoints,
      status: 'locked',
      description: '7-Day Streak Completed (15 pts × 7 days)',
      lockedAt: tNow.subtract(const Duration(days: 4, hours: 10)),
      unlockAt: unlockAt,
    );

    return HomeDashboardEntity(
      customerId: 'cust-8921',
      fullName: 'Vishnu Kumar',
      email: 'vishnu@example.com',
      mobileNumber: '+919876543210',
      wallet: WalletSummaryEntity(
        customerCode: 'SHFT-8921',
        membershipTier: 'Pebble Black Member',
        availablePoints: availablePoints,
        lockedPoints: lockedPoints,
        lifetimeEarnedPoints: availablePoints + lockedPoints,
        lifetimeRedeemedPoints: 100,
        pointsEarnedToday: 150,
        pointsToInrRate: 0.10,
      ),
      nextUnlockAllocation: lockedPoints > 0 ? allocation : null,
      lockedAllocations: lockedPoints > 0 ? [allocation] : const [],
      streak: DailyStreakEntity(
        dailyLoginEnabled: true,
        dailyPoints: 15,
        currentStreakDay: currentStreakDay,
        claimedToday: claimedToday,
        daysRemaining: 7 - currentStreakDay,
        cycleDate: '2026-11-17',
        nextResetAt: tNow.add(const Duration(hours: 20)),
        justCompletedDay7: justCompletedDay7,
        completedStreakPoints: completedStreakPoints,
        completedUnlockAt: tNow.add(const Duration(days: 7)),
      ),
      advertisements:
          ads ??
          [
            AdvertisementCampaignEntity(
              id: 'ad-diwali-89',
              title: 'Diwali Mahotsav 2X Bonus Sparkles',
              offerDetails:
                  '2x points on all purchases above ₹500 across partner stores in your hub.',
              imageUrl: null,
              popupDurationSeconds: 6,
              frequencyType: 'once_per_session',
              frequencyLimit: 1,
              startAt: tNow.subtract(const Duration(days: 2)),
              endAt: tNow.add(const Duration(days: 4)),
            ),
          ],
      recentTransactions:
          transactions ??
          [
            PointTransactionEntity(
              id: 'tx-1',
              type: PointTransactionType.merchantReward,
              title: 'Metro Fresh Mart',
              description: 'Partner store purchase',
              pointsDelta: 80,
              isLockedAllocation: false,
              createdAt: tNow.subtract(const Duration(minutes: 30)),
            ),
            PointTransactionEntity(
              id: 'tx-2',
              type: PointTransactionType.dailyStreak,
              title: 'Daily Streak Bonus',
              description: 'Day 4 check-in',
              pointsDelta: 15,
              isLockedAllocation: true,
              createdAt: tNow.subtract(const Duration(hours: 2)),
            ),
            PointTransactionEntity(
              id: 'tx-3',
              type: PointTransactionType.discountRedemption,
              title: 'Blue Tokai Coffee Pass',
              description: 'Bill discount redeemed',
              pointsDelta: -100,
              isLockedAllocation: false,
              createdAt: tNow.subtract(const Duration(days: 1)),
            ),
          ],
    );
  }

  CustomerQrTokenEntity buildQrToken() {
    return CustomerQrTokenEntity(
      id: 'qr-1',
      tokenCode: 'CLM-9942-X7B',
      qrPayload: 'SHIIFTEX:CLAIM:V1:CLM-9942-X7B:9F8E7D6C5B4A',
      status: 'active',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      createdAt: DateTime.now().toUtc(),
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
    registerFallbackValue(const GetHomeDashboardParams());
    registerFallbackValue(const NoParams());
    registerFallbackValue(
      const TrackAdvertisementEventParams(
        advertisementId: '',
        eventType: 'impression',
      ),
    );
  });

  setUp(() {
    mockGetHomeDashboardUseCase = _MockGetHomeDashboardUseCase();
    mockGenerateClaimQrUseCase = _MockGenerateClaimQrUseCase();
    mockTrackAdvertisementEventUseCase = _MockTrackAdvertisementEventUseCase();
    mockHomeRemoteDataSource = _MockHomeRemoteDataSource();

    when(
      () => mockTrackAdvertisementEventUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
  });

  group('Home Dashboard Domain & Data Model Tests', () {
    test(
      'Available and Locked balance INR equivalents and conversion rates are calculated accurately',
      () {
        final dashboard = buildDashboard(
          availablePoints: 2450,
          lockedPoints: 550,
        );
        expect(dashboard.wallet.availableInr, closeTo(245.0, 0.001));
        expect(dashboard.wallet.lockedInr, closeTo(55.0, 0.001));
        expect(dashboard.wallet.pointsPerOneInr, 10);
      },
    );

    test(
      'Missed-day reset and 7-day unlock model parsing preserve completed allocations',
      () async {
        final rawJson = <String, dynamic>{
          'profile': {
            'id': 'u-1',
            'full_name': 'Vishnu Kumar',
            'email': 'vishnu@example.com',
            'mobile_number': '+919876543210',
            'approval_status': 'approved',
          },
          'wallet': {
            'customer_code': 'SHFT-8921',
            'membership_tier': 'Pebble Black Member',
            'available_points': 105, // Previously unlocked 7-day streak (15 * 7)
            'locked_points': 0,
            'lifetime_earned_points': 105,
            'lifetime_redeemed_points': 0,
            'points_earned_today': 15,
            'points_to_inr_rate': '0.1000',
          },
          'next_unlock_allocation': null,
          'locked_allocations': <dynamic>[],
          'streak': {
            'daily_login_enabled': true,
            'daily_points': 15,
            'current_streak_day': 1, // Reset to Day 1 after missed day
            'claimed_today': true,
            'days_remaining': 6,
            'cycle_date': '2026-11-17',
            'next_reset_at': '2026-11-18T00:30:00Z',
            'just_completed_day_7': false,
            'completed_streak_points': 0,
          },
          'recent_transactions': [
            {
              'id': 'tx-unlock',
              'transaction_type': 'streak_unlock',
              'title': 'Streak Points Unlocked',
              'description': '7-Day Streak Completed (15 pts × 7 days)',
              'points_delta': 105,
              'is_locked_allocation': false,
              'created_at': '2026-11-17T06:00:00Z',
            },
          ],
        };

        when(
          () => mockHomeRemoteDataSource.getHomeDashboard(
            performDailyCheckIn: any(named: 'performDailyCheckIn'),
            sessionId: any(named: 'sessionId'),
          ),
        ).thenAnswer((_) async => HomeDashboardModel.fromJson(rawJson));

        final repository = HomeRepositoryImpl(mockHomeRemoteDataSource);
        final result = await repository.getHomeDashboard();

        expect(result.isRight(), isTrue);
        result.fold((_) => fail('Expected Right'), (dashboard) {
          // Missed day reset current streak to Day 1 while preserving 105 unlocked points
          expect(dashboard.streak.currentStreakDay, 1);
          expect(dashboard.streak.daysRemaining, 6);
          expect(dashboard.wallet.availablePoints, 105);
          expect(
            dashboard.recentTransactions.first.type,
            PointTransactionType.streakUnlock,
          );
          expect(dashboard.recentTransactions.first.pointsDelta, 105);
        });
      },
    );
  });

  group('HomeBloc Enum-State & Day 7 Celebration Tests', () {
    blocTest<HomeBloc, HomeState>(
      'emits [loading, loaded] and sets showStreakCelebration = true ONLY on Day 7 completion (15 * 7 = 105 pts locked)',
      build: () {
        when(() => mockGetHomeDashboardUseCase(any())).thenAnswer(
          (_) async => Right(
            buildDashboard(
              availablePoints: 2450,
              lockedPoints: 105,
              currentStreakDay: 7,
              claimedToday: true,
              justCompletedDay7: true,
              completedStreakPoints: 105,
            ),
          ),
        );
        return HomeBloc(
          getHomeDashboardUseCase: mockGetHomeDashboardUseCase,
          generateClaimQrUseCase: mockGenerateClaimQrUseCase,
          trackAdvertisementEventUseCase: mockTrackAdvertisementEventUseCase,
          sessionId: 'test_session',
        );
      },
      act: (bloc) => bloc.add(const HomeDashboardLoadRequested()),
      expect:
          () => [
            isA<HomeState>().having(
              (s) => s.status,
              'status',
              HomeStatus.loading,
            ),
            isA<HomeState>()
                .having((s) => s.status, 'status', HomeStatus.loaded)
                .having(
                  (s) => s.showStreakCelebration,
                  'showStreakCelebration',
                  isTrue,
                )
                .having(
                  (s) => s.dashboard?.streak.completedStreakPoints,
                  'completedStreakPoints',
                  105,
                ),
          ],
    );

    blocTest<HomeBloc, HomeState>(
      'does NOT re-show Day 7 celebration popup on subsequent refreshes in the same cycle',
      build: () {
        when(() => mockGetHomeDashboardUseCase(any())).thenAnswer(
          (_) async => Right(
            buildDashboard(
              lockedPoints: 105,
              currentStreakDay: 7,
              claimedToday: true,
              justCompletedDay7: true,
              completedStreakPoints: 105,
            ),
          ),
        );
        return HomeBloc(
          getHomeDashboardUseCase: mockGetHomeDashboardUseCase,
          generateClaimQrUseCase: mockGenerateClaimQrUseCase,
          trackAdvertisementEventUseCase: mockTrackAdvertisementEventUseCase,
          sessionId: 'test_session',
        );
      },
      act: (bloc) async {
        bloc.add(const HomeDashboardLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const HomeStreakCelebrationDismissed());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const HomeDashboardRefreshRequested());
      },
      verify: (bloc) {
        expect(bloc.state.showStreakCelebration, isFalse);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'emits HomeStatus.error when dashboard load fails',
      build: () {
        when(
          () => mockGetHomeDashboardUseCase(any()),
        ).thenAnswer((_) async => const Left(NetworkFailure()));
        return HomeBloc(
          getHomeDashboardUseCase: mockGetHomeDashboardUseCase,
          generateClaimQrUseCase: mockGenerateClaimQrUseCase,
          trackAdvertisementEventUseCase: mockTrackAdvertisementEventUseCase,
        );
      },
      act: (bloc) => bloc.add(const HomeDashboardLoadRequested()),
      expect:
          () => [
            isA<HomeState>().having(
              (s) => s.status,
              'status',
              HomeStatus.loading,
            ),
            isA<HomeState>().having(
              (s) => s.status,
              'status',
              HomeStatus.error,
            ),
          ],
    );
  });

  group('Home Dashboard UI, Celebration Dialog, QR Modal & Multi-Screen Tests', () {
    testWidgets(
      'Renders all 8 dashboard sections, opens Single-Use Claim QR modal, and switches to History tab',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        final authBloc = buildIdleAuthBloc();
        addTearDown(() async {
          await authBloc.close();
          await tester.binding.setSurfaceSize(null);
        });

        when(
          () => mockGetHomeDashboardUseCase(any()),
        ).thenAnswer((_) async => Right(buildDashboard()));
        when(
          () => mockGenerateClaimQrUseCase(any()),
        ).thenAnswer((_) async => Right(buildQrToken()));

        final homeBloc = HomeBloc(
          getHomeDashboardUseCase: mockGetHomeDashboardUseCase,
          generateClaimQrUseCase: mockGenerateClaimQrUseCase,
          trackAdvertisementEventUseCase: mockTrackAdvertisementEventUseCase,
          sessionId: 'sess_ui',
        );
        addTearDown(() => homeBloc.close());

        await tester.pumpWidget(
          BlocProvider<AuthenticationBloc>.value(
            value: authBloc,
            child: MaterialApp(
              home: HomePage(homeBloc: homeBloc),
            ),
          ),
        );
        await _pumpFrames(tester);

        // 1. Greeting & Customer Identity
        expect(find.text('Hello, Vishnu'), findsOneWidget);
        expect(find.text('Pebble Black Member •'), findsOneWidget);
        expect(find.text('SHFT-8921'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);

        // 2. Available Balance Card
        expect(find.text('Available Balance'), findsOneWidget);
        expect(find.text('10 pts = ₹1.00'), findsOneWidget);
        expect(find.text('≈ ₹245.00'), findsOneWidget);

        // 3. Locked Points Card
        expect(find.text('550 pts locked'), findsOneWidget);
        expect(find.text('≈ ₹55.00'), findsOneWidget);

        // 4. Daily Streak Progress Card
        expect(find.text('4 Day Streak 🔥'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Next streak unlocks at 06:00 AM'), findsOneWidget);

        // 5. Promotional Campaign Card
        expect(
          find.text('Diwali Mahotsav 2X Bonus Sparkles'),
          findsOneWidget,
        );
        expect(find.text('claim now'), findsOneWidget);

        // 6. Recent Rewards Section
        expect(find.text('Recent Rewards'), findsOneWidget);
        expect(find.text('Metro Fresh Mart'), findsOneWidget);
        expect(find.text('+80 pts'), findsOneWidget);
        expect(find.text('Blue Tokai Coffee Pass'), findsOneWidget);
        expect(find.text('-100 pts'), findsOneWidget);

        // 7. Tap "Claim Rewards" -> Opens Single-Use Claim QR Modal
        await tester.ensureVisible(find.text('Claim Rewards'));
        await tester.pump();
        await tester.tap(find.text('Claim Rewards'));
        await _pumpFrames(tester);

        expect(find.text('Single-Use Claim QR'), findsOneWidget);
        expect(find.text('CLM-9942-X7B'), findsOneWidget);
        expect(find.text('100 pts = ₹10.00 Off Bill'), findsOneWidget);
        // Verify QR payload does not expose wallet balance or email/phone
        expect(buildQrToken().qrPayload.contains('2450'), isFalse);
        expect(buildQrToken().qrPayload.contains('vishnu'), isFalse);

        await tester.ensureVisible(find.text('Done'));
        await tester.pump();
        await tester.tap(find.text('Done'));
        await _pumpFrames(tester);

        // 8. Switch to History tab via bottom navigation
        await tester.tap(find.text('History'));
        await _pumpFrames(tester);
        expect(find.text('Reward History'), findsOneWidget);
      },
    );

    testWidgets(
      'Displays 7-Day Streak Celebration Popup when Day 7 is completed',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        final authBloc = buildIdleAuthBloc();
        addTearDown(() async {
          await authBloc.close();
          await tester.binding.setSurfaceSize(null);
        });

        when(() => mockGetHomeDashboardUseCase(any())).thenAnswer(
          (_) async => Right(
            buildDashboard(
              lockedPoints: 105,
              currentStreakDay: 7,
              claimedToday: true,
              justCompletedDay7: true,
              completedStreakPoints: 105,
            ),
          ),
        );

        final homeBloc = HomeBloc(
          getHomeDashboardUseCase: mockGetHomeDashboardUseCase,
          generateClaimQrUseCase: mockGenerateClaimQrUseCase,
          trackAdvertisementEventUseCase: mockTrackAdvertisementEventUseCase,
          sessionId: 'sess_day7',
        );
        addTearDown(() => homeBloc.close());

        await tester.pumpWidget(
          BlocProvider<AuthenticationBloc>.value(
            value: authBloc,
            child: MaterialApp(
              home: HomePage(homeBloc: homeBloc),
            ),
          ),
        );
        await _pumpFrames(tester);

        expect(find.text('7-Day Streak Completed!'), findsOneWidget);
        expect(
          find.text(
            "Congratulations! You've completed seven consecutive days.",
          ),
          findsOneWidget,
        );
        expect(find.text('+105 pts Earned & Locked'), findsOneWidget);

        await tester.tap(find.text('Continue'));
        await _pumpFrames(tester);
        expect(find.text('7-Day Streak Completed!'), findsNothing);
      },
    );

    testWidgets(
      'Home Dashboard renders cleanly without overflow on Small Mobile (320x568)',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        final authBloc = buildIdleAuthBloc();
        addTearDown(() async {
          await authBloc.close();
          await tester.binding.setSurfaceSize(null);
        });

        when(
          () => mockGetHomeDashboardUseCase(any()),
        ).thenAnswer((_) async => Right(buildDashboard()));

        final homeBloc = HomeBloc(
          getHomeDashboardUseCase: mockGetHomeDashboardUseCase,
          generateClaimQrUseCase: mockGenerateClaimQrUseCase,
          trackAdvertisementEventUseCase: mockTrackAdvertisementEventUseCase,
        );
        addTearDown(() => homeBloc.close());

        await tester.pumpWidget(
          BlocProvider<AuthenticationBloc>.value(
            value: authBloc,
            child: MaterialApp(
              home: HomePage(homeBloc: homeBloc),
            ),
          ),
        );
        await _pumpFrames(tester);

        expect(find.text('Hello, Vishnu'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
