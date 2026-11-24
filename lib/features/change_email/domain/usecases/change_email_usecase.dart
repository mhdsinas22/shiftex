import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/change_email/domain/entities/change_email_result_entity.dart';
import 'package:shiftex/features/change_email/domain/repositories/change_email_repository.dart';

/// Parameters for initiating an email change on the current authenticated user.
class ChangeEmailParams extends Equatable {
  final String currentPassword;
  final String newEmail;

  const ChangeEmailParams({
    required this.currentPassword,
    required this.newEmail,
  });

  @override
  List<Object?> get props => [currentPassword, newEmail];

  @override
  bool get stringify => false;

  @override
  String toString() => 'ChangeEmailParams(redacted)';
}

/// Initiates an email change request on the existing Supabase Auth account.
class ChangeEmailUseCase
    implements UseCase<ChangeEmailResultEntity, ChangeEmailParams> {
  final ChangeEmailRepository _repository;

  const ChangeEmailUseCase(this._repository);

  @override
  Future<Either<Failure, ChangeEmailResultEntity>> call(
    ChangeEmailParams params,
  ) {
    return _repository.requestEmailChange(
      currentPassword: params.currentPassword,
      newEmail: params.newEmail,
    );
  }
}

/// Parameters for verifying a 6-digit email change OTP code.
class VerifyEmailChangeOtpParams extends Equatable {
  final String newEmail;
  final String otpCode;
  final String? currentEmail;
  final bool verifyCurrentEmail;
  final bool newEmailAlreadyVerified;
  final bool currentEmailAlreadyVerified;

  const VerifyEmailChangeOtpParams({
    required this.newEmail,
    required this.otpCode,
    this.currentEmail,
    this.verifyCurrentEmail = false,
    this.newEmailAlreadyVerified = false,
    this.currentEmailAlreadyVerified = false,
  });

  @override
  List<Object?> get props => [
    newEmail,
    otpCode,
    currentEmail,
    verifyCurrentEmail,
    newEmailAlreadyVerified,
    currentEmailAlreadyVerified,
  ];

  @override
  bool get stringify => false;

  @override
  String toString() =>
      'VerifyEmailChangeOtpParams(verifyCurrentEmail: $verifyCurrentEmail, newEmailAlreadyVerified: $newEmailAlreadyVerified, currentEmailAlreadyVerified: $currentEmailAlreadyVerified)';
}

/// Verifies a 6-digit email change OTP code via Supabase Auth.
class VerifyEmailChangeOtpUseCase
    implements UseCase<ChangeEmailResultEntity, VerifyEmailChangeOtpParams> {
  final ChangeEmailRepository _repository;

  const VerifyEmailChangeOtpUseCase(this._repository);

  @override
  Future<Either<Failure, ChangeEmailResultEntity>> call(
    VerifyEmailChangeOtpParams params,
  ) {
    return _repository.verifyEmailChangeOtp(
      newEmail: params.newEmail,
      otpCode: params.otpCode,
      currentEmail: params.currentEmail,
      verifyCurrentEmail: params.verifyCurrentEmail,
      newEmailAlreadyVerified: params.newEmailAlreadyVerified,
      currentEmailAlreadyVerified: params.currentEmailAlreadyVerified,
    );
  }
}

/// Parameters for resending the email change confirmation message.
class ResendEmailChangeParams extends Equatable {
  final String newEmail;

  const ResendEmailChangeParams({required this.newEmail});

  @override
  List<Object?> get props => [newEmail];
}

/// Resends the email change verification code or confirmation link.
class ResendEmailChangeUseCase
    implements UseCase<Unit, ResendEmailChangeParams> {
  final ChangeEmailRepository _repository;

  const ResendEmailChangeUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(ResendEmailChangeParams params) {
    return _repository.resendEmailChangeVerification(
      newEmail: params.newEmail,
    );
  }
}

/// Parameters for checking whether the pending email change has been confirmed.
class CheckEmailChangeStatusParams extends Equatable {
  final String targetEmail;

  const CheckEmailChangeStatusParams({required this.targetEmail});

  @override
  List<Object?> get props => [targetEmail];
}

/// Refreshes the authenticated session and checks if the new email is active.
class CheckEmailChangeStatusUseCase
    implements UseCase<ChangeEmailResultEntity, CheckEmailChangeStatusParams> {
  final ChangeEmailRepository _repository;

  const CheckEmailChangeStatusUseCase(this._repository);

  @override
  Future<Either<Failure, ChangeEmailResultEntity>> call(
    CheckEmailChangeStatusParams params,
  ) {
    return _repository.checkEmailChangeStatus(
      targetEmail: params.targetEmail,
    );
  }
}
