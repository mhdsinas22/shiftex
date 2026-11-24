import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/change_email/domain/entities/change_email_result_entity.dart';

/// Contract for updating and verifying the authenticated customer's email
/// address on their existing Supabase Auth account without creating a new user.
abstract class ChangeEmailRepository {
  /// Re-authenticates the active user with [currentPassword] and initiates an
  /// email update to [newEmail] via `supabase.auth.updateUser`.
  Future<Either<Failure, ChangeEmailResultEntity>> requestEmailChange({
    required String currentPassword,
    required String newEmail,
  });

  /// Verifies the 6-digit email-change OTP via `OtpType.emailChange` (supporting
  /// both single confirmation on [newEmail] and Secure Email Change double
  /// confirmation across [currentEmail] and [newEmail]) and synchronizes the
  /// customer profile once confirmed.
  Future<Either<Failure, ChangeEmailResultEntity>> verifyEmailChangeOtp({
    required String newEmail,
    required String otpCode,
    String? currentEmail,
    bool verifyCurrentEmail = false,
    bool newEmailAlreadyVerified = false,
    bool currentEmailAlreadyVerified = false,
  });

  /// Resends the email-change verification email/code to [newEmail].
  Future<Either<Failure, Unit>> resendEmailChangeVerification({
    required String newEmail,
  });

  /// Refreshes the active Supabase Auth user/session to check whether a
  /// confirmation link click or OTP confirmation has finalized [targetEmail].
  Future<Either<Failure, ChangeEmailResultEntity>> checkEmailChangeStatus({
    required String targetEmail,
  });
}
