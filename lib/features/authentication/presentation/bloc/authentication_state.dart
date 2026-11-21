import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';

abstract class AuthenticationState extends Equatable {
  const AuthenticationState();

  @override
  List<Object?> get props => [];
}

class AuthenticationInitial extends AuthenticationState {
  const AuthenticationInitial();
}

class AuthenticationLoading extends AuthenticationState {
  final String? activeEmail;
  final CustomerProfileEntity? currentProfile;

  const AuthenticationLoading({this.activeEmail, this.currentProfile});

  @override
  List<Object?> get props => [activeEmail, currentProfile];
}

class Unauthenticated extends AuthenticationState {
  const Unauthenticated();
}

class RegistrationSuccess extends AuthenticationState {
  final String email;
  final String fullName;
  final String mobileNumber;

  const RegistrationSuccess({
    required this.email,
    required this.fullName,
    required this.mobileNumber,
  });

  @override
  List<Object?> get props => [email, fullName, mobileNumber];
}

class OtpVerificationRequired extends AuthenticationState {
  final String email;
  final String? fullName;
  final String? mobileNumber;
  final bool otpResent;
  final String? infoMessage;

  const OtpVerificationRequired({
    required this.email,
    this.fullName,
    this.mobileNumber,
    this.otpResent = false,
    this.infoMessage,
  });

  @override
  List<Object?> get props => [
    email,
    fullName,
    mobileNumber,
    otpResent,
    infoMessage,
  ];
}

class AuthenticationSuccess extends AuthenticationState {
  final CustomerProfileEntity profile;

  const AuthenticationSuccess(this.profile);

  @override
  List<Object?> get props => [profile];
}

class PendingApproval extends AuthenticationState {
  final CustomerProfileEntity profile;
  final String? statusMessage;

  const PendingApproval(this.profile, {this.statusMessage});

  @override
  List<Object?> get props => [profile, statusMessage];
}

class AccountRejected extends AuthenticationState {
  final CustomerProfileEntity profile;
  final String? reason;

  const AccountRejected({required this.profile, this.reason});

  @override
  List<Object?> get props => [profile, reason];
}

class AccountSuspended extends AuthenticationState {
  final CustomerProfileEntity profile;

  const AccountSuspended(this.profile);

  @override
  List<Object?> get props => [profile];
}

class PasswordResetEmailSent extends AuthenticationState {
  final String email;
  final bool isResend;
  final String message;

  const PasswordResetEmailSent({
    required this.email,
    this.isResend = false,
    this.message =
        'If an account exists for this email, a 6-digit reset code has been sent.',
  });

  @override
  List<Object?> get props => [email, isResend, message];
}

class PasswordResetVerified extends AuthenticationState {
  final String email;

  const PasswordResetVerified({required this.email});

  @override
  List<Object?> get props => [email];
}

class PasswordResetSuccess extends AuthenticationState {
  final String message;

  const PasswordResetSuccess({
    this.message =
        'Your password has been updated. Please sign in with your new password.',
  });

  @override
  List<Object?> get props => [message];
}

class AuthenticationFailure extends AuthenticationState {
  final Failure failure;
  final String? email;
  final CustomerProfileEntity? previousProfile;

  const AuthenticationFailure(this.failure, {this.email, this.previousProfile});

  @override
  List<Object?> get props => [failure, email, previousProfile];
}
