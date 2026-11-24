import 'dart:async';
import 'dart:io';

import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/core/extensions/string_extensions.dart';
import 'package:shiftex/core/services/secure_storage_service.dart';
import 'package:shiftex/features/account_approval/data/datasources/account_approval_remote_data_source.dart';
import 'package:shiftex/features/account_approval/data/models/customer_profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthenticationRemoteDataSource {
  Future<String> register({
    required String firstName,
    required String lastName,
    required String mobileNumber,
    required String email,
    required String password,
  });

  Future<CustomerProfileModel> verifyEmailOtp({
    required String email,
    required String otpCode,
    String? fullName,
    String? mobileNumber,
  });

  Future<void> resendEmailOtp({
    required String email,
  });

  Future<CustomerProfileModel> login({
    required String identifier,
    required String password,
    required bool rememberMe,
  });

  Future<void> sendPasswordResetOtp({
    required String email,
  });

  Future<void> verifyPasswordResetOtp({
    required String email,
    required String otpCode,
  });

  Future<void> resetPassword({
    required String newPassword,
  });

  Future<CustomerProfileModel?> getCurrentSessionProfile();

  Future<void> logout();

  Stream<String> get authSessionEvents;
}

class AuthenticationRemoteDataSourceImpl
    implements AuthenticationRemoteDataSource {
  final SupabaseClient _supabaseClient;
  final AccountApprovalRemoteDataSource _approvalRemoteDataSource;
  final SecureStorageService _secureStorageService;

  const AuthenticationRemoteDataSourceImpl({
    required SupabaseClient supabaseClient,
    required AccountApprovalRemoteDataSource approvalRemoteDataSource,
    required SecureStorageService secureStorageService,
  }) : _supabaseClient = supabaseClient,
       _approvalRemoteDataSource = approvalRemoteDataSource,
       _secureStorageService = secureStorageService;

  @override
  Future<String> register({
    required String firstName,
    required String lastName,
    required String mobileNumber,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedMobile = mobileNumber.normalizeMobile();
    final fullName = '${firstName.trim()} ${lastName.trim()}'.trim();

    final response = await _supabaseClient.auth.signUp(
      email: normalizedEmail,
      password: password,
      data: {
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'full_name': fullName,
        'mobile_number': normalizedMobile,
      },
    );

    final user = response.user;
    if (user == null) {
      throw const AppAuthException(
        'Registration could not be completed. Please try again.',
        code: 'server_failure',
      );
    }

    // When email confirmation is enabled in Supabase, duplicate email signups
    // return an obfuscated user object with an empty identities list.
    if (user.identities != null && user.identities!.isEmpty) {
      throw const AppAuthException(
        'An account with this email address already exists.',
        code: 'email_already_registered',
      );
    }

    await _secureStorageService.savePendingRegistrationContext(
      email: normalizedEmail,
      fullName: fullName,
      mobileNumber: normalizedMobile,
    );

    return normalizedEmail;
  }

  @override
  Future<CustomerProfileModel> verifyEmailOtp({
    required String email,
    required String otpCode,
    String? fullName,
    String? mobileNumber,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final cleanToken = otpCode.trim();

    AuthResponse response;
    try {
      response = await _supabaseClient.auth.verifyOTP(
        email: normalizedEmail,
        token: cleanToken,
        type: OtpType.signup,
      );
    } on AuthException {
      // Fallback to OtpType.email if token was issued as email verification OTP
      response = await _supabaseClient.auth.verifyOTP(
        email: normalizedEmail,
        token: cleanToken,
        type: OtpType.email,
      );
    }

    if (response.user == null && _supabaseClient.auth.currentUser == null) {
      throw const AppAuthException(
        'Email verification failed. Please request a new code.',
        code: 'invalid_otp',
      );
    }

    final pendingContext =
        await _secureStorageService.getPendingRegistrationContext();
    final resolvedFullName = fullName ?? pendingContext['fullName'];
    final resolvedMobile = mobileNumber ?? pendingContext['mobileNumber'];

    final profile = await _approvalRemoteDataSource.ensureCustomerProfile(
      fullName: resolvedFullName,
      mobileNumber: resolvedMobile,
    );

    await _secureStorageService.clearPendingRegistrationContext();
    return profile;
  }

  @override
  Future<void> resendEmailOtp({
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    await _supabaseClient.auth.resend(
      type: OtpType.signup,
      email: normalizedEmail,
    );
  }

  @override
  Future<CustomerProfileModel> login({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    if (_supabaseClient.auth.currentSession != null ||
        _supabaseClient.auth.currentUser != null) {
      await _clearLocalSessionBestEffort();
    }

    final rawIdentifier = identifier.trim();
    String targetEmail;

    if (rawIdentifier.looksLikeEmail) {
      targetEmail = rawIdentifier.toLowerCase();
    } else {
      final normalizedMobile = rawIdentifier.normalizeMobile();
      final resolved = await _supabaseClient.rpc(
        'resolve_mobile_login_email',
        params: {
          'p_mobile': normalizedMobile,
          'p_password': password,
        },
      );

      final resolvedEmail = (resolved as String?)?.trim().toLowerCase() ?? '';
      if (resolvedEmail.isEmpty) {
        throw const AppAuthException(
          'Invalid login credentials. Please check and try again.',
          code: 'invalid_credentials',
        );
      }
      targetEmail = resolvedEmail;
    }

    final authResponse = await _supabaseClient.auth.signInWithPassword(
      email: targetEmail,
      password: password,
    );

    final user = authResponse.user;
    final session = authResponse.session;
    if (user == null || session == null) {
      throw const AppAuthException(
        'Invalid login credentials. Please check and try again.',
        code: 'invalid_credentials',
      );
    }

    if (_supabaseClient.auth.currentUser?.id != user.id) {
      await _clearLocalSessionBestEffort();
      throw const AppAuthException(
        'Session switch could not be verified. Please sign in again.',
        code: 'session_expired',
      );
    }

    if (user.emailConfirmedAt == null) {
      throw AppAuthException(
        'Please verify your email address before signing in.',
        code: 'email_not_verified',
        email: targetEmail,
      );
    }

    await _secureStorageService.clearPendingRegistrationContext();
    await _secureStorageService.saveRememberMe(
      rememberMe: rememberMe,
      identifier: rawIdentifier,
    );

    final profile = await _approvalRemoteDataSource.fetchCurrentCustomerProfile();
    if (profile.id != user.id) {
      await _clearLocalSessionBestEffort();
      throw const AppAuthException(
        'Authenticated profile mismatch detected. Please sign in again.',
        code: 'session_expired',
      );
    }
    return profile;
  }

  @override
  Future<void> sendPasswordResetOtp({
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    await _supabaseClient.auth.resetPasswordForEmail(normalizedEmail);
  }

  @override
  Future<void> verifyPasswordResetOtp({
    required String email,
    required String otpCode,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final response = await _supabaseClient.auth.verifyOTP(
      email: normalizedEmail,
      token: otpCode.trim(),
      type: OtpType.recovery,
    );

    if (response.session == null &&
        _supabaseClient.auth.currentSession == null) {
      throw const AppAuthException(
        'The reset code could not be verified. Please try again.',
        code: 'invalid_otp',
      );
    }
  }

  @override
  Future<void> resetPassword({
    required String newPassword,
  }) async {
    final session = _supabaseClient.auth.currentSession;
    if (session == null) {
      throw const AppAuthException(
        'Your password recovery session has expired. Please request a new code.',
        code: 'session_expired',
      );
    }

    await _supabaseClient.auth.updateUser(
      UserAttributes(password: newPassword),
    );

    // Sign out after password update so user logs in freshly on /login
    await _clearLocalSessionBestEffort();
    await _secureStorageService.clearUserAuthDataOnLogout();
  }

  @override
  Future<CustomerProfileModel?> getCurrentSessionProfile() async {
    var session = _supabaseClient.auth.currentSession;
    if (session == null) {
      return null;
    }

    if (session.isExpired) {
      try {
        final refreshed = await _supabaseClient.auth.refreshSession();
        session = refreshed.session;
      } catch (_) {
        await _clearLocalSessionBestEffort();
        await _secureStorageService.clearUserAuthDataOnLogout();
        throw const AppAuthException(
          'Your session has expired. Please sign in again.',
          code: 'session_expired',
        );
      }
    }

    final user = _supabaseClient.auth.currentUser;
    if (user == null) {
      return null;
    }

    if (user.emailConfirmedAt == null) {
      throw AppAuthException(
        'Please verify your email address to continue.',
        code: 'email_not_verified',
        email: user.email ?? '',
      );
    }

    final profile = await _approvalRemoteDataSource.fetchCurrentCustomerProfile();
    if (profile.id != user.id) {
      await _clearLocalSessionBestEffort();
      await _secureStorageService.clearUserAuthDataOnLogout();
      throw const AppAuthException(
        'Your session could not be verified. Please sign in again.',
        code: 'session_expired',
      );
    }
    return profile;
  }

  @override
  Future<void> logout() async {
    try {
      await _supabaseClient.auth
          .signOut(scope: SignOutScope.local)
          .timeout(const Duration(seconds: 8));
    } catch (error) {
      await Future<void>.delayed(Duration.zero);

      final sessionCleared =
          _supabaseClient.auth.currentSession == null &&
          _supabaseClient.auth.currentUser == null;

      if (_isNetworkSignOutError(error) && sessionCleared) {
        await _secureStorageService.clearUserAuthDataOnLogout();
        return;
      }

      if (sessionCleared) {
        await _secureStorageService.clearUserAuthDataOnLogout();
      }
      rethrow;
    }

    // Allow SupabaseAuth's onAuthStateChange listener to flush persisted storage cleanup.
    await Future<void>.delayed(Duration.zero);

    if (_supabaseClient.auth.currentSession != null ||
        _supabaseClient.auth.currentUser != null) {
      await _clearLocalSessionBestEffort();
      if (_supabaseClient.auth.currentSession != null ||
          _supabaseClient.auth.currentUser != null) {
        throw const AppAuthException(
          'Unable to clear authentication session cleanly.',
          code: 'session_cleanup_failed',
        );
      }
    }

    await _secureStorageService.clearUserAuthDataOnLogout();
  }

  Future<void> _clearLocalSessionBestEffort() async {
    try {
      await _supabaseClient.auth
          .signOut(scope: SignOutScope.local)
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // GoTrue removes _currentSession synchronously before network revocation.
    }
    await Future<void>.delayed(Duration.zero);
  }

  bool _isNetworkSignOutError(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is AuthRetryableFetchException) {
      return true;
    }
    final raw = error.toString().toLowerCase();
    return raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection refused') ||
        raw.contains('connection reset') ||
        raw.contains('clientexception') ||
        raw.contains('timed out');
  }

  @override
  Stream<String> get authSessionEvents {
    return _supabaseClient.auth.onAuthStateChange.map(
      (authState) => authState.event.name,
    );
  }
}
