import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/core/routes/app_router.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/features/account_approval/domain/entities/approval_status.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';
import 'package:shiftex/features/account_approval/domain/usecases/get_approval_status_usecase.dart';
import 'package:shiftex/features/account_approval/presentation/bloc/account_approval_bloc.dart';
import 'package:shiftex/features/advertisements/data/datasources/advertisement_local_data_source.dart';
import 'package:shiftex/features/advertisements/data/datasources/advertisement_remote_data_source.dart';
import 'package:shiftex/features/advertisements/data/models/advertisement_model.dart';
import 'package:shiftex/features/advertisements/data/repositories/advertisement_repository_impl.dart';
import 'package:shiftex/features/advertisements/domain/entities/advertisement_entity.dart';
import 'package:shiftex/features/advertisements/domain/entities/advertisement_event_type.dart';
import 'package:shiftex/features/advertisements/domain/usecases/clear_advertisement_session_usecase.dart';
import 'package:shiftex/features/advertisements/domain/usecases/get_eligible_advertisement_usecase.dart';
import 'package:shiftex/features/advertisements/domain/usecases/track_advertisement_analytics_usecase.dart';
import 'package:shiftex/features/advertisements/presentation/bloc/advertisement_bloc.dart';
import 'package:shiftex/features/advertisements/presentation/bloc/advertisement_event.dart';
import 'package:shiftex/features/advertisements/presentation/bloc/advertisement_state.dart';
import 'package:shiftex/features/advertisements/presentation/widgets/advertisement_overlay_host.dart';
import 'package:shiftex/features/advertisements/presentation/widgets/advertisement_popup.dart';
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
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';
import 'package:shiftex/features/home/domain/entities/daily_streak_entity.dart';
import 'package:shiftex/features/home/domain/entities/home_dashboard_entity.dart';
import 'package:shiftex/features/home/domain/entities/wallet_summary_entity.dart';
import 'package:shiftex/features/home/domain/usecases/generate_claim_qr_usecase.dart';
import 'package:shiftex/features/home/domain/usecases/get_home_dashboard_usecase.dart';
import 'package:shiftex/features/home/domain/usecases/track_advertisement_event_usecase.dart';
import 'package:shiftex/features/home/presentation/bloc/home_bloc.dart';
import 'package:shiftex/shiftexapp.dart';

class _InMemoryAdKeyValueStore implements AdKeyValueStore {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

class _FakeRemoteDataSource implements AdvertisementRemoteDataSource {
  List<AdvertisementModel> adsToReturn = const [];
  Object? fetchError;
  Object? trackError;
  Completer<void>? pendingDelay;
  int fetchCallCount = 0;
  final List<
    ({
      String adId,
      AdvertisementEventType type,
      String sessionId,
      Map<String, dynamic> metadata,
    })
  >
  recordedEvents = [];

  @override
  Future<List<AdvertisementModel>> fetchActiveAdvertisements({
    required String userId,
    required String sessionId,
  }) async {
    fetchCallCount++;
    if (pendingDelay != null) {
      await pendingDelay!.future;
    }
    if (fetchError != null) throw fetchError!;
    return adsToReturn;
  }

  @override
  Future<void> trackEvent({
    required String advertisementId,
    required AdvertisementEventType eventType,
    required String sessionId,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (trackError != null) throw trackError!;
    recordedEvents.add((
      adId: advertisementId,
      type: eventType,
      sessionId: sessionId,
      metadata: Map<String, dynamic>.from(metadata),
    ));
  }
}

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

class _MockGetHomeDashboardUseCase extends Mock
    implements GetHomeDashboardUseCase {}

class _MockGenerateClaimQrUseCase extends Mock
    implements GenerateClaimQrUseCase {}

class _MockTrackAdvertisementEventUseCase extends Mock
    implements TrackAdvertisementEventUseCase {}

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const GetHomeDashboardParams(performDailyCheckIn: false),
    );
  });

  final nowUtc = DateTime.utc(2026, 11, 19, 6, 30);

  AdvertisementModel buildAdModel({
    String id = 'ad-1',
    String title = 'Mega Cashback Weekend',
    String offerDetails = 'Earn 2X points on POS bills above ₹500',
    String? imageUrl = 'https://cdn.shiiftex.example/ads/promo.png',
    int duration = 6,
    AdvertisementFrequencyType frequencyType =
        AdvertisementFrequencyType.oncePerSession,
    int frequencyLimit = 1,
    DateTime? startAt,
    DateTime? endAt,
    AdvertisementCampaignStatus status = AdvertisementCampaignStatus.published,
    DateTime? deactivatedAt,
    String? ctaLabel,
    AdvertisementCtaActionType? ctaActionType,
    String? ctaActionValue,
    int priority = 0,
    DateTime? publishedAt,
    DateTime? serverNow,
  }) {
    return AdvertisementModel(
      id: id,
      title: title,
      offerDetails: offerDetails,
      imageUrl: imageUrl,
      popupDurationSeconds: duration,
      frequencyType: frequencyType,
      frequencyLimit: frequencyLimit,
      startAt: startAt ?? nowUtc.subtract(const Duration(days: 1)),
      endAt: endAt ?? nowUtc.add(const Duration(days: 5)),
      status: status,
      deactivatedAt: deactivatedAt,
      ctaLabel: ctaLabel,
      ctaActionType: ctaActionType,
      ctaActionValue: ctaActionValue,
      priority: priority,
      publishedAt: publishedAt ?? nowUtc.subtract(const Duration(hours: 2)),
      serverNow: serverNow ?? nowUtc,
    );
  }

  AuthenticationBloc buildAuthBloc() {
    final mockRepo = _MockAuthenticationRepository();
    when(
      () => mockRepo.authSessionEvents,
    ).thenAnswer((_) => const Stream<String>.empty());
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
      authRepository: mockRepo,
    );
  }

  CustomerProfileEntity approvedProfile({String id = 'cust-1'}) {
    return CustomerProfileEntity(
      id: id,
      fullName: 'Vishnu Kumar',
      email: 'vishnu@example.com',
      mobileNumber: '+919876543210',
      approvalStatus: AccountApprovalStatus.approved,
      createdAt: nowUtc,
      updatedAt: nowUtc,
    );
  }

  HomeDashboardEntity buildHomeDashboard() {
    return HomeDashboardEntity(
      customerId: 'cust-1',
      fullName: 'Vishnu Kumar',
      email: 'vishnu@example.com',
      mobileNumber: '+919876543210',
      wallet: const WalletSummaryEntity(
        customerCode: 'SHFT-CUST',
        membershipTier: 'Pebble Black Member',
        availablePoints: 2450,
        lockedPoints: 550,
        lifetimeEarnedPoints: 3000,
        lifetimeRedeemedPoints: 550,
        pointsEarnedToday: 80,
        pointsToInrRate: 0.10,
      ),
      lockedAllocations: const [],
      streak: DailyStreakEntity(
        dailyLoginEnabled: true,
        dailyPoints: 15,
        currentStreakDay: 3,
        claimedToday: true,
        daysRemaining: 4,
        cycleDate: '2026-11-19',
        nextResetAt: nowUtc.add(const Duration(hours: 12)),
        justCompletedDay7: false,
        completedStreakPoints: 0,
      ),
      recentTransactions: const [],
      advertisements: const [],
    );
  }

  HomeBloc buildReadyHomeBloc() {
    final getHome = _MockGetHomeDashboardUseCase();
    final genQr = _MockGenerateClaimQrUseCase();
    final trackAd = _MockTrackAdvertisementEventUseCase();
    when(
      () => getHome(any()),
    ).thenAnswer((_) async => Right(buildHomeDashboard()));
    return HomeBloc(
      getHomeDashboardUseCase: getHome,
      generateClaimQrUseCase: genQr,
      trackAdvertisementEventUseCase: trackAd,
    );
  }

  AccountApprovalBloc buildApprovalBloc() {
    return AccountApprovalBloc(
      getApprovalStatusUseCase: _MockGetApprovalStatusUseCase(),
    );
  }

  ({
    _FakeRemoteDataSource remote,
    AdvertisementLocalDataSourceImpl local,
    AdvertisementRepositoryImpl repo,
    AdvertisementBloc bloc,
  })
  buildPipeline({Duration tickInterval = const Duration(milliseconds: 20)}) {
    final store = _InMemoryAdKeyValueStore();
    final local = AdvertisementLocalDataSourceImpl(store);
    final remote = _FakeRemoteDataSource();
    final repo = AdvertisementRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: local,
    );
    final bloc = AdvertisementBloc(
      getEligibleAdvertisementUseCase: GetEligibleAdvertisementUseCase(repo),
      trackAdvertisementAnalyticsUseCase: TrackAdvertisementAnalyticsUseCase(
        repo,
      ),
      clearAdvertisementSessionUseCase: ClearAdvertisementSessionUseCase(repo),
      clockProvider: () => nowUtc,
      tickInterval: tickInterval,
    );
    return (remote: remote, local: local, repo: repo, bloc: bloc);
  }

  group('Campaign Validation, Priority & Frequency Cap Tests', () {
    test(
      'excludes draft, future scheduled, expired, and deactivated ads cleanly',
      () {
        final draft = buildAdModel(
          id: 'draft',
          status: AdvertisementCampaignStatus.draft,
        );
        final scheduledStatus = buildAdModel(
          id: 'scheduled',
          status: AdvertisementCampaignStatus.scheduled,
        );
        final futureStart = buildAdModel(
          id: 'future-window',
          startAt: nowUtc.add(const Duration(hours: 1)),
          endAt: nowUtc.add(const Duration(days: 3)),
        );
        final expired = buildAdModel(
          id: 'expired',
          startAt: nowUtc.subtract(const Duration(days: 5)),
          endAt: nowUtc.subtract(const Duration(minutes: 1)),
        );
        final deactivated = buildAdModel(
          id: 'deactivated',
          deactivatedAt: nowUtc.subtract(const Duration(hours: 1)),
        );
        final zeroDuration = buildAdModel(id: 'zero-dur', duration: 0);
        final eligible = buildAdModel(id: 'active');

        expect(draft.isEligibleAt(nowUtc), isFalse);
        expect(scheduledStatus.isEligibleAt(nowUtc), isFalse);
        expect(futureStart.isEligibleAt(nowUtc), isFalse);
        expect(expired.isEligibleAt(nowUtc), isFalse);
        expect(deactivated.isEligibleAt(nowUtc), isFalse);
        expect(zeroDuration.isEligibleAt(nowUtc), isFalse);
        expect(eligible.isEligibleAt(nowUtc), isTrue);
      },
    );

    test(
      'selects highest-priority eligible campaign among multiple active campaigns and validates CTA destinations',
      () async {
        final pipe = buildPipeline();
        addTearDown(() => pipe.bloc.close());

        final draftHighPriority = buildAdModel(
          id: 'ad-draft',
          priority: 99,
          status: AdvertisementCampaignStatus.draft,
        );
        final lowPriority = buildAdModel(
          id: 'ad-low',
          title: 'Low Priority',
          priority: 1,
          publishedAt: nowUtc.subtract(const Duration(minutes: 5)),
        );
        final topPriority = buildAdModel(
          id: 'ad-top',
          title: 'Top Priority',
          priority: 10,
          ctaLabel: 'Claim Now',
          ctaActionType: AdvertisementCtaActionType.internalRoute,
          ctaActionValue: '/claim-rewards',
        );

        pipe.remote.adsToReturn = [draftHighPriority, lowPriority, topPriority];

        final result = await pipe.repo.getEligibleAdvertisement(
          userId: 'cust-1',
          sessionId: 'sess-1',
          nowOverride: nowUtc,
        );

        expect(result.isRight(), isTrue);
        final selected = result.getOrElse(() => null);
        expect(selected?.id, 'ad-top');
        expect(selected?.hasConfiguredCta, isTrue);

        // Unsafe CTA schemes & non-allowlisted routes rejected safely
        final unsafeJsCta = buildAdModel(
          ctaLabel: 'Hack',
          ctaActionType: AdvertisementCtaActionType.externalUrl,
          ctaActionValue: 'javascript:alert(1)',
        );
        final unsafeHttpCta = buildAdModel(
          ctaLabel: 'Insecure',
          ctaActionType: AdvertisementCtaActionType.externalUrl,
          ctaActionValue: 'http://example.com',
        );
        final unknownRouteCta = buildAdModel(
          ctaLabel: 'Unknown',
          ctaActionType: AdvertisementCtaActionType.internalRoute,
          ctaActionValue: '/admin-dashboard',
        );
        expect(unsafeJsCta.hasConfiguredCta, isFalse);
        expect(unsafeHttpCta.hasConfiguredCta, isFalse);
        expect(unknownRouteCta.hasConfiguredCta, isFalse);
      },
    );

    test(
      'enforces 1x/session, once_per_day, once_per_week, once_per_user, and multi-limit frequency caps',
      () async {
        final store = _InMemoryAdKeyValueStore();
        final local = AdvertisementLocalDataSourceImpl(store);

        // 1x/session: session-1 allows 1 -> after impression blocks session-1 -> allows session-2
        final sessionAd = buildAdModel(
          id: 'ad-sess',
          frequencyType: AdvertisementFrequencyType.oncePerSession,
          frequencyLimit: 1,
        );
        expect(
          await local.isWithinFrequencyCap(
            advertisement: sessionAd,
            userId: 'u1',
            sessionId: 's1',
            referenceUtc: nowUtc,
          ),
          isTrue,
        );
        await local.recordLocalImpression(
          userId: 'u1',
          advertisementId: 'ad-sess',
          sessionId: 's1',
          recordedAtUtc: nowUtc,
        );
        expect(
          await local.isWithinFrequencyCap(
            advertisement: sessionAd,
            userId: 'u1',
            sessionId: 's1',
            referenceUtc: nowUtc,
          ),
          isFalse,
        );
        expect(
          await local.isWithinFrequencyCap(
            advertisement: sessionAd,
            userId: 'u1',
            sessionId: 's2',
            referenceUtc: nowUtc,
          ),
          isTrue,
        );

        // once_per_day across sessions
        final dayAd = buildAdModel(
          id: 'ad-day',
          frequencyType: AdvertisementFrequencyType.oncePerDay,
          frequencyLimit: 1,
        );
        await local.recordLocalImpression(
          userId: 'u1',
          advertisementId: 'ad-day',
          sessionId: 's1',
          recordedAtUtc: nowUtc,
        );
        expect(
          await local.isWithinFrequencyCap(
            advertisement: dayAd,
            userId: 'u1',
            sessionId: 's2',
            referenceUtc: nowUtc.add(const Duration(hours: 10)),
          ),
          isFalse,
        );
        expect(
          await local.isWithinFrequencyCap(
            advertisement: dayAd,
            userId: 'u1',
            sessionId: 's3',
            referenceUtc: nowUtc.add(const Duration(hours: 25)),
          ),
          isTrue,
        );

        // once_per_user with frequency_limit = 2
        final userLimit2 = buildAdModel(
          id: 'ad-user-2',
          frequencyType: AdvertisementFrequencyType.oncePerUser,
          frequencyLimit: 2,
        );
        await local.recordLocalImpression(
          userId: 'u1',
          advertisementId: 'ad-user-2',
          sessionId: 's1',
          recordedAtUtc: nowUtc,
        );
        expect(
          await local.isWithinFrequencyCap(
            advertisement: userLimit2,
            userId: 'u1',
            sessionId: 's2',
            referenceUtc: nowUtc.add(const Duration(days: 60)),
          ),
          isTrue,
        );
        await local.recordLocalImpression(
          userId: 'u1',
          advertisementId: 'ad-user-2',
          sessionId: 's2',
          recordedAtUtc: nowUtc.add(const Duration(days: 60)),
        );
        expect(
          await local.isWithinFrequencyCap(
            advertisement: userLimit2,
            userId: 'u1',
            sessionId: 's3',
            referenceUtc: nowUtc.add(const Duration(days: 61)),
          ),
          isFalse,
        );
      },
    );

    test(
      'handles offline gracefully: uses valid non-expired cached ads, queues offline events, and skips expired cache',
      () async {
        final pipe = buildPipeline();
        addTearDown(() => pipe.bloc.close());

        final activeAd = buildAdModel(
          id: 'ad-cached',
          title: 'Offline Cached Campaign',
          endAt: nowUtc.add(const Duration(hours: 2)),
        );
        final expiringSoonAd = buildAdModel(
          id: 'ad-expiring',
          title: 'Soon Expired',
          endAt: nowUtc.add(const Duration(minutes: 30)),
        );
        pipe.remote.adsToReturn = [expiringSoonAd];

        // Online fetch populates cache
        await pipe.repo.getEligibleAdvertisement(
          userId: 'cust-1',
          sessionId: 'sess-online',
          nowOverride: nowUtc,
        );

        // Record event offline -> queues pending event without losing it
        pipe.remote.trackError = const AppAuthException(
          'Offline',
          code: 'network_failure',
        );
        await pipe.repo.recordEvent(
          userId: 'cust-1',
          advertisementId: 'ad-cached',
          eventType: AdvertisementEventType.dismissal,
          sessionId: 'sess-offline',
          presentationSequence: 1,
          nowOverride: nowUtc,
        );
        expect(pipe.remote.recordedEvents, isEmpty);

        // Cache rejects expiringSoonAd once past endAt
        final expiredLookup = await pipe.local.getCachedAdvertisements(
          userId: 'cust-1',
          referenceUtc: nowUtc.add(const Duration(hours: 1)),
        );
        expect(expiredLookup, isEmpty);

        // Re-seed cache with activeAd and go offline on fetch -> returns cached campaign seamlessly
        await pipe.local.cacheAdvertisements(
          userId: 'cust-1',
          advertisements: [activeAd],
          cachedAtUtc: nowUtc,
        );
        pipe.remote.fetchError = const AppAuthException(
          'Offline',
          code: 'network_failure',
        );
        final offlineResult = await pipe.repo.getEligibleAdvertisement(
          userId: 'cust-1',
          sessionId: 'sess-offline-fallback',
          nowOverride: nowUtc,
        );
        expect(offlineResult.getOrElse(() => null)?.id, 'ad-cached');

        // Coming back online flushes queued offline dismissal event cleanly
        pipe.remote.fetchError = null;
        pipe.remote.trackError = null;
        pipe.remote.adsToReturn = [activeAd];
        await pipe.repo.getEligibleAdvertisement(
          userId: 'cust-1',
          sessionId: 'sess-recovered',
          nowOverride: nowUtc,
        );
        expect(
          pipe.remote.recordedEvents.any(
            (e) =>
                e.adId == 'ad-cached' &&
                e.type == AdvertisementEventType.dismissal,
          ),
          isTrue,
        );
      },
    );
  });

  group('AdvertisementBloc Lifecycle, Countdown & Analytics Tests', () {
    blocTest<AdvertisementBloc, AdvertisementState>(
      'counts down from configured duration to 0, auto-dismisses, and records single impression + auto_dismissal',
      build: () {
        final pipe = buildPipeline(
          tickInterval: const Duration(milliseconds: 15),
        );
        pipe.remote.adsToReturn = [buildAdModel(id: 'ad-auto', duration: 3)];
        return pipe.bloc;
      },
      act: (bloc) async {
        bloc.add(const AdvertisementSessionStarted(userId: 'cust-1'));
        await Future<void>.delayed(const Duration(milliseconds: 120));
      },
      verify: (bloc) {
        expect(bloc.state.status, AdvertisementStatus.dismissed);
        expect(bloc.state.remainingSeconds, 0);
        expect(bloc.state.activeAdvertisement, isNull);
      },
    );

    test(
      'ignores duplicate AdvertisementSessionStarted triggers in same session (no duplicate impressions) and allows fresh session after logout',
      () async {
        final pipe = buildPipeline(tickInterval: const Duration(seconds: 1));
        addTearDown(() => pipe.bloc.close());

        final ad = buildAdModel(
          id: 'ad-1',
          duration: 6,
          frequencyType: AdvertisementFrequencyType.oncePerSession,
        );
        pipe.remote.adsToReturn = [ad];

        pipe.bloc.add(const AdvertisementSessionStarted(userId: 'cust-1'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(pipe.bloc.state.status, AdvertisementStatus.showing);
        expect(pipe.remote.fetchCallCount, 1);

        // Duplicate triggers (rebuild / route revisit / auth refresh) no-op
        pipe.bloc.add(const AdvertisementSessionStarted(userId: 'cust-1'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(pipe.remote.fetchCallCount, 1);

        final impressionsSession1 = pipe.remote.recordedEvents
            .where((e) => e.type == AdvertisementEventType.impression)
            .length;
        expect(impressionsSession1, 1);

        // Manual close records dismissal once
        pipe.bloc.add(const AdvertisementDismissRequested());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(pipe.bloc.state.status, AdvertisementStatus.dismissed);
        expect(
          pipe.remote.recordedEvents
              .where((e) => e.type == AdvertisementEventType.dismissal)
              .length,
          1,
        );

        // Logout / session end clears session cleanly -> next login shows 1x/session ad
        pipe.bloc.add(const AdvertisementSessionEnded());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(pipe.bloc.state.status, AdvertisementStatus.initial);

        pipe.bloc.add(const AdvertisementSessionStarted(userId: 'cust-1'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(pipe.bloc.state.status, AdvertisementStatus.showing);
        expect(pipe.remote.fetchCallCount, 2);
      },
    );

    test(
      'emits silent empty / error states without throwing when offline and cleans up timer on close',
      () async {
        final pipe = buildPipeline();
        pipe.remote.fetchError = const AppAuthException(
          'Network failure',
          code: 'network_failure',
        );

        pipe.bloc.add(const AdvertisementSessionStarted(userId: 'cust-1'));
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(pipe.bloc.state.status, AdvertisementStatus.error);
        expect(pipe.bloc.state.activeAdvertisement, isNull);

        await pipe.bloc.close();
        expect(pipe.bloc.isClosed, isTrue);
      },
    );
  });

  group('Widget, Countdown, Navigation & Responsive Popup Tests', () {
    testWidgets(
      'renders popup on approved app launch, counts down every second (6s -> 0s), and auto-dismisses',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final authBloc = buildAuthBloc();
        final approvalBloc = buildApprovalBloc();
        final homeBloc = buildReadyHomeBloc();
        final pipe = buildPipeline(tickInterval: const Duration(seconds: 1));
        pipe.remote.adsToReturn = [
          buildAdModel(
            id: 'ad-launch',
            title: 'Festive Cashback 2X',
            offerDetails: 'Double rewards on weekend partner purchases.',
            duration: 6,
          ),
        ];

        final router = GoRouter(
          initialLocation: RoutesNames.splash,
          refreshListenable: GoRouterRefreshStream(authBloc.stream),
          redirect: (context, state) {
            return AppRouter.evaluateAuthRedirect(
              authState: authBloc.state,
              matchedLocation: state.matchedLocation,
              queryParameters: state.uri.queryParameters,
            );
          },
          routes: [
            GoRoute(
              path: RoutesNames.splash,
              builder: (_, _) => const Scaffold(body: Text('Splash')),
            ),
            GoRoute(
              path: RoutesNames.home,
              builder: (context, _) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => context.go(RoutesNames.activityHistory),
                    child: const Text('Go History'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: RoutesNames.activityHistory,
              builder: (context, _) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => context.go(RoutesNames.home),
                    child: const Text('Back Home'),
                  ),
                ),
              ),
            ),
          ],
        );

        addTearDown(() async {
          router.dispose();
          await pipe.bloc.close();
          await homeBloc.close();
          await approvalBloc.close();
          await authBloc.close();
        });

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<AuthenticationBloc>.value(value: authBloc),
              BlocProvider<AccountApprovalBloc>.value(value: approvalBloc),
              BlocProvider<HomeBloc>.value(value: homeBloc),
              BlocProvider<AdvertisementBloc>.value(value: pipe.bloc),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              builder: (context, child) => AdvertisementOverlayHost(
                router: router,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
        await _pumpFrames(tester);

        // Before approval/login -> no popup shown
        expect(find.byType(AdvertisementPopup), findsNothing);

        // Customer authenticates as approved -> navigates to /home and displays popup
        authBloc.emit(AuthenticationSuccess(approvedProfile()));
        await _pumpFrames(tester);

        expect(find.byType(AdvertisementPopup), findsOneWidget);
        expect(
          find.byKey(const ValueKey('advertisement_campaign_pill')),
          findsOneWidget,
        );
        expect(find.text('Festive Cashback 2X'), findsOneWidget);
        expect(find.text('6s'), findsOneWidget);
        expect(find.text('Promotional Offer'), findsOneWidget);
        expect(find.text('Validity Window'), findsOneWidget);
        // No fake CTA rendered when Admin hasn't configured CTA
        expect(
          find.byKey(const ValueKey('advertisement_cta_button')),
          findsNothing,
        );

        // Verify 1 second tick -> 5s
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('5s'), findsOneWidget);

        // Advance remaining 5 seconds -> auto-dismisses at zero
        await tester.pump(const Duration(seconds: 5));
        await _pumpFrames(tester);
        expect(find.byType(AdvertisementPopup), findsNothing);

        // Verify 1 impression + 1 auto_dismissal recorded
        expect(
          pipe.remote.recordedEvents
              .where((e) => e.type == AdvertisementEventType.impression)
              .length,
          1,
        );
        expect(
          pipe.remote.recordedEvents
              .where((e) => e.type == AdvertisementEventType.autoDismissal)
              .length,
          1,
        );

        // Navigating Home -> History -> Home in same session does NOT reopen popup
        await tester.tap(find.text('Go History'));
        await _pumpFrames(tester);
        await tester.tap(find.text('Back Home'));
        await _pumpFrames(tester);
        expect(find.byType(AdvertisementPopup), findsNothing);
        expect(pipe.remote.fetchCallCount, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'manual close dismisses immediately and records dismissal, while CTA navigates internally & launches verified HTTPS external URL',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final authBloc = buildAuthBloc();
        final pipe = buildPipeline(tickInterval: const Duration(seconds: 1));
        final launchedUrls = <Uri>[];

        pipe.remote.adsToReturn = [
          buildAdModel(
            id: 'ad-manual-close',
            title: 'Manual Close Promo',
            duration: 8,
            ctaLabel: 'Claim Discount',
            ctaActionType: AdvertisementCtaActionType.internalRoute,
            ctaActionValue: RoutesNames.claimRewards,
          ),
        ];

        final router = GoRouter(
          initialLocation: RoutesNames.home,
          routes: [
            GoRoute(
              path: RoutesNames.home,
              builder: (_, _) => const Scaffold(body: Text('Home Screen')),
            ),
            GoRoute(
              path: RoutesNames.claimRewards,
              builder: (_, _) =>
                  const Scaffold(body: Text('Claim Rewards Route')),
            ),
          ],
        );

        addTearDown(() async {
          router.dispose();
          await pipe.bloc.close();
          await authBloc.close();
        });

        authBloc.emit(AuthenticationSuccess(approvedProfile()));

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<AuthenticationBloc>.value(value: authBloc),
              BlocProvider<AdvertisementBloc>.value(value: pipe.bloc),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              builder: (context, child) => AdvertisementOverlayHost(
                router: router,
                externalUrlLauncher: (uri) async {
                  launchedUrls.add(uri);
                  return true;
                },
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
        await _pumpFrames(tester);

        expect(find.text('Manual Close Promo'), findsOneWidget);
        expect(find.text('Claim Discount'), findsOneWidget);

        // Tap Close -> closes immediately & records dismissal
        await tester.tap(
          find.byKey(const ValueKey('advertisement_close_button')),
        );
        await _pumpFrames(tester);
        expect(find.byType(AdvertisementPopup), findsNothing);
        expect(
          pipe.remote.recordedEvents.last.type,
          AdvertisementEventType.dismissal,
        );

        // Start a fresh session with internal CTA -> tap CTA navigates to /claim-rewards & records cta_click
        pipe.bloc.add(
          const AdvertisementSessionStarted(
            userId: 'cust-1',
            forceNewSession: true,
          ),
        );
        await _pumpFrames(tester);
        expect(find.text('Claim Discount'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('advertisement_cta_button')),
        );
        await _pumpFrames(tester);

        expect(find.byType(AdvertisementPopup), findsNothing);
        expect(find.text('Claim Rewards Route'), findsOneWidget);
        expect(
          pipe.remote.recordedEvents.last.type,
          AdvertisementEventType.ctaClick,
        );

        // Start another session with external HTTPS CTA -> tap CTA launches verified HTTPS URL
        pipe.remote.adsToReturn = [
          buildAdModel(
            id: 'ad-ext-url',
            title: 'Partner Mall Offer',
            ctaLabel: 'Explore Offer',
            ctaActionType: AdvertisementCtaActionType.externalUrl,
            ctaActionValue: 'https://rewards.shiiftex.example/festival',
          ),
        ];
        pipe.bloc.add(
          const AdvertisementSessionStarted(
            userId: 'cust-1',
            forceNewSession: true,
          ),
        );
        await _pumpFrames(tester);
        await tester.tap(
          find.byKey(const ValueKey('advertisement_cta_button')),
        );
        await _pumpFrames(tester);

        expect(launchedUrls.length, 1);
        expect(
          launchedUrls.single.toString(),
          'https://rewards.shiiftex.example/festival',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'never shows popup to pending/unauthenticated users and keeps Shiftexapp Home unblocked offline',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final authBloc = buildAuthBloc();
        final approvalBloc = buildApprovalBloc();
        final homeBloc = buildReadyHomeBloc();
        final pipe = buildPipeline();
        pipe.remote.fetchError = const AppAuthException(
          'Offline',
          code: 'network_failure',
        );

        authBloc.emit(
          PendingApproval(
            CustomerProfileEntity(
              id: 'pending-1',
              fullName: 'Pending User',
              email: 'pending@example.com',
              mobileNumber: '+919876543210',
              approvalStatus: AccountApprovalStatus.pending,
              createdAt: nowUtc,
              updatedAt: nowUtc,
            ),
          ),
        );

        addTearDown(() async {
          await pipe.bloc.close();
          await homeBloc.close();
          await approvalBloc.close();
          await authBloc.close();
        });

        await tester.pumpWidget(
          Shiftexapp(
            authenticationBloc: authBloc,
            accountApprovalBloc: approvalBloc,
            homeBloc: homeBloc,
            advertisementBloc: pipe.bloc,
          ),
        );
        await _pumpFrames(tester);

        // Pending user cannot see ads or fetch them
        expect(find.byType(AdvertisementPopup), findsNothing);
        expect(pipe.remote.fetchCallCount, 0);

        // Switch to approved customer while ads are offline -> Home renders cleanly with zero error dialogs!
        authBloc.emit(AuthenticationSuccess(approvedProfile()));
        await _pumpFrames(tester);

        expect(find.text('Hello, Vishnu'), findsOneWidget);
        expect(find.byType(AdvertisementPopup), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    for (final viewport in [
      const Size(320, 568),
      const Size(375, 812),
      const Size(430, 932),
    ]) {
      testWidgets(
        'renders AdvertisementPopup cleanly without overflow at ${viewport.width.toInt()}x${viewport.height.toInt()}',
        (WidgetTester tester) async {
          await tester.binding.setSurfaceSize(viewport);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final ad = buildAdModel(
            id: 'ad-resp',
            title:
                'Super Weekend Mega Cashback & Partner Celebration Offer for Loyal Customers',
            offerDetails:
                'Earn 2X instant points plus bonus locked points across partner retail outlets and outlets near your hub when scanning at checkout.',
            duration: 10,
            imageUrl: null,
            ctaLabel: 'Claim Rewards Now',
            ctaActionType: AdvertisementCtaActionType.internalRoute,
            ctaActionValue: RoutesNames.claimRewards,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AdvertisementPopup(
                advertisement: ad,
                remainingSeconds: 10,
                totalSeconds: 10,
                onClose: () {},
                onCtaTap: () {},
              ),
            ),
          );
          await _pumpFrames(tester);

          expect(
            find.byKey(const ValueKey('advertisement_campaign_pill')),
            findsOneWidget,
          );
          expect(find.text('10s'), findsOneWidget);
          expect(find.text('Promotional Offer'), findsOneWidget);
          expect(find.text('Validity Window'), findsOneWidget);
          expect(find.text('Claim Rewards Now'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'renders image-only compact poster layout when offerDetails and CTA are empty, and renders Days Left when details exist',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(375, 812));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final flyerOnlyAd = buildAdModel(
          id: 'ad-flyer-only',
          title: 'FIRST DROP SALE',
          offerDetails: '',
          imageUrl: null,
          duration: 5,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AdvertisementPopup(
              advertisement: flyerOnlyAd,
              remainingSeconds: 5,
              totalSeconds: 5,
              onClose: () {},
            ),
          ),
        );
        await _pumpFrames(tester);

        expect(find.text('FIRST DROP SALE'), findsOneWidget);
        expect(find.text('5s'), findsOneWidget);
        expect(find.text('Promotional Offer'), findsNothing);
        expect(find.text('Validity Window'), findsNothing);

        final detailedAd = buildAdModel(
          id: 'ad-diwali',
          title: 'Diwali Bonus',
          offerDetails: '+200 bonus pts automatically applied',
          imageUrl: null,
          duration: 5,
          startAt: DateTime.utc(2026, 11, 18),
          endAt: DateTime.utc(2026, 11, 26),
          serverNow: DateTime.utc(2026, 11, 18, 10),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AdvertisementPopup(
              advertisement: detailedAd,
              remainingSeconds: 5,
              totalSeconds: 5,
              onClose: () {},
            ),
          ),
        );
        await _pumpFrames(tester);

        expect(find.text('Diwali Bonus'), findsOneWidget);
        expect(find.text('5s'), findsOneWidget);
        expect(find.text('Promotional Offer'), findsOneWidget);
        expect(find.text('+200 bonus pts automatically applied'), findsOneWidget);
        expect(find.text('Validity Window'), findsOneWidget);
        expect(find.textContaining('8 Days Left'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'keeps Home unblocked during loading state, avoids duplicate impressions on Shiftexapp rebuilds, and selects secondary campaign on next session',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final authBloc = buildAuthBloc();
        final approvalBloc = buildApprovalBloc();
        final homeBloc = buildReadyHomeBloc();
        final pipe = buildPipeline(tickInterval: const Duration(seconds: 1));
        final gate = Completer<void>();
        pipe.remote.pendingDelay = gate;

        final campaignA = buildAdModel(
          id: 'ad-a',
          title: 'Primary Once Per User Campaign',
          priority: 10,
          frequencyType: AdvertisementFrequencyType.oncePerUser,
          frequencyLimit: 1,
          duration: 6,
        );
        final campaignB = buildAdModel(
          id: 'ad-b',
          title: 'Secondary Fallback Campaign',
          priority: 5,
          frequencyType: AdvertisementFrequencyType.oncePerSession,
          frequencyLimit: 1,
          duration: 6,
        );
        pipe.remote.adsToReturn = [campaignA, campaignB];

        authBloc.emit(AuthenticationSuccess(approvedProfile()));

        addTearDown(() async {
          await pipe.bloc.close();
          await homeBloc.close();
          await approvalBloc.close();
          await authBloc.close();
        });

        Widget buildApp() => Shiftexapp(
          authenticationBloc: authBloc,
          accountApprovalBloc: approvalBloc,
          homeBloc: homeBloc,
          advertisementBloc: pipe.bloc,
        );

        await tester.pumpWidget(buildApp());
        await _pumpFrames(tester);

        // While ad fetch is still loading, Home dashboard renders unblocked
        expect(pipe.bloc.state.status, AdvertisementStatus.loading);
        expect(find.text('Hello, Vishnu'), findsOneWidget);
        expect(find.byType(AdvertisementPopup), findsNothing);

        // Resolve fetch -> Primary Campaign shows & records 1 impression
        gate.complete();
        pipe.remote.pendingDelay = null;
        await _pumpFrames(tester);

        expect(find.text('Primary Once Per User Campaign'), findsOneWidget);
        expect(
          pipe.remote.recordedEvents
              .where((e) => e.type == AdvertisementEventType.impression)
              .length,
          1,
        );

        // Widget tree rebuild does not duplicate impressions
        await tester.pumpWidget(buildApp());
        await _pumpFrames(tester);
        expect(
          pipe.remote.recordedEvents
              .where((e) => e.type == AdvertisementEventType.impression)
              .length,
          1,
        );

        // Close popup, start new session (simulate fresh app launch/re-login) -> Campaign A capped once_per_user, Campaign B shows
        await tester.tap(
          find.byKey(const ValueKey('advertisement_close_button')),
        );
        await _pumpFrames(tester);
        pipe.bloc.add(
          const AdvertisementSessionStarted(
            userId: 'cust-1',
            forceNewSession: true,
          ),
        );
        await _pumpFrames(tester);

        expect(find.text('Secondary Fallback Campaign'), findsOneWidget);

        // Unmount app mid-countdown & close BLoC cleanly without pending timer leaks
        await tester.pumpWidget(const SizedBox.shrink());
        await pipe.bloc.close();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
