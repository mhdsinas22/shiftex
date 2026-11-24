import 'dart:async';
import 'dart:io';

import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorMapper {
  const ErrorMapper._();

  static Failure mapExceptionToFailure(
    Object error, {
    String? fallbackEmail,
  }) {
    if (error is Failure) {
      return error;
    }

    if (error is SocketException || error is TimeoutException) {
      return const NetworkFailure();
    }

    if (error is AppAuthException) {
      switch (error.code) {
        case 'network_failure':
          return NetworkFailure(error.message);
        case 'invalid_credentials':
          return InvalidCredentialsFailure(error.message);
        case 'email_already_registered':
          return EmailAlreadyRegisteredFailure(error.message);
        case 'mobile_already_registered':
          return MobileAlreadyRegisteredFailure(error.message);
        case 'invalid_otp':
          return InvalidOtpFailure(error.message);
        case 'expired_otp':
          return ExpiredOtpFailure(error.message);
        case 'rate_limit_exceeded':
          return RateLimitFailure(error.message);
        case 'email_not_verified':
          return EmailNotVerifiedFailure(
            email: error.email ?? fallbackEmail ?? '',
            message: error.message,
          );
        case 'pending_approval':
          return PendingApprovalFailure(error.message);
        case 'account_rejected':
          return AccountRejectedFailure(
            reason: error.reason,
            message: error.message,
          );
        case 'account_suspended':
          return AccountSuspendedFailure(error.message);
        case 'session_expired':
          return SessionExpiredFailure(error.message);
        case 'validation_failure':
          return ValidationFailure(error.message);
        default:
          return ServerFailure(error.message);
      }
    }

    if (error is AuthException) {
      return _mapSupabaseAuthException(error, fallbackEmail: fallbackEmail);
    }

    if (error is PostgrestException) {
      return _mapPostgrestException(error);
    }

    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection refused')) {
      return const NetworkFailure();
    }

    return const ServerFailure();
  }

  static Failure _mapSupabaseAuthException(
    AuthException error, {
    String? fallbackEmail,
  }) {
    final msg = error.message.toLowerCase();
    final code = (error.code ?? '').toLowerCase();

    if (msg.contains('mobile_already_registered') ||
        code.contains('mobile_already_registered')) {
      return const MobileAlreadyRegisteredFailure();
    }

    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        msg.contains('user already registered') ||
        msg.contains('already been registered')) {
      return const EmailAlreadyRegisteredFailure();
    }

    if (code == 'email_not_confirmed' ||
        msg.contains('email not confirmed')) {
      return EmailNotVerifiedFailure(email: fallbackEmail ?? '');
    }

    if (code == 'invalid_credentials' ||
        msg.contains('invalid login credentials') ||
        msg.contains('invalid email or password')) {
      return const InvalidCredentialsFailure();
    }

    if (code == 'otp_expired' ||
        msg.contains('token has expired') ||
        msg.contains('otp has expired') ||
        msg.contains('expired')) {
      if (msg.contains('invalid') && !msg.contains('expired')) {
        return const InvalidOtpFailure();
      }
      if (code == 'otp_expired' || msg.contains('token has expired')) {
        return const InvalidOtpFailure(
          'The verification code is invalid or has expired. Please check or request a new code.',
        );
      }
      return const ExpiredOtpFailure();
    }

    if (code == 'otp_disabled' ||
        msg.contains('token is invalid') ||
        msg.contains('invalid otp') ||
        msg.contains('incorrect otp')) {
      return const InvalidOtpFailure();
    }

    if (code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        error.statusCode == '429' ||
        msg.contains('rate limit') ||
        msg.contains('for security purposes, you can only request this')) {
      return const RateLimitFailure();
    }

    if (code == 'session_not_found' ||
        code == 'refresh_token_not_found' ||
        msg.contains('jwt expired') ||
        msg.contains('session expired')) {
      return const SessionExpiredFailure();
    }

    if (code == 'weak_password' ||
        code == 'same_password' ||
        msg.contains('new password should be different')) {
      if (code == 'same_password' ||
          msg.contains('new password should be different')) {
        return const ValidationFailure(
          'Your new password must be different from your current password.',
        );
      }
      return const ValidationFailure(
        'Password must be at least 8 characters and include uppercase, lowercase, number, and special character.',
      );
    }

    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('clientexception')) {
      return const NetworkFailure();
    }

    return const ServerFailure(
      'Unable to complete the authentication request. Please try again.',
    );
  }

  static Failure _mapPostgrestException(PostgrestException error) {
    final msg = error.message.toLowerCase();
    final details = (error.details ?? '').toString().toLowerCase();

    if (msg.contains('mobile_already_registered') ||
        msg.contains('profiles_mobile_number_key') ||
        details.contains('mobile_number')) {
      return const MobileAlreadyRegisteredFailure();
    }

    if (msg.contains('profiles_email_key') || details.contains('email')) {
      return const EmailAlreadyRegisteredFailure();
    }

    if (error.code == 'PGRST301' || msg.contains('jwt expired')) {
      return const SessionExpiredFailure();
    }

    if (error.code == 'PGRST202' ||
        error.code == '42P01' ||
        error.code == '42883') {
      return const ServerFailure(
        'Backend service configuration is missing or not updated yet. Please apply the latest database migration and try again.',
      );
    }

    if (msg.contains('unauthenticated')) {
      return const SessionExpiredFailure();
    }

    return const ServerFailure(
      'Unable to process your request right now. Please try again.',
    );
  }
}
