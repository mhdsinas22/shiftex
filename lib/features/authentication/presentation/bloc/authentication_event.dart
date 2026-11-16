import 'package:equatable/equatable.dart';

abstract class AuthenticationEvent extends Equatable {
  const AuthenticationEvent();

  @override
  List<Object?> get props => [];
}

class RegisterRequested extends AuthenticationEvent {
  final String firstName;
  final String lastName;
  final String mobileNumber;
  final String email;
  final String password;

  const RegisterRequested({
    required this.firstName,
    required this.lastName,
    required this.mobileNumber,
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [
    firstName,
    lastName,
    mobileNumber,
    email,
    password,
  ];
}

class VerifyEmailOtpRequested extends AuthenticationEvent {
  final String email;
  final String otpCode;
  final String? fullName;
  final String? mobileNumber;

  const VerifyEmailOtpRequested({
    required this.email,
    required this.otpCode,
    this.fullName,
    this.mobileNumber,
  });

  @override
  List<Object?> get props => [email, otpCode, fullName, mobileNumber];
}

class ResendEmailOtpRequested extends AuthenticationEvent {
  final String email;

  const ResendEmailOtpRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

class LoginRequested extends AuthenticationEvent {
  final String identifier;
  final String password;
  final bool rememberMe;

  const LoginRequested({
    required this.identifier,
    required this.password,
    this.rememberMe = true,
  });

  @override
  List<Object?> get props => [identifier, password, rememberMe];
}

class LogoutRequested extends AuthenticationEvent {
  const LogoutRequested();
}

class ForgotPasswordRequested extends AuthenticationEvent {
  final String email;
  final bool isResend;

  const ForgotPasswordRequested({
    required this.email,
    this.isResend = false,
  });

  @override
  List<Object?> get props => [email, isResend];
}

class VerifyPasswordResetOtpRequested extends AuthenticationEvent {
  final String email;
  final String otpCode;

  const VerifyPasswordResetOtpRequested({
    required this.email,
    required this.otpCode,
  });

  @override
  List<Object?> get props => [email, otpCode];
}

class ResetPasswordRequested extends AuthenticationEvent {
  final String newPassword;

  const ResetPasswordRequested({required this.newPassword});

  @override
  List<Object?> get props => [newPassword];
}

class AuthSessionChanged extends AuthenticationEvent {
  final String? sessionEvent;

  const AuthSessionChanged({this.sessionEvent});

  @override
  List<Object?> get props => [sessionEvent];
}

class CheckApprovalStatusRequested extends AuthenticationEvent {
  const CheckApprovalStatusRequested();
}
