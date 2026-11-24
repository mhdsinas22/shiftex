import 'package:flutter/foundation.dart';
import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/core/services/secure_storage_service.dart';
import 'package:shiftex/core/utils/validators.dart';
import 'package:shiftex/features/change_email/domain/entities/change_email_result_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote contract backed by Supabase Auth for updating and confirming the
/// authenticated customer's email address on their existing user UUID.
abstract class ChangeEmailRemoteDataSource {
  Future<ChangeEmailResultEntity> requestEmailChange({
    required String currentPassword,
    required String newEmail,
  });

  Future<ChangeEmailResultEntity> verifyEmailChangeOtp({
    required String newEmail,
    required String otpCode,
    String? currentEmail,
    bool verifyCurrentEmail = false,
    bool newEmailAlreadyVerified = false,
    bool currentEmailAlreadyVerified = false,
  });

  Future<void> resendEmailChangeVerification({
    required String newEmail,
  });

  Future<ChangeEmailResultEntity> checkEmailChangeStatus({
    required String targetEmail,
  });
}

/// Supabase Auth implementation of [ChangeEmailRemoteDataSource].
///
/// Always updates the existing user in-place via `supabase.auth.updateUser`
/// and verifies that the authenticated user's UUID never changes.
class ChangeEmailRemoteDataSourceImpl implements ChangeEmailRemoteDataSource {
  final SupabaseClient _supabaseClient;
  final SecureStorageService? _secureStorageService;

  const ChangeEmailRemoteDataSourceImpl(
    this._supabaseClient, {
    SecureStorageService? secureStorageService,
  }) : _secureStorageService = secureStorageService;

  void _logDebug(String step, Map<String, Object?> details) {
    if (!kDebugMode) return;
    final formatted = details.entries
        .map((e) => '${e.key}=${e.value}')
        .join(', ');
    debugPrint('[ChangeEmailRemoteDataSource] $step | $formatted');
  }

  String _maskEmail(String email) {
    final trimmed = email.trim();
    final atIndex = trimmed.indexOf('@');
    if (atIndex <= 1) return trimmed.isEmpty ? '<empty>' : '***';
    final local = trimmed.substring(0, atIndex);
    final domain = trimmed.substring(atIndex);
    return '${local[0]}***${local[local.length - 1]}$domain';
  }

  @override
  Future<ChangeEmailResultEntity> requestEmailChange({
    required String currentPassword,
    required String newEmail,
  }) async {
    final session = _supabaseClient.auth.currentSession;
    final user = _supabaseClient.auth.currentUser;

    if (session == null || user == null) {
      _logDebug('requestEmailChange.noSession', {
        'hasSession': session != null,
        'hasUser': user != null,
      });
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }

    final originalUserId = user.id;
    final previousSentAt = user.emailChangeSentAt;

    if (session.isExpired) {
      _logDebug('requestEmailChange.refreshingExpiredSession', {
        'userId': originalUserId,
      });
      await _refreshActiveSession(expectedUserId: originalUserId);
    }

    final currentEmail = (user.email ?? '').trim().toLowerCase();
    if (currentEmail.isEmpty) {
      throw const AppAuthException(
        'Unable to verify your current account email.',
        code: 'validation_failure',
      );
    }

    final normalizedNewEmail = newEmail.trim().toLowerCase();
    final emailValidationError = Validators.validateNewEmail(
      normalizedNewEmail,
      currentEmail: currentEmail,
    );
    if (emailValidationError != null) {
      throw AppAuthException(
        emailValidationError,
        code: 'validation_failure',
      );
    }

    if (currentPassword.isEmpty) {
      throw const AppAuthException(
        'Current password is required to change your email.',
        code: 'validation_failure',
      );
    }

    _logDebug('requestEmailChange.start', {
      'userId': originalUserId,
      'currentEmail': _maskEmail(currentEmail),
      'targetEmail': _maskEmail(normalizedNewEmail),
      'previousSentAt': previousSentAt ?? 'none',
    });

    await _verifyCurrentPassword(
      email: currentEmail,
      currentPassword: currentPassword,
      expectedUserId: originalUserId,
    );

    final updatedUser = await _updateAuthUserEmail(
      newEmail: normalizedNewEmail,
      expectedUserId: originalUserId,
    );

    final activeAuthEmail = (updatedUser.email ?? '').trim().toLowerCase();
    final pendingAuthEmail = (updatedUser.newEmail ?? '').trim().toLowerCase();
    final updatedSentAt = updatedUser.emailChangeSentAt;

    _logDebug('requestEmailChange.updateUserResponse', {
      'userId': updatedUser.id,
      'activeEmail': _maskEmail(activeAuthEmail),
      'pendingNewEmail': _maskEmail(pendingAuthEmail),
      'emailChangeSentAt': updatedSentAt ?? 'none',
    });

    // 1. Immediate update (when Confirm Email is disabled in Supabase Auth)
    if (activeAuthEmail == normalizedNewEmail && pendingAuthEmail.isEmpty) {
      await _syncProfileAndRememberedEmail(
        userId: originalUserId,
        confirmedEmail: normalizedNewEmail,
      );
      return ChangeEmailResultEntity(
        userId: originalUserId,
        currentEmail: normalizedNewEmail,
        targetEmail: normalizedNewEmail,
        status: ChangeEmailStatus.completed,
        emailChangeSentAt: updatedSentAt,
        newEmailVerified: true,
        currentEmailVerified: true,
        message:
            'Your registered email address has been updated to $normalizedNewEmail.',
      );
    }

    // 2. Verify that Supabase actually accepted the pending email change
    if (pendingAuthEmail != normalizedNewEmail &&
        activeAuthEmail != normalizedNewEmail) {
      _logDebug('requestEmailChange.notAccepted', {
        'userId': originalUserId,
        'activeEmail': _maskEmail(activeAuthEmail),
        'pendingNewEmail': _maskEmail(pendingAuthEmail),
        'expectedNewEmail': _maskEmail(normalizedNewEmail),
      });
      throw const AppAuthException(
        'Supabase did not accept the email change request. Please verify the email address and try again.',
        code: 'email_change_not_accepted',
      );
    }

    final isWithinRateLimitWindow =
        previousSentAt != null &&
        previousSentAt.isNotEmpty &&
        updatedSentAt == previousSentAt;

    if (isWithinRateLimitWindow) {
      _logDebug('requestEmailChange.reusingRecentTokenWithinCooldown', {
        'userId': originalUserId,
        'emailChangeSentAt': updatedSentAt,
      });
    }

    return ChangeEmailResultEntity(
      userId: originalUserId,
      currentEmail: currentEmail,
      targetEmail: normalizedNewEmail,
      status: ChangeEmailStatus.pendingVerification,
      emailChangeSentAt: updatedSentAt,
      message:
          'Verification code sent to $normalizedNewEmail. If Secure Email Change is enabled, a confirmation code is also sent to $currentEmail. Enter the 6-digit code below to confirm.',
    );
  }

  @override
  Future<ChangeEmailResultEntity> verifyEmailChangeOtp({
    required String newEmail,
    required String otpCode,
    String? currentEmail,
    bool verifyCurrentEmail = false,
    bool newEmailAlreadyVerified = false,
    bool currentEmailAlreadyVerified = false,
  }) async {
    final session = _supabaseClient.auth.currentSession;
    final user = _supabaseClient.auth.currentUser;

    if (session == null || user == null) {
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }

    final originalUserId = user.id;
    final resolvedCurrentEmail =
        (currentEmail ?? user.email ?? '').trim().toLowerCase();
    final normalizedNewEmail = newEmail.trim().toLowerCase();
    final cleanOtp = otpCode.trim();

    if (Validators.validateEmail(normalizedNewEmail) != null) {
      throw const AppAuthException(
        'Enter a valid email address.',
        code: 'validation_failure',
      );
    }

    if (Validators.validateOtp(cleanOtp) != null) {
      throw const AppAuthException(
        'Please enter the 6-digit verification code.',
        code: 'invalid_otp',
      );
    }

    final shouldPreferCurrentEmail =
        (verifyCurrentEmail ||
            (newEmailAlreadyVerified && !currentEmailAlreadyVerified)) &&
        resolvedCurrentEmail.isNotEmpty &&
        resolvedCurrentEmail != normalizedNewEmail;

    final primaryEmail =
        shouldPreferCurrentEmail ? resolvedCurrentEmail : normalizedNewEmail;
    final secondaryEmail =
        shouldPreferCurrentEmail ? normalizedNewEmail : resolvedCurrentEmail;

    _logDebug('verifyEmailChangeOtp.start', {
      'userId': originalUserId,
      'primaryEmail': _maskEmail(primaryEmail),
      'secondaryEmail': _maskEmail(secondaryEmail),
      'verifyCurrentEmail': shouldPreferCurrentEmail,
      'newEmailAlreadyVerified': newEmailAlreadyVerified,
      'currentEmailAlreadyVerified': currentEmailAlreadyVerified,
    });

    AuthResponse? response;
    String matchedEmail = primaryEmail;

    try {
      response = await _supabaseClient.auth.verifyOTP(
        email: primaryEmail,
        token: cleanOtp,
        type: OtpType.emailChange,
      );
      _logDebug('verifyEmailChangeOtp.primarySuccess', {
        'userId': originalUserId,
        'matchedEmail': _maskEmail(primaryEmail),
        'hasResponseUser': response.user != null,
      });
    } on AuthException catch (primaryError) {
      _logDebug('verifyEmailChangeOtp.primaryFailed', {
        'userId': originalUserId,
        'primaryEmail': _maskEmail(primaryEmail),
        'code': primaryError.code,
        'statusCode': primaryError.statusCode,
        'message': primaryError.message,
      });

      final canTrySecondary =
          secondaryEmail.isNotEmpty &&
          secondaryEmail != primaryEmail &&
          _shouldAttemptSecondaryEmailOnOtpError(primaryError);

      if (!canTrySecondary) {
        _rethrowMappedOtpException(primaryError);
      }

      try {
        _logDebug('verifyEmailChangeOtp.attemptingSecondaryEmail', {
          'userId': originalUserId,
          'secondaryEmail': _maskEmail(secondaryEmail),
        });
        response = await _supabaseClient.auth.verifyOTP(
          email: secondaryEmail,
          token: cleanOtp,
          type: OtpType.emailChange,
        );
        matchedEmail = secondaryEmail;
        _logDebug('verifyEmailChangeOtp.secondarySuccess', {
          'userId': originalUserId,
          'matchedEmail': _maskEmail(secondaryEmail),
          'hasResponseUser': response.user != null,
        });
      } on AuthException catch (secondaryError) {
        _logDebug('verifyEmailChangeOtp.secondaryFailed', {
          'userId': originalUserId,
          'secondaryEmail': _maskEmail(secondaryEmail),
          'code': secondaryError.code,
          'statusCode': secondaryError.statusCode,
          'message': secondaryError.message,
        });
        _rethrowMappedOtpException(primaryError);
      }
    }

    final verifiedUser = await _fetchAuthoritativeUser(
      fallbackUser: response.user ?? _supabaseClient.auth.currentUser,
      expectedTargetEmail: normalizedNewEmail,
    );

    if (verifiedUser == null || verifiedUser.id != originalUserId) {
      _logDebug('verifyEmailChangeOtp.identityMismatch', {
        'expectedUserId': originalUserId,
        'actualUserId': verifiedUser?.id,
      });
      throw const AppAuthException(
        'Account identity verification failed. Your existing account was not modified.',
        code: 'session_expired',
      );
    }

    final latestEmail = (verifiedUser.email ?? '').trim().toLowerCase();
    final latestPendingEmail =
        (verifiedUser.newEmail ?? '').trim().toLowerCase();

    _logDebug('verifyEmailChangeOtp.postVerifyUserState', {
      'userId': verifiedUser.id,
      'latestEmail': _maskEmail(latestEmail),
      'latestPendingEmail': _maskEmail(latestPendingEmail),
      'matchedEmail': _maskEmail(matchedEmail),
    });

    if (latestEmail == normalizedNewEmail) {
      await _syncProfileAndRememberedEmail(
        userId: originalUserId,
        confirmedEmail: normalizedNewEmail,
      );
      return ChangeEmailResultEntity(
        userId: originalUserId,
        currentEmail: normalizedNewEmail,
        targetEmail: normalizedNewEmail,
        status: ChangeEmailStatus.completed,
        newEmailVerified: true,
        currentEmailVerified: true,
        message:
            'Your email address has been verified and updated to $normalizedNewEmail.',
      );
    }

    final nextNewVerified =
        newEmailAlreadyVerified || (matchedEmail == normalizedNewEmail);
    final nextCurrentVerified =
        currentEmailAlreadyVerified || (matchedEmail == resolvedCurrentEmail);

    final remainingEmail =
        nextNewVerified ? resolvedCurrentEmail : normalizedNewEmail;
    final remainingLabel =
        nextNewVerified ? 'current email' : 'new email';

    return ChangeEmailResultEntity(
      userId: originalUserId,
      currentEmail: resolvedCurrentEmail,
      targetEmail: normalizedNewEmail,
      status: ChangeEmailStatus.pendingVerification,
      emailChangeSentAt: verifiedUser.emailChangeSentAt,
      newEmailVerified: nextNewVerified,
      currentEmailVerified: nextCurrentVerified,
      requiresCurrentEmailVerification: true,
      message:
          'Step 1 of 2 verified ($matchedEmail)! Secure Email Change is enabled — please enter the 6-digit verification code sent to your $remainingLabel ($remainingEmail) to complete the update.',
    );
  }

  bool _shouldAttemptSecondaryEmailOnOtpError(AuthException error) {
    final code = (error.code ?? '').toLowerCase();
    final msg = error.message.toLowerCase();
    return code == 'otp_expired' ||
        code == 'invalid_otp' ||
        msg.contains('one-time token not found') ||
        msg.contains('token has expired') ||
        msg.contains('token is invalid');
  }

  @override
  Future<void> resendEmailChangeVerification({
    required String newEmail,
  }) async {
    final session = _supabaseClient.auth.currentSession;
    final user = _supabaseClient.auth.currentUser;
    if (session == null || user == null) {
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }

    final originalUserId = user.id;
    final normalizedNewEmail = newEmail.trim().toLowerCase();
    if (Validators.validateEmail(normalizedNewEmail) != null) {
      throw const AppAuthException(
        'Enter a valid email address.',
        code: 'validation_failure',
      );
    }

    _logDebug('resendEmailChangeVerification.start', {
      'userId': originalUserId,
      'targetEmail': _maskEmail(normalizedNewEmail),
    });

    try {
      await _supabaseClient.auth.resend(
        email: normalizedNewEmail,
        type: OtpType.emailChange,
      );
      _logDebug('resendEmailChangeVerification.resendCompleted', {
        'userId': originalUserId,
        'targetEmail': _maskEmail(normalizedNewEmail),
      });
    } on AuthException catch (error) {
      _logDebug('resendEmailChangeVerification.resendAuthException', {
        'userId': originalUserId,
        'code': error.code,
        'statusCode': error.statusCode,
        'message': error.message,
      });
      rethrow;
    }

    // Workaround for GoTrue issue #1283 where POST /resend with type=email_change
    // can return 200 OK without re-dispatching SMTP when double confirm is active:
    // if the user already has a pending newEmail on their session, re-trigger
    // updateUser(UserAttributes(email: normalizedNewEmail)) to ensure fresh
    // one_time_tokens and SMTP delivery.
    final pendingOnUser = (user.newEmail ?? '').trim().toLowerCase();
    if (pendingOnUser == normalizedNewEmail) {
      try {
        final updateResponse = await _supabaseClient.auth.updateUser(
          UserAttributes(email: normalizedNewEmail),
        );
        final updatedUser = updateResponse.user;
        if (updatedUser != null && updatedUser.id != originalUserId) {
          throw const AppAuthException(
            'Account UUID mismatch detected. Email update aborted to protect your data.',
            code: 'session_expired',
          );
        }
        _logDebug('resendEmailChangeVerification.updateUserRedispatched', {
          'userId': originalUserId,
          'emailChangeSentAt': updatedUser?.emailChangeSentAt ?? 'none',
        });
      } on AuthException catch (error) {
        _logDebug('resendEmailChangeVerification.updateUserAuthException', {
          'userId': originalUserId,
          'code': error.code,
          'statusCode': error.statusCode,
          'message': error.message,
        });
        rethrow;
      }
    }
  }

  @override
  Future<ChangeEmailResultEntity> checkEmailChangeStatus({
    required String targetEmail,
  }) async {
    final session = _supabaseClient.auth.currentSession;
    final user = _supabaseClient.auth.currentUser;

    if (session == null || user == null) {
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }

    final originalUserId = user.id;
    final normalizedTarget = targetEmail.trim().toLowerCase();

    _logDebug('checkEmailChangeStatus.start', {
      'userId': originalUserId,
      'targetEmail': _maskEmail(normalizedTarget),
    });

    final latestUser = await _fetchAuthoritativeUser(
      fallbackUser: user,
      expectedTargetEmail: normalizedTarget,
      preferRefreshSession: true,
    );

    if (latestUser == null || latestUser.id != originalUserId) {
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }

    final activeEmail = (latestUser.email ?? '').trim().toLowerCase();
    final pendingEmail = (latestUser.newEmail ?? '').trim().toLowerCase();

    _logDebug('checkEmailChangeStatus.result', {
      'userId': latestUser.id,
      'activeEmail': _maskEmail(activeEmail),
      'pendingEmail': _maskEmail(pendingEmail),
    });

    if (activeEmail == normalizedTarget) {
      await _syncProfileAndRememberedEmail(
        userId: originalUserId,
        confirmedEmail: normalizedTarget,
      );
      return ChangeEmailResultEntity(
        userId: originalUserId,
        currentEmail: normalizedTarget,
        targetEmail: normalizedTarget,
        status: ChangeEmailStatus.completed,
        newEmailVerified: true,
        currentEmailVerified: true,
        message:
            'Your email address has been confirmed and updated to $normalizedTarget.',
      );
    }

    return ChangeEmailResultEntity(
      userId: originalUserId,
      currentEmail: activeEmail,
      targetEmail: normalizedTarget,
      status: ChangeEmailStatus.pendingVerification,
      emailChangeSentAt: latestUser.emailChangeSentAt,
      message:
          'Confirmation for $normalizedTarget is still pending. Please enter the 6-digit verification code from your email (and confirm both old and new emails if Secure Email Change is enabled).',
    );
  }

  Future<User?> _fetchAuthoritativeUser({
    required User? fallbackUser,
    required String expectedTargetEmail,
    bool preferRefreshSession = false,
  }) async {
    User? latestUser = fallbackUser;

    if (preferRefreshSession) {
      try {
        final refreshed = await _supabaseClient.auth.refreshSession();
        if (refreshed.user != null) {
          latestUser = refreshed.user;
        }
      } catch (error) {
        _logDebug('fetchAuthoritativeUser.refreshSessionError', {
          'errorType': error.runtimeType.toString(),
        });
      }
    }

    if (latestUser == null ||
        (latestUser.email ?? '').trim().toLowerCase() != expectedTargetEmail) {
      try {
        final fetched = await _supabaseClient.auth.getUser();
        if (fetched.user != null) {
          latestUser = fetched.user;
        }
      } catch (error) {
        _logDebug('fetchAuthoritativeUser.getUserError', {
          'errorType': error.runtimeType.toString(),
        });
      }
    }

    return latestUser ?? _supabaseClient.auth.currentUser;
  }

  Future<void> _refreshActiveSession({required String expectedUserId}) async {
    try {
      final refreshed = await _supabaseClient.auth.refreshSession();
      if (refreshed.session == null ||
          refreshed.user == null ||
          refreshed.user!.id != expectedUserId) {
        throw const AppAuthException(
          'Your session has expired. Please sign in again.',
          code: 'session_expired',
        );
      }
    } on AppAuthException {
      rethrow;
    } on AuthException catch (error) {
      _logDebug('refreshActiveSession.failed', {
        'code': error.code,
        'statusCode': error.statusCode,
      });
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }
  }

  Future<void> _verifyCurrentPassword({
    required String email,
    required String currentPassword,
    required String expectedUserId,
  }) async {
    try {
      final response = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      if (response.user == null || response.session == null) {
        throw const AppAuthException(
          'Current password is incorrect. Please check and try again.',
          code: 'invalid_credentials',
        );
      }
      if (response.user!.id != expectedUserId) {
        throw const AppAuthException(
          'Session identity mismatch detected. Please sign in again.',
          code: 'session_expired',
        );
      }
      _logDebug('verifyCurrentPassword.success', {
        'userId': expectedUserId,
      });
    } on AuthException catch (error) {
      _logDebug('verifyCurrentPassword.authException', {
        'userId': expectedUserId,
        'code': error.code,
        'statusCode': error.statusCode,
        'message': error.message,
      });
      final code = (error.code ?? '').toLowerCase();
      final msg = error.message.toLowerCase();
      if (code == 'invalid_credentials' ||
          msg.contains('invalid login credentials') ||
          msg.contains('invalid email or password')) {
        throw const AppAuthException(
          'Current password is incorrect. Please check and try again.',
          code: 'invalid_credentials',
        );
      }
      rethrow;
    }
  }

  Future<User> _updateAuthUserEmail({
    required String newEmail,
    required String expectedUserId,
  }) async {
    try {
      final response = await _supabaseClient.auth.updateUser(
        UserAttributes(
          email: newEmail,
        ),
      );
      final updatedUser = response.user;
      if (updatedUser == null) {
        _logDebug('updateAuthUserEmail.nullUser', {
          'expectedUserId': expectedUserId,
        });
        throw const AppAuthException(
          'Unable to initiate email update right now. Please try again.',
          code: 'server_failure',
        );
      }
      if (updatedUser.id != expectedUserId) {
        _logDebug('updateAuthUserEmail.uuidMismatch', {
          'expectedUserId': expectedUserId,
          'actualUserId': updatedUser.id,
        });
        throw const AppAuthException(
          'Account UUID mismatch detected. Email update aborted to protect your data.',
          code: 'session_expired',
        );
      }
      return updatedUser;
    } on AuthException catch (error) {
      _logDebug('updateAuthUserEmail.authException', {
        'expectedUserId': expectedUserId,
        'code': error.code,
        'statusCode': error.statusCode,
        'message': error.message,
      });
      final code = (error.code ?? '').toLowerCase();
      final msg = error.message.toLowerCase();
      if (code == 'email_exists' ||
          code == 'user_already_exists' ||
          msg.contains('already been registered') ||
          msg.contains('user already registered') ||
          msg.contains('email address is already')) {
        throw const AppAuthException(
          'An account with this email address already exists.',
          code: 'email_already_registered',
        );
      }
      if (code == 'same_email' ||
          msg.contains('new email should be different')) {
        throw const AppAuthException(
          'New email must be different from your current email.',
          code: 'validation_failure',
        );
      }
      if (code == 'email_address_invalid' ||
          msg.contains('unable to validate email address') ||
          msg.contains('invalid email')) {
        throw const AppAuthException(
          'Enter a valid email address.',
          code: 'validation_failure',
        );
      }
      rethrow;
    }
  }

  Never _rethrowMappedOtpException(AuthException error) {
    final code = (error.code ?? '').toLowerCase();
    final msg = error.message.toLowerCase();
    if (code == 'otp_expired' ||
        msg.contains('one-time token not found') ||
        msg.contains('token has expired') ||
        msg.contains('otp has expired') ||
        msg.contains('expired')) {
      throw const AppAuthException(
        'This verification code has expired or was not found. Please check both your new and current email inboxes or request a new 6-digit code.',
        code: 'expired_otp',
      );
    }
    if (code == 'otp_disabled' ||
        msg.contains('token is invalid') ||
        msg.contains('invalid otp') ||
        msg.contains('incorrect otp')) {
      throw const AppAuthException(
        'The verification code entered is invalid. Please try again.',
        code: 'invalid_otp',
      );
    }
    throw error;
  }

  Future<void> _syncProfileAndRememberedEmail({
    required String userId,
    required String confirmedEmail,
  }) async {
    try {
      await _supabaseClient.rpc('sync_customer_profile_email');
      _logDebug('syncProfileAndRememberedEmail.rpcSuccess', {
        'userId': userId,
        'confirmedEmail': _maskEmail(confirmedEmail),
      });
    } catch (rpcError) {
      _logDebug('syncProfileAndRememberedEmail.rpcFallback', {
        'userId': userId,
        'errorType': rpcError.runtimeType.toString(),
      });
      try {
        await _supabaseClient
            .from('profiles')
            .update({'email': confirmedEmail})
            .eq('id', userId);
        _logDebug('syncProfileAndRememberedEmail.directUpdateSuccess', {
          'userId': userId,
        });
      } catch (updateError) {
        _logDebug('syncProfileAndRememberedEmail.directUpdateError', {
          'userId': userId,
          'errorType': updateError.runtimeType.toString(),
        });
      }
    }

    final storage = _secureStorageService;
    if (storage != null) {
      final rememberMe = await storage.getRememberMe();
      final rememberedIdentifier = await storage.getRememberedIdentifier();
      if (rememberMe &&
          rememberedIdentifier != null &&
          rememberedIdentifier.contains('@')) {
        await storage.saveRememberMe(
          rememberMe: true,
          identifier: confirmedEmail,
        );
      }
    }
  }
}
