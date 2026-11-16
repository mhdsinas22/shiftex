import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shiftex/core/config/supabase_config.dart';
import 'package:shiftex/core/network/network_info.dart';
import 'package:shiftex/core/router/app_router.dart';
import 'package:shiftex/core/services/secure_storage_service.dart';
import 'package:shiftex/features/account_approval/data/datasources/account_approval_remote_data_source.dart';
import 'package:shiftex/features/account_approval/data/repositories/account_approval_repository_impl.dart';
import 'package:shiftex/features/account_approval/domain/repositories/account_approval_repository.dart';
import 'package:shiftex/features/account_approval/domain/usecases/ensure_customer_profile_usecase.dart';
import 'package:shiftex/features/account_approval/domain/usecases/get_approval_status_usecase.dart';
import 'package:shiftex/features/account_approval/presentation/bloc/account_approval_bloc.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart';

final GetIt getIt = GetIt.instance;

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

  // Repositories
  getIt.registerLazySingleton<AccountApprovalRepository>(
    () =>
        AccountApprovalRepositoryImpl(getIt<AccountApprovalRemoteDataSource>()),
  );
  getIt.registerLazySingleton<AuthenticationRepository>(
    () => AuthenticationRepositoryImpl(getIt<AuthenticationRemoteDataSource>()),
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

  // Router
  getIt.registerLazySingleton<AppRouter>(
    () => AppRouter(authenticationBloc: getIt<AuthenticationBloc>()),
  );
}
