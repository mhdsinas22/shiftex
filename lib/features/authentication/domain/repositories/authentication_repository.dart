import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';

abstract class AuthenticationRepository {
  Future<Either<Failure, String>> register({
    required String firstName,
    required String lastName,
    required String mobileNumber,
    required String email,
    required String password,
  });

  Future<Either<Failure, CustomerProfileEntity>> verifyEmailOtp({
    required String email,
    required String otpCode,
    String? fullName,
    String? mobileNumber,
  });

  Future<Either<Failure, void>> resendEmailOtp({
    required String email,
  });

  Future<Either<Failure, CustomerProfileEntity>> login({
    required String identifier,
    required String password,
    required bool rememberMe,
  });

  Future<Either<Failure, void>> sendPasswordResetOtp({
    required String email,
  });

  Future<Either<Failure, void>> verifyPasswordResetOtp({
    required String email,
    required String otpCode,
  });

  Future<Either<Failure, void>> resetPassword({
    required String newPassword,
  });

  Future<Either<Failure, CustomerProfileEntity?>> getCurrentSessionProfile();

  Future<Either<Failure, void>> logout();

  Stream<String> get authSessionEvents;
}
