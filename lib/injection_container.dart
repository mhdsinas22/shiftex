import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shiftex/core/config/supabase_config.dart';
import 'package:shiftex/core/network/network_info.dart';
import 'package:shiftex/core/routes/app_router.dart';
import 'package:shiftex/core/services/secure_storage_service.dart';
import 'package:shiftex/features/account_approval/data/datasources/account_approval_remote_data_source.dart';
import 'package:shiftex/features/account_approval/data/repositories/account_approval_repository_impl.dart';
import 'package:shiftex/features/account_approval/domain/repositories/account_approval_repository.dart';
import 'package:shiftex/features/account_approval/domain/usecases/ensure_customer_profile_usecase.dart';
import 'package:shiftex/features/account_approval/domain/usecases/get_approval_status_usecase.dart';
import 'package:shiftex/features/account_approval/presentation/bloc/account_approval_bloc.dart';
import 'package:shiftex/features/activity_history/data/datasources/activity_history_remote_data_source.dart';
import 'package:shiftex/features/activity_history/data/datasources/statement_exporter_service.dart';
import 'package:shiftex/features/activity_history/data/repositories/activity_history_repository_impl.dart';
import 'package:shiftex/features/activity_history/domain/repositories/activity_history_repository.dart';
import 'package:shiftex/features/activity_history/domain/usecases/export_monthly_statement_usecase.dart';
import 'package:shiftex/features/activity_history/domain/usecases/get_activity_history_usecase.dart';
import 'package:shiftex/features/activity_history/domain/usecases/get_monthly_statement_usecase.dart';
import 'package:shiftex/features/activity_history/domain/usecases/get_transaction_detail_usecase.dart';
import 'package:shiftex/features/activity_history/presentation/bloc/activity_history_bloc.dart';
import 'package:shiftex/features/advertisements/data/datasources/advertisement_local_data_source.dart';
import 'package:shiftex/features/advertisements/data/datasources/advertisement_remote_data_source.dart';
import 'package:shiftex/features/advertisements/data/repositories/advertisement_repository_impl.dart';
import 'package:shiftex/features/advertisements/domain/repositories/advertisement_repository.dart';
import 'package:shiftex/features/advertisements/domain/usecases/clear_advertisement_session_usecase.dart';
import 'package:shiftex/features/advertisements/domain/usecases/get_eligible_advertisement_usecase.dart';
import 'package:shiftex/features/advertisements/domain/usecases/track_advertisement_analytics_usecase.dart';
import 'package:shiftex/features/advertisements/presentation/bloc/advertisement_bloc.dart';
import 'package:shiftex/features/authentication/data/datasources/authentication_remote_data_source.dart';
import 'package:shiftex/features/authentication/data/repositories/authentication_repository_impl.dart';
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
import 'package:shiftex/features/home/data/repositories/home_repository_impl.dart';
import 'package:shiftex/features/home/domain/repositories/home_repository.dart';
import 'package:shiftex/features/home/domain/usecases/generate_claim_qr_usecase.dart';
import 'package:shiftex/features/home/domain/usecases/get_home_dashboard_usecase.dart';
import 'package:shiftex/features/home/domain/usecases/track_advertisement_event_usecase.dart';
import 'package:shiftex/features/claim_rewards/data/datasources/claim_rewards_remote_data_source.dart';
import 'package:shiftex/features/claim_rewards/data/repositories/claim_rewards_repository_impl.dart';
import 'package:shiftex/features/claim_rewards/domain/repositories/claim_rewards_repository.dart';
import 'package:shiftex/features/claim_rewards/domain/usecases/cancel_reward_claim_usecase.dart';
import 'package:shiftex/features/claim_rewards/domain/usecases/create_reward_claim_usecase.dart';
import 'package:shiftex/features/claim_rewards/domain/usecases/get_claim_rewards_context_usecase.dart';
import 'package:shiftex/features/claim_rewards/domain/usecases/get_customer_claim_status_usecase.dart';
import 'package:shiftex/features/claim_rewards/presentation/bloc/claim_rewards_bloc.dart';
import 'package:shiftex/features/customer_qr/data/datasources/customer_qr_remote_data_source.dart';
import 'package:shiftex/features/customer_qr/data/repositories/customer_qr_repository_impl.dart';
import 'package:shiftex/features/customer_qr/domain/repositories/customer_qr_repository.dart';
import 'package:shiftex/features/customer_qr/domain/usecases/get_customer_personal_qr_usecase.dart';
import 'package:shiftex/features/customer_qr/domain/usecases/revoke_customer_personal_qr_usecase.dart';
import 'package:shiftex/features/customer_qr/presentation/bloc/customer_qr_bloc.dart';
import 'package:shiftex/features/home/presentation/bloc/home_bloc.dart';
import 'package:shiftex/features/notifications/data/datasources/notification_local_data_source.dart';
import 'package:shiftex/features/notifications/data/datasources/notification_remote_data_source.dart';
import 'package:shiftex/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:shiftex/features/notifications/domain/repositories/notification_repository.dart';
import 'package:shiftex/features/notifications/domain/usecases/get_notifications_usecase.dart';
import 'package:shiftex/features/notifications/domain/usecases/get_unread_notification_count_usecase.dart';
import 'package:shiftex/features/notifications/domain/usecases/mark_all_notifications_read_usecase.dart';
import 'package:shiftex/features/notifications/domain/usecases/mark_notification_read_usecase.dart';
import 'package:shiftex/features/notifications/domain/usecases/watch_notifications_realtime_usecase.dart';
import 'package:shiftex/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final GetIt getIt = GetIt.instance;
final GetIt sl = getIt;

Future<void> initializeDependencies({
  SupabaseClient? customSupabaseClient,
}) async {
  if (getIt.isRegistered<AuthenticationBloc>()) {
    return;
  }

  final SupabaseClient supabaseClient;
  if (customSupabaseClient != null) {
    supabaseClient = customSupabaseClient;
  } else {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
    );
    supabaseClient = Supabase.instance.client;
  }

  // External & Core Services
  getIt.registerLazySingleton<SupabaseClient>(() => supabaseClient);
  getIt.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
  getIt.registerLazySingleton<SecureStorageService>(
    () => SecureStorageService(getIt<FlutterSecureStorage>()),
  );
  getIt.registerLazySingleton<NetworkInfo>(() => const NetworkInfoImpl());

  // Data Sources
  getIt.registerLazySingleton<AccountApprovalRemoteDataSource>(
    () => AccountApprovalRemoteDataSourceImpl(getIt<SupabaseClient>()),
  );
  getIt.registerLazySingleton<AuthenticationRemoteDataSource>(
    () => AuthenticationRemoteDataSourceImpl(
      supabaseClient: getIt<SupabaseClient>(),
      approvalRemoteDataSource: getIt<AccountApprovalRemoteDataSource>(),
      secureStorageService: getIt<SecureStorageService>(),
    ),
  );
  getIt.registerLazySingleton<HomeRemoteDataSource>(
    () => HomeRemoteDataSourceImpl(getIt<SupabaseClient>()),
  );

  // Repositories
  getIt.registerLazySingleton<AccountApprovalRepository>(
    () =>
        AccountApprovalRepositoryImpl(getIt<AccountApprovalRemoteDataSource>()),
  );
  getIt.registerLazySingleton<AuthenticationRepository>(
    () => AuthenticationRepositoryImpl(getIt<AuthenticationRemoteDataSource>()),
  );
  getIt.registerLazySingleton<HomeRepository>(
    () => HomeRepositoryImpl(getIt<HomeRemoteDataSource>()),
  );

  // Use Cases - Account Approval
  getIt.registerLazySingleton<EnsureCustomerProfileUseCase>(
    () => EnsureCustomerProfileUseCase(getIt<AccountApprovalRepository>()),
  );
  getIt.registerLazySingleton<GetApprovalStatusUseCase>(
    () => GetApprovalStatusUseCase(getIt<AccountApprovalRepository>()),
  );

  // Use Cases - Authentication
  getIt.registerLazySingleton<RegisterUseCase>(
    () => RegisterUseCase(getIt<AuthenticationRepository>()),
  );
  getIt.registerLazySingleton<VerifyEmailOtpUseCase>(
    () => VerifyEmailOtpUseCase(getIt<AuthenticationRepository>()),
  );
  getIt.registerLazySingleton<ResendEmailOtpUseCase>(
    () => ResendEmailOtpUseCase(getIt<AuthenticationRepository>()),
  );
  getIt.registerLazySingleton<LoginUseCase>(
    () => LoginUseCase(getIt<AuthenticationRepository>()),
  );
  getIt.registerLazySingleton<LogoutUseCase>(
    () => LogoutUseCase(getIt<AuthenticationRepository>()),
  );
  getIt.registerLazySingleton<ForgotPasswordUseCase>(
    () => ForgotPasswordUseCase(getIt<AuthenticationRepository>()),
  );
  getIt.registerLazySingleton<VerifyPasswordResetOtpUseCase>(
    () => VerifyPasswordResetOtpUseCase(getIt<AuthenticationRepository>()),
  );
  getIt.registerLazySingleton<ResetPasswordUseCase>(
    () => ResetPasswordUseCase(getIt<AuthenticationRepository>()),
  );
  getIt.registerLazySingleton<GetCurrentSessionProfileUseCase>(
    () => GetCurrentSessionProfileUseCase(getIt<AuthenticationRepository>()),
  );

  // Use Cases - Customer Home Dashboard
  getIt.registerLazySingleton<GetHomeDashboardUseCase>(
    () => GetHomeDashboardUseCase(getIt<HomeRepository>()),
  );
  getIt.registerLazySingleton<GenerateClaimQrUseCase>(
    () => GenerateClaimQrUseCase(getIt<HomeRepository>()),
  );
  getIt.registerLazySingleton<TrackAdvertisementEventUseCase>(
    () => TrackAdvertisementEventUseCase(getIt<HomeRepository>()),
  );

  // BLoCs
  getIt.registerLazySingleton<AuthenticationBloc>(
    () => AuthenticationBloc(
      registerUseCase: getIt<RegisterUseCase>(),
      verifyEmailOtpUseCase: getIt<VerifyEmailOtpUseCase>(),
      resendEmailOtpUseCase: getIt<ResendEmailOtpUseCase>(),
      loginUseCase: getIt<LoginUseCase>(),
      logoutUseCase: getIt<LogoutUseCase>(),
      forgotPasswordUseCase: getIt<ForgotPasswordUseCase>(),
      verifyPasswordResetOtpUseCase: getIt<VerifyPasswordResetOtpUseCase>(),
      resetPasswordUseCase: getIt<ResetPasswordUseCase>(),
      getCurrentSessionProfileUseCase: getIt<GetCurrentSessionProfileUseCase>(),
      getApprovalStatusUseCase: getIt<GetApprovalStatusUseCase>(),
      authRepository: getIt<AuthenticationRepository>(),
    ),
  );

  getIt.registerFactory<AccountApprovalBloc>(
    () => AccountApprovalBloc(
      getApprovalStatusUseCase: getIt<GetApprovalStatusUseCase>(),
    ),
  );

  getIt.registerFactory<HomeBloc>(
    () => HomeBloc(
      getHomeDashboardUseCase: getIt<GetHomeDashboardUseCase>(),
      generateClaimQrUseCase: getIt<GenerateClaimQrUseCase>(),
      trackAdvertisementEventUseCase: getIt<TrackAdvertisementEventUseCase>(),
    ),
  );

  // Customer Personal QR Display Feature
  getIt.registerLazySingleton<CustomerQrRemoteDataSource>(
    () => CustomerQrRemoteDataSourceImpl(getIt<SupabaseClient>()),
  );
  getIt.registerLazySingleton<CustomerQrRepository>(
    () => CustomerQrRepositoryImpl(getIt<CustomerQrRemoteDataSource>()),
  );
  getIt.registerLazySingleton<GetCustomerPersonalQrUseCase>(
    () => GetCustomerPersonalQrUseCase(getIt<CustomerQrRepository>()),
  );
  getIt.registerLazySingleton<RevokeCustomerPersonalQrUseCase>(
    () => RevokeCustomerPersonalQrUseCase(getIt<CustomerQrRepository>()),
  );
  getIt.registerFactory<CustomerQrBloc>(
    () => CustomerQrBloc(
      getCustomerPersonalQrUseCase: getIt<GetCustomerPersonalQrUseCase>(),
      revokeCustomerPersonalQrUseCase: getIt<RevokeCustomerPersonalQrUseCase>(),
    ),
  );

  // Claim Rewards Feature
  getIt.registerLazySingleton<ClaimRewardsRemoteDataSource>(
    () => ClaimRewardsRemoteDataSourceImpl(getIt<SupabaseClient>()),
  );
  getIt.registerLazySingleton<ClaimRewardsRepository>(
    () => ClaimRewardsRepositoryImpl(getIt<ClaimRewardsRemoteDataSource>()),
  );
  getIt.registerLazySingleton<GetClaimRewardsContextUseCase>(
    () => GetClaimRewardsContextUseCase(getIt<ClaimRewardsRepository>()),
  );
  getIt.registerLazySingleton<CreateRewardClaimUseCase>(
    () => CreateRewardClaimUseCase(getIt<ClaimRewardsRepository>()),
  );
  getIt.registerLazySingleton<GetCustomerClaimStatusUseCase>(
    () => GetCustomerClaimStatusUseCase(getIt<ClaimRewardsRepository>()),
  );
  getIt.registerLazySingleton<CancelRewardClaimUseCase>(
    () => CancelRewardClaimUseCase(getIt<ClaimRewardsRepository>()),
  );
  getIt.registerFactory<ClaimRewardsBloc>(
    () => ClaimRewardsBloc(
      getClaimRewardsContextUseCase: getIt<GetClaimRewardsContextUseCase>(),
      createRewardClaimUseCase: getIt<CreateRewardClaimUseCase>(),
      getCustomerClaimStatusUseCase: getIt<GetCustomerClaimStatusUseCase>(),
      cancelRewardClaimUseCase: getIt<CancelRewardClaimUseCase>(),
    ),
  );

  // Activity & History Feature
  getIt.registerLazySingleton<StatementExporterService>(
    () => const StatementExporterService(),
  );
  getIt.registerLazySingleton<ActivityHistoryRemoteDataSource>(
    () => ActivityHistoryRemoteDataSourceImpl(getIt<SupabaseClient>()),
  );
  getIt.registerLazySingleton<ActivityHistoryRepository>(
    () => ActivityHistoryRepositoryImpl(
      remoteDataSource: getIt<ActivityHistoryRemoteDataSource>(),
      statementExporterService: getIt<StatementExporterService>(),
    ),
  );
  getIt.registerLazySingleton<GetActivityHistoryUseCase>(
    () => GetActivityHistoryUseCase(getIt<ActivityHistoryRepository>()),
  );
  getIt.registerLazySingleton<GetTransactionDetailUseCase>(
    () => GetTransactionDetailUseCase(getIt<ActivityHistoryRepository>()),
  );
  getIt.registerLazySingleton<GetMonthlyStatementUseCase>(
    () => GetMonthlyStatementUseCase(getIt<ActivityHistoryRepository>()),
  );
  getIt.registerLazySingleton<ExportMonthlyStatementUseCase>(
    () => ExportMonthlyStatementUseCase(getIt<ActivityHistoryRepository>()),
  );
  getIt.registerFactory<ActivityHistoryBloc>(
    () => ActivityHistoryBloc(
      getActivityHistoryUseCase: getIt<GetActivityHistoryUseCase>(),
      getTransactionDetailUseCase: getIt<GetTransactionDetailUseCase>(),
      exportMonthlyStatementUseCase: getIt<ExportMonthlyStatementUseCase>(),
    ),
  );

  // Promotional Advertisements Popup Feature
  getIt.registerLazySingleton<AdKeyValueStore>(
    () => SecureAdKeyValueStore(getIt<FlutterSecureStorage>()),
  );
  getIt.registerLazySingleton<AdvertisementLocalDataSource>(
    () => AdvertisementLocalDataSourceImpl(getIt<AdKeyValueStore>()),
  );
  getIt.registerLazySingleton<AdvertisementRemoteDataSource>(
    () => AdvertisementRemoteDataSourceImpl(getIt<SupabaseClient>()),
  );
  getIt.registerLazySingleton<AdvertisementRepository>(
    () => AdvertisementRepositoryImpl(
      remoteDataSource: getIt<AdvertisementRemoteDataSource>(),
      localDataSource: getIt<AdvertisementLocalDataSource>(),
    ),
  );
  getIt.registerLazySingleton<GetEligibleAdvertisementUseCase>(
    () => GetEligibleAdvertisementUseCase(getIt<AdvertisementRepository>()),
  );
  getIt.registerLazySingleton<TrackAdvertisementAnalyticsUseCase>(
    () => TrackAdvertisementAnalyticsUseCase(getIt<AdvertisementRepository>()),
  );
  getIt.registerLazySingleton<ClearAdvertisementSessionUseCase>(
    () => ClearAdvertisementSessionUseCase(getIt<AdvertisementRepository>()),
  );
  getIt.registerLazySingleton<AdvertisementBloc>(
    () => AdvertisementBloc(
      getEligibleAdvertisementUseCase: getIt<GetEligibleAdvertisementUseCase>(),
      trackAdvertisementAnalyticsUseCase:
          getIt<TrackAdvertisementAnalyticsUseCase>(),
      clearAdvertisementSessionUseCase:
          getIt<ClearAdvertisementSessionUseCase>(),
    ),
  );

  // Notifications Center Feature
  getIt.registerLazySingleton<NotificationKeyValueStore>(
    () => SecureNotificationKeyValueStore(getIt<FlutterSecureStorage>()),
  );
  getIt.registerLazySingleton<NotificationLocalDataSource>(
    () => NotificationLocalDataSourceImpl(getIt<NotificationKeyValueStore>()),
  );
  getIt.registerLazySingleton<NotificationRemoteDataSource>(
    () => NotificationRemoteDataSourceImpl(getIt<SupabaseClient>()),
  );
  getIt.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(
      remoteDataSource: getIt<NotificationRemoteDataSource>(),
      localDataSource: getIt<NotificationLocalDataSource>(),
    ),
  );
  getIt.registerLazySingleton<GetNotificationsUseCase>(
    () => GetNotificationsUseCase(getIt<NotificationRepository>()),
  );
  getIt.registerLazySingleton<MarkNotificationReadUseCase>(
    () => MarkNotificationReadUseCase(getIt<NotificationRepository>()),
  );
  getIt.registerLazySingleton<MarkAllNotificationsReadUseCase>(
    () => MarkAllNotificationsReadUseCase(getIt<NotificationRepository>()),
  );
  getIt.registerLazySingleton<GetUnreadNotificationCountUseCase>(
    () => GetUnreadNotificationCountUseCase(getIt<NotificationRepository>()),
  );
  getIt.registerLazySingleton<WatchNotificationsRealtimeUseCase>(
    () => WatchNotificationsRealtimeUseCase(getIt<NotificationRepository>()),
  );
  getIt.registerLazySingleton<NotificationBloc>(
    () => NotificationBloc(
      getNotificationsUseCase: getIt<GetNotificationsUseCase>(),
      markNotificationReadUseCase: getIt<MarkNotificationReadUseCase>(),
      markAllNotificationsReadUseCase:
          getIt<MarkAllNotificationsReadUseCase>(),
      getUnreadNotificationCountUseCase:
          getIt<GetUnreadNotificationCountUseCase>(),
      watchNotificationsRealtimeUseCase:
          getIt<WatchNotificationsRealtimeUseCase>(),
    ),
  );

  // Router
  getIt.registerLazySingleton<AppRouter>(
    () => AppRouter(authenticationBloc: getIt<AuthenticationBloc>()),
  );
}
