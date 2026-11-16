import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message =
        'Unable to connect to the server. Please check your internet connection.',
  ]) : super(code: 'network_failure');
}

class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure([
    super.message = 'Invalid login credentials. Please check and try again.',
  ]) : super(code: 'invalid_credentials');
}

class EmailAlreadyRegisteredFailure extends Failure {
  const EmailAlreadyRegisteredFailure([
    super.message = 'An account with this email address already exists.',
  ]) : super(code: 'email_already_registered');
}

class MobileAlreadyRegisteredFailure extends Failure {
  const MobileAlreadyRegisteredFailure([
    super.message = 'An account with this mobile number already exists.',
  ]) : super(code: 'mobile_already_registered');
}

class InvalidOtpFailure extends Failure {
  const InvalidOtpFailure([
    super.message =
        'The verification code entered is invalid. Please try again.',
  ]) : super(code: 'invalid_otp');
}

class ExpiredOtpFailure extends Failure {
  const ExpiredOtpFailure([
    super.message =
        'This verification code has expired. Please request a new code.',
  ]) : super(code: 'expired_otp');
}

class RateLimitFailure extends Failure {
  const RateLimitFailure([
    super.message =
        'Too many attempts. Please wait a moment before requesting again.',
  ]) : super(code: 'rate_limit_exceeded');
}

class EmailNotVerifiedFailure extends Failure {
  final String email;

  const EmailNotVerifiedFailure({
    required this.email,
    String message = 'Please verify your email address before signing in.',
  }) : super(message, code: 'email_not_verified');

  @override
  List<Object?> get props => [message, code, email];
}

class PendingApprovalFailure extends Failure {
  const PendingApprovalFailure([
    super.message = 'Your account is currently awaiting administrator review.',
  ]) : super(code: 'pending_approval');
}

class AccountRejectedFailure extends Failure {
  final String? reason;

  const AccountRejectedFailure({
    this.reason,
    String message = 'Your account application was not approved.',
  }) : super(message, code: 'account_rejected');

  @override
  List<Object?> get props => [message, code, reason];
}

class AccountSuspendedFailure extends Failure {
  const AccountSuspendedFailure([
    super.message =
        'Your account has been suspended. Please contact Shiiftex Support.',
  ]) : super(code: 'account_suspended');
}

class SessionExpiredFailure extends Failure {
  const SessionExpiredFailure([
    super.message = 'Your session has expired. Please sign in again.',
  ]) : super(code: 'session_expired');
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message) : super(code: 'validation_failure');
}

class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'Something went wrong on our end. Please try again shortly.',
  ]) : super(code: 'server_failure');
}
