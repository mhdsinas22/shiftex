import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/routes/app_router.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/core/services/secure_storage_service.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/core/widgets/sign_out_dialog.dart';
import 'package:shiftex/features/account_approval/data/datasources/account_approval_remote_data_source.dart';
import 'package:shiftex/features/account_approval/data/models/customer_profile_model.dart';
import 'package:shiftex/features/account_approval/domain/entities/approval_status.dart';
import 'package:shiftex/features/account_approval/domain/usecases/get_approval_status_usecase.dart';
import 'package:shiftex/features/account_approval/presentation/bloc/account_approval_bloc.dart';
import 'package:shiftex/features/account_approval/presentation/bloc/account_approval_event.dart';
import 'package:shiftex/features/account_approval/presentation/bloc/account_approval_state.dart';
import 'package:shiftex/features/advertisements/domain/usecases/clear_advertisement_session_usecase.dart';
import 'package:shiftex/features/advertisements/domain/usecases/get_eligible_advertisement_usecase.dart';
import 'package:shiftex/features/advertisements/domain/usecases/track_advertisement_analytics_usecase.dart';
import 'package:shiftex/features/advertisements/presentation/bloc/advertisement_bloc.dart';
import 'package:shiftex/features/advertisements/presentation/bloc/advertisement_state.dart';
import 'package:shiftex/features/authentication/data/datasources/authentication_remote_data_source.dart';
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
import 'package:shiftex/features/home/domain/entities/daily_streak_entity.dart';
import 'package:shiftex/features/home/domain/entities/home_dashboard_entity.dart';
import 'package:shiftex/features/home/domain/entities/wallet_summary_entity.dart';
import 'package:shiftex/features/home/domain/usecases/generate_claim_qr_usecase.dart';
import 'package:shiftex/features/home/domain/usecases/get_home_dashboard_usecase.dart';
import 'package:shiftex/features/home/domain/usecases/track_advertisement_event_usecase.dart';
import 'package:shiftex/features/home/presentation/bloc/home_bloc.dart';
import 'package:shiftex/features/home/presentation/bloc/home_event.dart';
import 'package:shiftex/features/home/presentation/bloc/home_state.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_category.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_entity.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_filter.dart';
import 'package:shiftex/features/notifications/domain/usecases/get_notifications_usecase.dart';
import 'package:shiftex/features/notifications/domain/usecases/get_unread_notification_count_usecase.dart';
import 'package:shiftex/features/notifications/domain/usecases/mark_all_notifications_read_usecase.dart';
import 'package:shiftex/features/notifications/domain/usecases/mark_notification_read_usecase.dart';
import 'package:shiftex/features/notifications/domain/usecases/watch_notifications_realtime_usecase.dart';
import 'package:shiftex/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:shiftex/features/notifications/presentation/bloc/notification_event.dart';
import 'package:shiftex/shiftexapp.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockAccountApprovalRemoteDataSource extends Mock
    implements AccountApprovalRemoteDataSource {}

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

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

class _MockGetNotificationsUseCase extends Mock
    implements GetNotificationsUseCase {}

class _MockMarkNotificationReadUseCase extends Mock
    implements MarkNotificationReadUseCase {}

class _MockMarkAllNotificationsReadUseCase extends Mock
    implements MarkAllNotificationsReadUseCase {}

class _MockGetUnreadNotificationCountUseCase extends Mock
    implements GetUnreadNotificationCountUseCase {}

class _MockWatchNotificationsRealtimeUseCase extends Mock
    implements WatchNotificationsRealtimeUseCase {}

class _MockGetEligibleAdvertisementUseCase extends Mock
    implements GetEligibleAdvertisementUseCase {}

class _MockTrackAdvertisementAnalyticsUseCase extends Mock
    implements TrackAdvertisementAnalyticsUseCase {}

class _MockClearAdvertisementSessionUseCase extends Mock
    implements ClearAdvertisementSessionUseCase {}

void main() {
  final tNow = DateTime.utc(2026, 11, 24, 10, 0);

  CustomerProfileModel buildProfileModel(
    String id,
    String name,
    String email, {
    AccountApprovalStatus status = AccountApprovalStatus.approved,
  }) {
    return CustomerProfileModel(
      id: id,
      fullName: name,
      email: email,
      mobileNumber: '+919800000001',
      approvalStatus: status,
      createdAt: tNow,
      updatedAt: tNow,
    );
  }

  User buildAuthUser(String id, String email) {
    return User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      email: email,
      emailConfirmedAt: tNow.toIso8601String(),
      createdAt: tNow.toIso8601String(),
    );
  }

  Session buildSession(User user) {
    return Session(
      accessToken: 'jwt-${user.id}',
      refreshToken: 'refresh-${user.id}',
      tokenType: 'bearer',
      user: user,
    );
  }

  HomeDashboardEntity buildDashboard(
    String id,
    String name,
    String email,
    String code,
    int points,
  ) {
    return HomeDashboardEntity(
      customerId: id,
      fullName: name,
      email: email,
      mobileNumber: '+919800000001',
      wallet: WalletSummaryEntity(
        customerCode: code,
        membershipTier: 'Pebble Black Member',
        availablePoints: points,
        lockedPoints: 0,
        lifetimeEarnedPoints: points,
        lifetimeRedeemedPoints: 0,
        pointsEarnedToday: points,
        pointsToInrRate: 0.10,
      ),
      lockedAllocations: const [],
      streak: DailyStreakEntity(
        dailyLoginEnabled: true,
        dailyPoints: 15,
        currentStreakDay: 1,
        claimedToday: false,
        daysRemaining: 6,
        cycleDate: '2026-11-24',
        nextResetAt: tNow.add(const Duration(hours: 12)),
        justCompletedDay7: false,
        completedStreakPoints: 0,
      ),
      recentTransactions: const [],
      advertisements: const [],
    );
  }

  NotificationEntity buildNotification({
    required String id,
    required String userId,
    required String title,
    DateTime? readAt,
  }) {
    return NotificationEntity(
      id: id,
      userId: userId,
      category: NotificationCategory.pointsRewards,
      type: NotificationType.posPointsCredited,
      title: title,
      body: 'Points update for $userId',
      pointsAmount: 50,
      readAt: readAt,
      createdAt: tNow,
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
    registerFallbackValue(const GetHomeDashboardParams());
    registerFallbackValue(
      const GetNotificationsParams(filter: NotificationFilter.all),
    );
    registerFallbackValue(
      const GetEligibleAdvertisementParams(userId: '', sessionId: ''),
    );
    registerFallbackValue(
      const ClearAdvertisementSessionParams(sessionId: ''),
    );
    registerFallbackValue(SignOutScope.local);
  });

  group('SecureStorageService Logout Isolation', () {
    test(
      'clearUserAuthDataOnLogout removes previous user identifier and pending registration keys without deleting global settings or other users caches',
      () async {
        final store = <String, String>{
          'shiiftex_remember_me': 'true',
          'shiiftex_remembered_identifier': 'alice@example.com',
          'shiiftex_pending_verification_email': 'alice@example.com',
          'shiiftex_pending_full_name': 'Alice Smith',
          'shiiftex_pending_mobile': '+919800000001',
          'notifications_center_v1_user-b': '{"cached":true}',
          'ad_caps_user-b': '{"caps":1}',
        };

        final mockStorage = _MockFlutterSecureStorage();
        when(() => mockStorage.read(key: any(named: 'key'))).thenAnswer((inv) async {
          final key = inv.namedArguments[#key] as String;
          return store[key];
        });
        when(
          () => mockStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((inv) async {
          final key = inv.namedArguments[#key] as String;
          final val = inv.namedArguments[#value] as String?;
          if (val == null) {
            store.remove(key);
          } else {
            store[key] = val;
          }
        });
        when(() => mockStorage.delete(key: any(named: 'key'))).thenAnswer((
          inv,
        ) async {
          final key = inv.namedArguments[#key] as String;
          store.remove(key);
        });

        final service = SecureStorageService(mockStorage);
        await service.clearUserAuthDataOnLogout();

        expect(await service.getRememberedIdentifier(), isNull);
        final pending = await service.getPendingRegistrationContext();
        expect(pending['email'], isNull);
        expect(pending['fullName'], isNull);
        expect(pending['mobileNumber'], isNull);
        // Global app setting and unrelated user caches remain untouched
        expect(await service.getRememberMe(), isTrue);
        expect(store['notifications_center_v1_user-b'], '{"cached":true}');
        expect(store['ad_caps_user-b'], '{"caps":1}');
      },
    );
  });

  group('AuthenticationRemoteDataSourceImpl Session & Network Teardown', () {
    late _MockSupabaseClient mockSupabase;
    late _MockGoTrueClient mockAuth;
    late _MockAccountApprovalRemoteDataSource mockApprovalRemote;
    late _MockFlutterSecureStorage mockSecureStorage;
    late Map<String, String> storageMap;
    late AuthenticationRemoteDataSourceImpl dataSource;
    Session? activeSession;
    User? activeUser;

    setUp(() {
      mockSupabase = _MockSupabaseClient();
      mockAuth = _MockGoTrueClient();
      mockApprovalRemote = _MockAccountApprovalRemoteDataSource();
      mockSecureStorage = _MockFlutterSecureStorage();
      storageMap = <String, String>{};
      activeSession = null;
      activeUser = null;

      when(() => mockSupabase.auth).thenReturn(mockAuth);
      when(() => mockAuth.currentSession).thenAnswer((_) => activeSession);
      when(() => mockAuth.currentUser).thenAnswer((_) => activeUser);

      when(() => mockSecureStorage.read(key: any(named: 'key'))).thenAnswer((
        inv,
      ) async {
        return storageMap[inv.namedArguments[#key] as String];
      });
      when(
        () => mockSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((inv) async {
        final key = inv.namedArguments[#key] as String;
        final val = inv.namedArguments[#value] as String?;
        if (val != null) storageMap[key] = val;
      });
      when(() => mockSecureStorage.delete(key: any(named: 'key'))).thenAnswer((
        inv,
      ) async {
        storageMap.remove(inv.namedArguments[#key] as String);
      });

      dataSource = AuthenticationRemoteDataSourceImpl(
        supabaseClient: mockSupabase,
        approvalRemoteDataSource: mockApprovalRemote,
        secureStorageService: SecureStorageService(mockSecureStorage),
      );
    });

    test(
      'logout awaits signOut, verifies session/user are null, and clears remembered identifier',
      () async {
        final userA = buildAuthUser('user-a', 'alice@example.com');
        activeUser = userA;
        activeSession = buildSession(userA);
        storageMap['shiiftex_remembered_identifier'] = 'alice@example.com';

        when(() => mockAuth.signOut(scope: any(named: 'scope'))).thenAnswer((
          _,
        ) async {
          activeSession = null;
          activeUser = null;
        });

        await dataSource.logout();

        verify(() => mockAuth.signOut(scope: SignOutScope.local)).called(1);
        expect(activeSession, isNull);
        expect(activeUser, isNull);
        expect(storageMap.containsKey('shiiftex_remembered_identifier'), isFalse);
      },
    );

    test(
      'logout completes local teardown cleanly on unstable network once Supabase GoTrue clears local session, and rethrows server failure',
      () async {
        final userA = buildAuthUser('user-a', 'alice@example.com');
        activeUser = userA;
        activeSession = buildSession(userA);
        storageMap['shiiftex_remembered_identifier'] = 'alice@example.com';

        // 1. Unstable network after GoTrue removed local session
        when(() => mockAuth.signOut(scope: any(named: 'scope'))).thenAnswer((
          _,
        ) async {
          activeSession = null;
          activeUser = null;
          throw const SocketException('Network unstable');
        });

        await dataSource.logout();
        expect(storageMap.containsKey('shiiftex_remembered_identifier'), isFalse);

        // 2. Non-network server error -> surfaces exception
        activeUser = userA;
        activeSession = buildSession(userA);
        storageMap['shiiftex_remembered_identifier'] = 'alice@example.com';
        when(() => mockAuth.signOut(scope: any(named: 'scope'))).thenAnswer((
          _,
        ) async {
          activeSession = null;
          activeUser = null;
          throw const AuthException('Internal server failure', statusCode: '500');
        });

        await expectLater(dataSource.logout(), throwsA(isA<AuthException>()));
        expect(storageMap.containsKey('shiiftex_remembered_identifier'), isFalse);
      },
    );

    test(
      'login clears any lingering previous session first and rejects profile/user ID mismatch',
      () async {
        final userA = buildAuthUser('user-a', 'alice@example.com');
        final userB = buildAuthUser('user-b', 'bob@example.com');
        activeUser = userA;
        activeSession = buildSession(userA);

        when(() => mockAuth.signOut(scope: any(named: 'scope'))).thenAnswer((
          _,
        ) async {
          activeUser = null;
          activeSession = null;
        });

        when(
          () => mockAuth.signInWithPassword(
            email: 'bob@example.com',
            password: 'PasswordB1',
          ),
        ).thenAnswer((_) async {
          activeUser = userB;
          activeSession = buildSession(userB);
          return AuthResponse(session: activeSession, user: userB);
        });

        // First simulate mismatched profile from User A -> rejected!
        when(() => mockApprovalRemote.fetchCurrentCustomerProfile()).thenAnswer(
          (_) async => buildProfileModel(
            'user-a',
            'Alice Smith',
            'alice@example.com',
          ),
        );

        await expectLater(
          dataSource.login(
            identifier: 'bob@example.com',
            password: 'PasswordB1',
            rememberMe: true,
          ),
          throwsA(
            isA<AppAuthException>().having(
              (e) => e.code,
              'code',
              'session_expired',
            ),
          ),
        );

        // Matching profile succeeds cleanly for User B
        when(() => mockApprovalRemote.fetchCurrentCustomerProfile()).thenAnswer(
          (_) async =>
              buildProfileModel('user-b', 'Bob Jones', 'bob@example.com'),
        );

        final loggedIn = await dataSource.login(
          identifier: 'bob@example.com',
          password: 'PasswordB1',
          rememberMe: true,
        );
        expect(loggedIn.id, 'user-b');
        expect(loggedIn.fullName, 'Bob Jones');
      },
    );
  });

  group('AuthenticationBloc Concurrency, Failure & Rapid Switch Isolation', () {
    late _MockRegisterUseCase mockRegister;
    late _MockVerifyEmailOtpUseCase mockVerifyOtp;
    late _MockResendEmailOtpUseCase mockResendOtp;
    late _MockLoginUseCase mockLogin;
    late _MockLogoutUseCase mockLogout;
    late _MockForgotPasswordUseCase mockForgotPassword;
    late _MockVerifyPasswordResetOtpUseCase mockVerifyReset;
    late _MockResetPasswordUseCase mockResetPassword;
    late _MockGetCurrentSessionProfileUseCase mockGetSessionProfile;
    late _MockGetApprovalStatusUseCase mockGetApprovalStatus;
    late _MockAuthenticationRepository mockAuthRepo;
    late StreamController<String> authEventController;

    final userA = buildProfileModel('user-a', 'Alice Smith', 'alice@example.com');
    final userB = buildProfileModel('user-b', 'Bob Jones', 'bob@example.com');

    AuthenticationBloc buildAuthBloc() {
      return AuthenticationBloc(
        registerUseCase: mockRegister,
        verifyEmailOtpUseCase: mockVerifyOtp,
        resendEmailOtpUseCase: mockResendOtp,
        loginUseCase: mockLogin,
        logoutUseCase: mockLogout,
        forgotPasswordUseCase: mockForgotPassword,
        verifyPasswordResetOtpUseCase: mockVerifyReset,
        resetPasswordUseCase: mockResetPassword,
        getCurrentSessionProfileUseCase: mockGetSessionProfile,
        getApprovalStatusUseCase: mockGetApprovalStatus,
        authRepository: mockAuthRepo,
      );
    }

    setUp(() {
      mockRegister = _MockRegisterUseCase();
      mockVerifyOtp = _MockVerifyEmailOtpUseCase();
      mockResendOtp = _MockResendEmailOtpUseCase();
      mockLogin = _MockLoginUseCase();
      mockLogout = _MockLogoutUseCase();
      mockForgotPassword = _MockForgotPasswordUseCase();
      mockVerifyReset = _MockVerifyPasswordResetOtpUseCase();
      mockResetPassword = _MockResetPasswordUseCase();
      mockGetSessionProfile = _MockGetCurrentSessionProfileUseCase();
      mockGetApprovalStatus = _MockGetApprovalStatusUseCase();
      mockAuthRepo = _MockAuthenticationRepository();
      authEventController = StreamController<String>.broadcast();

      when(
        () => mockAuthRepo.authSessionEvents,
      ).thenAnswer((_) => authEventController.stream);
    });

    tearDown(() async {
      await authEventController.close();
    });

    blocTest<AuthenticationBloc, AuthenticationState>(
      'Scenario 4: server logout failure emits AuthenticationFailure with previousProfile instead of reporting fake Unauthenticated even if signedOut stream fires',
      build: () {
        when(() => mockLogout(any())).thenAnswer((_) async {
          authEventController.add('signedOut');
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return const Left(ServerFailure('Unable to reach logout service.'));
        });
        return buildAuthBloc();
      },
      seed: () => AuthenticationSuccess(userA),
      act: (bloc) => bloc.add(const LogoutRequested()),
      wait: const Duration(milliseconds: 30),
      expect: () => [
        AuthenticationLoading(currentProfile: userA),
        AuthenticationFailure(
          const ServerFailure('Unable to reach logout service.'),
          previousProfile: userA,
        ),
      ],
    );

    blocTest<AuthenticationBloc, AuthenticationState>(
      'Scenario 5: rapid LogoutRequested followed immediately by LoginRequested (User B) completes logout first and resolves strictly to User B',
      build: () {
        final callOrder = <String>[];
        when(() => mockLogout(any())).thenAnswer((_) async {
          callOrder.add('logout-start');
          await Future<void>.delayed(const Duration(milliseconds: 40));
          callOrder.add('logout-end');
          return const Right(null);
        });
        when(() => mockLogin(any())).thenAnswer((_) async {
          callOrder.add('login-b');
          expect(callOrder, ['logout-start', 'logout-end', 'login-b']);
          return Right(userB);
        });
        return buildAuthBloc();
      },
      seed: () => AuthenticationSuccess(userA),
      act: (bloc) async {
        bloc.add(const LogoutRequested());
        await Future<void>.delayed(const Duration(milliseconds: 5));
        bloc.add(
          const LoginRequested(
            identifier: 'bob@example.com',
            password: 'PasswordB1',
          ),
        );
      },
      wait: const Duration(milliseconds: 80),
      expect: () => [
        AuthenticationLoading(currentProfile: userA),
        const AuthenticationLoading(),
        AuthenticationSuccess(userB),
      ],
    );

    blocTest<AuthenticationBloc, AuthenticationState>(
      'discards stale in-flight AuthSessionChanged (User A) superseded by LogoutRequested',
      build: () {
        when(() => mockGetSessionProfile(any())).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 40));
          return Right(userA);
        });
        when(() => mockLogout(any())).thenAnswer((_) async => const Right(null));
        return buildAuthBloc();
      },
      act: (bloc) async {
        bloc.add(const AuthSessionChanged());
        await Future<void>.delayed(const Duration(milliseconds: 5));
        bloc.add(const LogoutRequested());
      },
      wait: const Duration(milliseconds: 80),
      expect: () => [
        const AuthenticationLoading(),
        const Unauthenticated(),
      ],
    );
  });

  group('HomeBloc, NotificationBloc, and AppRouter Isolation', () {
    test(
      'AppRouter keeps AuthenticationFailure with approved previousProfile on protected routes during failed logout',
      () {
        final userA = buildProfileModel('user-a', 'Alice Smith', 'alice@example.com');
        expect(
          AppRouter.evaluateAuthRedirect(
            authState: AuthenticationFailure(
              const ServerFailure('Logout error'),
              previousProfile: userA,
            ),
            matchedLocation: RoutesNames.home,
          ),
          isNull,
        );
      },
    );

    test(
      'HomeBloc HomeSessionReset clears User A dashboard/QR and ignores in-flight User A fetches',
      () async {
        final mockDashboard = _MockGetHomeDashboardUseCase();
        final mockClaimQr = _MockGenerateClaimQrUseCase();
        final mockTrackAd = _MockTrackAdvertisementEventUseCase();
        final delayedFetch = Completer<Either<Failure, HomeDashboardEntity>>();

        when(() => mockDashboard(any())).thenAnswer((_) => delayedFetch.future);
        final bloc = HomeBloc(
          getHomeDashboardUseCase: mockDashboard,
          generateClaimQrUseCase: mockClaimQr,
          trackAdvertisementEventUseCase: mockTrackAd,
        );
        addTearDown(bloc.close);

        bloc.add(const HomeDashboardLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const HomeSessionReset());
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Late resolution for User A arrives after reset
        delayedFetch.complete(
          Right(
            buildDashboard(
              'user-a',
              'Alice Smith',
              'alice@example.com',
              'SHFT-AAAA',
              120,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(bloc.state.status, HomeStatus.initial);
        expect(bloc.state.dashboard, isNull);
        expect(bloc.state.activeQrToken, isNull);
      },
    );

    test(
      'NotificationBloc stops Account A, clears cache, and ignores late Account A responses',
      () async {
        final mockGet = _MockGetNotificationsUseCase();
        final mockMark = _MockMarkNotificationReadUseCase();
        final mockMarkAll = _MockMarkAllNotificationsReadUseCase();
        final mockUnread = _MockGetUnreadNotificationCountUseCase();
        final mockWatch = _MockWatchNotificationsRealtimeUseCase();

        final slowUserAFetch = Completer<Either<Failure, NotificationPageEntity>>();
        when(() => mockWatch.connectionStateStream).thenAnswer(
          (_) => const Stream.empty(),
        );
        when(() => mockWatch(userId: any(named: 'userId'))).thenAnswer(
          (_) => const Stream.empty(),
        );
        when(() => mockWatch.stop(userId: any(named: 'userId'))).thenAnswer(
          (_) async {},
        );
        var callCount = 0;
        when(() => mockGet(any())).thenAnswer((_) {
          callCount++;
          if (callCount == 1) {
            return slowUserAFetch.future;
          }
          return Future.value(
            Right(
              NotificationPageEntity(
                filter: NotificationFilter.all,
                limit: 20,
                offset: 0,
                hasMore: false,
                counts: const NotificationCountsEntity(all: 1, unread: 1),
                notifications: [
                  buildNotification(
                    id: 'notif-b',
                    userId: 'user-b',
                    title: 'Welcome Bob',
                  ),
                ],
              ),
            ),
          );
        });
        when(() => mockUnread()).thenAnswer((_) async => const Right(0));

        final bloc = NotificationBloc(
          getNotificationsUseCase: mockGet,
          markNotificationReadUseCase: mockMark,
          markAllNotificationsReadUseCase: mockMarkAll,
          getUnreadNotificationCountUseCase: mockUnread,
          watchNotificationsRealtimeUseCase: mockWatch,
        );
        addTearDown(bloc.close);

        bloc.add(const NotificationsStarted('user-a'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const NotificationsStopped());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const NotificationsStarted('user-b'));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Now User A's slow fetch resolves late -> MUST NOT leak into User B
        slowUserAFetch.complete(
          Right(
            NotificationPageEntity(
              filter: NotificationFilter.all,
              limit: 20,
              offset: 0,
              hasMore: false,
              counts: const NotificationCountsEntity(all: 1, unread: 1),
              notifications: [
                buildNotification(
                  id: 'notif-a',
                  userId: 'user-a',
                  title: 'Secret Alice Reward',
                ),
              ],
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        verify(() => mockWatch.stop(userId: 'user-a')).called(1);
        expect(bloc.state.activeUserId, 'user-b');
        expect(bloc.state.notifications.map((e) => e.title), ['Welcome Bob']);
      },
    );

    test(
      'AccountApprovalBloc AccountApprovalReset discards in-flight approval checks and returns to initial state',
      () async {
        final mockGetApproval = _MockGetApprovalStatusUseCase();
        final slowCheck = Completer<Either<Failure, CustomerProfileModel>>();
        when(() => mockGetApproval(any())).thenAnswer((_) => slowCheck.future);

        final approvalBloc = AccountApprovalBloc(
          getApprovalStatusUseCase: mockGetApproval,
        );
        addTearDown(approvalBloc.close);

        approvalBloc.add(const LoadApprovalStatusRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        approvalBloc.add(const AccountApprovalReset());
        await Future<void>.delayed(const Duration(milliseconds: 10));

        slowCheck.complete(
          Right(buildProfileModel('user-a', 'Alice Smith', 'alice@example.com')),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(approvalBloc.state, const AccountApprovalInitial());
      },
    );

    testWidgets(
      'signOutDialog surfaces server failure SnackBar cleanly and closes only the dialog without typo',
      (WidgetTester tester) async {
        final userA = buildProfileModel('user-a', 'Alice Smith', 'alice@example.com');
        final mockLogout = _MockLogoutUseCase();
        final mockAuthRepo = _MockAuthenticationRepository();
        when(() => mockAuthRepo.authSessionEvents).thenAnswer(
          (_) => const Stream.empty(),
        );
        when(() => mockLogout(any())).thenAnswer(
          (_) async =>
              const Left(ServerFailure('Server failed to revoke session.')),
        );

        final authBloc = AuthenticationBloc(
          registerUseCase: _MockRegisterUseCase(),
          verifyEmailOtpUseCase: _MockVerifyEmailOtpUseCase(),
          resendEmailOtpUseCase: _MockResendEmailOtpUseCase(),
          loginUseCase: _MockLoginUseCase(),
          logoutUseCase: mockLogout,
          forgotPasswordUseCase: _MockForgotPasswordUseCase(),
          verifyPasswordResetOtpUseCase: _MockVerifyPasswordResetOtpUseCase(),
          resetPasswordUseCase: _MockResetPasswordUseCase(),
          getCurrentSessionProfileUseCase:
              _MockGetCurrentSessionProfileUseCase(),
          getApprovalStatusUseCase: _MockGetApprovalStatusUseCase(),
          authRepository: mockAuthRepo,
        );
        authBloc.emit(AuthenticationSuccess(userA));
        addTearDown(authBloc.close);

        await tester.pumpWidget(
          BlocProvider<AuthenticationBloc>.value(
            value: authBloc,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => signOutDialog(context),
                    child: const Text('TriggerLogout'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('TriggerLogout'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Sign Out'));
        await tester.pumpAndSettle();

        expect(find.text('Server failed to revoke session.'), findsOneWidget);
        expect(find.text('Un Authenction the user'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('End-to-End Shiftexapp Multi-Account Session Switching', () {
    Future<void> pumpTransition(WidgetTester tester) async {
      await tester.pump();
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets(
      'Scenarios 1, 2, 3 & 6: User A login -> Logout via signOutDialog resets Home/Notification/Ad/Approval state -> User B login shows only User B and survives simulated restart',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
        });

        final userA = buildProfileModel('user-a', 'Alice Smith', 'alice@example.com');
        final userB = buildProfileModel('user-b', 'Bob Jones', 'bob@example.com');
        final dashA = buildDashboard(
          'user-a',
          'Alice Smith',
          'alice@example.com',
          'SHFT-AAAA',
          120,
        );
        final dashB = buildDashboard(
          'user-b',
          'Bob Jones',
          'bob@example.com',
          'SHFT-BBBB',
          260,
        );

        CustomerProfileModel? persistedSessionUser;

        final mockLogin = _MockLoginUseCase();
        final mockLogout = _MockLogoutUseCase();
        final mockGetSession = _MockGetCurrentSessionProfileUseCase();
        final mockGetApproval = _MockGetApprovalStatusUseCase();
        final mockAuthRepo = _MockAuthenticationRepository();
        when(
          () => mockAuthRepo.authSessionEvents,
        ).thenAnswer((_) => const Stream.empty());

        when(() => mockLogin(any())).thenAnswer((inv) async {
          final params = inv.positionalArguments.first as LoginParams;
          if (params.identifier == 'alice@example.com') {
            persistedSessionUser = userA;
            return Right(userA);
          }
          persistedSessionUser = userB;
          return Right(userB);
        });
        when(() => mockLogout(any())).thenAnswer((_) async {
          persistedSessionUser = null;
          return const Right(null);
        });
        when(() => mockGetSession(any())).thenAnswer(
          (_) async => Right(persistedSessionUser),
        );

        final mockDashboard = _MockGetHomeDashboardUseCase();
        when(() => mockDashboard(any())).thenAnswer((_) async {
          if (persistedSessionUser?.id == 'user-b') {
            return Right(dashB);
          }
          return Right(dashA);
        });

        final mockGetNotifs = _MockGetNotificationsUseCase();
        final mockWatchNotifs = _MockWatchNotificationsRealtimeUseCase();
        final mockUnreadNotifs = _MockGetUnreadNotificationCountUseCase();
        when(() => mockWatchNotifs.connectionStateStream).thenAnswer(
          (_) => const Stream.empty(),
        );
        when(() => mockWatchNotifs(userId: any(named: 'userId'))).thenAnswer(
          (_) => const Stream.empty(),
        );
        when(() => mockWatchNotifs.stop(userId: any(named: 'userId'))).thenAnswer(
          (_) async {},
        );
        when(() => mockUnreadNotifs()).thenAnswer((_) async => const Right(1));
        when(() => mockGetNotifs(any())).thenAnswer((_) async {
          final uid = persistedSessionUser?.id ?? 'unknown';
          return Right(
            NotificationPageEntity(
              filter: NotificationFilter.all,
              limit: 20,
              offset: 0,
              hasMore: false,
              counts: const NotificationCountsEntity(all: 1, unread: 1),
              notifications: [
                buildNotification(
                  id: 'notif-$uid',
                  userId: uid,
                  title: uid == 'user-b' ? 'Bob Bonus' : 'Alice Bonus',
                ),
              ],
            ),
          );
        });

        final mockGetAd = _MockGetEligibleAdvertisementUseCase();
        final mockTrackAd = _MockTrackAdvertisementAnalyticsUseCase();
        final mockClearAd = _MockClearAdvertisementSessionUseCase();
        when(() => mockGetAd(any())).thenAnswer((_) async => const Right(null));
        when(() => mockClearAd(any())).thenAnswer((_) async => const Right(null));

        AuthenticationBloc createAuthBloc() => AuthenticationBloc(
          registerUseCase: _MockRegisterUseCase(),
          verifyEmailOtpUseCase: _MockVerifyEmailOtpUseCase(),
          resendEmailOtpUseCase: _MockResendEmailOtpUseCase(),
          loginUseCase: mockLogin,
          logoutUseCase: mockLogout,
          forgotPasswordUseCase: _MockForgotPasswordUseCase(),
          verifyPasswordResetOtpUseCase: _MockVerifyPasswordResetOtpUseCase(),
          resetPasswordUseCase: _MockResetPasswordUseCase(),
          getCurrentSessionProfileUseCase: mockGetSession,
          getApprovalStatusUseCase: mockGetApproval,
          authRepository: mockAuthRepo,
        );

        HomeBloc createHomeBloc() => HomeBloc(
          getHomeDashboardUseCase: mockDashboard,
          generateClaimQrUseCase: _MockGenerateClaimQrUseCase(),
          trackAdvertisementEventUseCase: _MockTrackAdvertisementEventUseCase(),
        );

        NotificationBloc createNotifBloc() => NotificationBloc(
          getNotificationsUseCase: mockGetNotifs,
          markNotificationReadUseCase: _MockMarkNotificationReadUseCase(),
          markAllNotificationsReadUseCase:
              _MockMarkAllNotificationsReadUseCase(),
          getUnreadNotificationCountUseCase: mockUnreadNotifs,
          watchNotificationsRealtimeUseCase: mockWatchNotifs,
        );

        AdvertisementBloc createAdBloc() => AdvertisementBloc(
          getEligibleAdvertisementUseCase: mockGetAd,
          trackAdvertisementAnalyticsUseCase: mockTrackAd,
          clearAdvertisementSessionUseCase: mockClearAd,
        );

        final authBloc1 = createAuthBloc();
        final homeBloc1 = createHomeBloc();
        final notifBloc1 = createNotifBloc();
        final adBloc1 = createAdBloc();
        final approvalBloc1 = AccountApprovalBloc(
          getApprovalStatusUseCase: mockGetApproval,
        );

        addTearDown(() async {
          await authBloc1.close();
          await homeBloc1.close();
          await notifBloc1.close();
          await adBloc1.close();
          await approvalBloc1.close();
        });

        await tester.pumpWidget(
          Shiftexapp(
            authenticationBloc: authBloc1,
            accountApprovalBloc: approvalBloc1,
            homeBloc: homeBloc1,
            notificationBloc: notifBloc1,
            advertisementBloc: adBloc1,
          ),
        );
        authBloc1.add(const AuthSessionChanged());
        await pumpTransition(tester);

        // Login as User A
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Mobile number or email'),
          'alice@example.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter your password'),
          'PasswordA1',
        );
        await tester.tap(find.text('Sign In'));
        await pumpTransition(tester);

        expect(find.text('Hello, Alice'), findsOneWidget);
        expect(find.text('SHFT-AAAA'), findsOneWidget);
        expect(notifBloc1.state.activeUserId, 'user-a');
        expect(notifBloc1.state.notifications.first.title, 'Alice Bonus');

        // Scenario 2: Simulated restart while User A is signed in -> restores User A
        final authBlocRestartA = createAuthBloc();
        final homeBlocRestartA = createHomeBloc();
        final notifBlocRestartA = createNotifBloc();
        final adBlocRestartA = createAdBloc();
        final approvalBlocRestartA = AccountApprovalBloc(
          getApprovalStatusUseCase: mockGetApproval,
        );
        addTearDown(() async {
          await authBlocRestartA.close();
          await homeBlocRestartA.close();
          await notifBlocRestartA.close();
          await adBlocRestartA.close();
          await approvalBlocRestartA.close();
        });

        await tester.pumpWidget(
          Shiftexapp(
            key: const ValueKey('restart-a'),
            authenticationBloc: authBlocRestartA,
            accountApprovalBloc: approvalBlocRestartA,
            homeBloc: homeBlocRestartA,
            notificationBloc: notifBlocRestartA,
            advertisementBloc: adBlocRestartA,
          ),
        );
        authBlocRestartA.add(const AuthSessionChanged());
        await pumpTransition(tester);

        expect(find.text('Hello, Alice'), findsOneWidget);
        expect(find.text('SHFT-AAAA'), findsOneWidget);

        // Tap User A profile avatar -> open CustomerProfileSheet -> Sign Out -> signOutDialog
        await tester.tap(find.text('AS'));
        await pumpTransition(tester);
        await tester.tap(find.text('Sign Out'));
        await pumpTransition(tester);
        await tester.tap(find.widgetWithText(TextButton, 'Sign Out'));
        await pumpTransition(tester);
        await tester.pumpAndSettle();

        // Clean login screen + reset BLoCs + zero User A cache
        expect(find.text('Welcome back'), findsOneWidget);
        expect(homeBlocRestartA.state.status, HomeStatus.initial);
        expect(homeBlocRestartA.state.dashboard, isNull);
        expect(notifBlocRestartA.state.activeUserId, isNull);
        expect(notifBlocRestartA.state.notifications, isEmpty);
        expect(adBlocRestartA.state.status, AdvertisementStatus.initial);
        verify(() => mockWatchNotifs.stop(userId: 'user-a')).called(1);

        // Login as User B
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Mobile number or email'),
          'bob@example.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter your password'),
          'PasswordB1',
        );
        await tester.tap(find.text('Sign In'));
        await pumpTransition(tester);

        // User B UI renders strictly User B data with zero Account A leakage
        expect(find.text('Hello, Bob'), findsOneWidget);
        expect(find.text('SHFT-BBBB'), findsOneWidget);
        expect(find.text('Hello, Alice'), findsNothing);
        expect(find.text('SHFT-AAAA'), findsNothing);
        expect(notifBlocRestartA.state.activeUserId, 'user-b');
        expect(notifBlocRestartA.state.notifications.map((n) => n.title), [
          'Bob Bonus',
        ]);

        // Scenario 3: Restart after switching -> confirms ONLY User B restores
        final authBlocRestartB = createAuthBloc();
        final homeBlocRestartB = createHomeBloc();
        final notifBlocRestartB = createNotifBloc();
        final adBlocRestartB = createAdBloc();
        final approvalBlocRestartB = AccountApprovalBloc(
          getApprovalStatusUseCase: mockGetApproval,
        );
        addTearDown(() async {
          await authBlocRestartB.close();
          await homeBlocRestartB.close();
          await notifBlocRestartB.close();
          await adBlocRestartB.close();
          await approvalBlocRestartB.close();
        });

        await tester.pumpWidget(
          Shiftexapp(
            key: const ValueKey('restart-b'),
            authenticationBloc: authBlocRestartB,
            accountApprovalBloc: approvalBlocRestartB,
            homeBloc: homeBlocRestartB,
            notificationBloc: notifBlocRestartB,
            advertisementBloc: adBlocRestartB,
          ),
        );
        authBlocRestartB.add(const AuthSessionChanged());
        await pumpTransition(tester);

        expect(find.text('Hello, Bob'), findsOneWidget);
        expect(find.text('SHFT-BBBB'), findsOneWidget);
        expect(find.text('Hello, Alice'), findsNothing);
        expect(notifBlocRestartB.state.activeUserId, 'user-b');
      },
    );
  });
}
