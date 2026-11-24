import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';

/// Contract for verifying the authenticated customer's current password
/// and updating their Supabase Auth password without invalidating the session.
abstract class ChangePasswordRepository {
  /// Verifies [currentPassword] against the active authenticated user's email
  /// and updates their password to [newPassword].
  Future<Either<Failure, Unit>> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
