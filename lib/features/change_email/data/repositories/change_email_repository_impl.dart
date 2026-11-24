import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/error_mapper.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/network/network_info.dart';
import 'package:shiftex/features/change_email/data/datasources/change_email_remote_data_source.dart';
import 'package:shiftex/features/change_email/domain/entities/change_email_result_entity.dart';
import 'package:shiftex/features/change_email/domain/repositories/change_email_repository.dart';

/// Repository implementation coordinating connectivity checks and safe error
/// mapping for Supabase Auth email updates and confirmations.
class ChangeEmailRepositoryImpl implements ChangeEmailRepository {
  final ChangeEmailRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;

  const ChangeEmailRepositoryImpl({
    required ChangeEmailRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  }) : _remoteDataSource = remoteDataSource,
       _networkInfo = networkInfo;

  @override
  Future<Either<Failure, ChangeEmailResultEntity>> requestEmailChange({
    required String currentPassword,
    required String newEmail,
  }) async {
    try {
      if (!await _networkInfo.isConnected) {
        return const Left(NetworkFailure());
      }
      final result = await _remoteDataSource.requestEmailChange(
        currentPassword: currentPassword,
        newEmail: newEmail,
      );
      return Right(result);
    } catch (error) {
      return Left(
        ErrorMapper.mapExceptionToFailure(error, fallbackEmail: newEmail),
      );
    }
  }

  @override
  Future<Either<Failure, ChangeEmailResultEntity>> verifyEmailChangeOtp({
    required String newEmail,
    required String otpCode,
    String? currentEmail,
    bool verifyCurrentEmail = false,
    bool newEmailAlreadyVerified = false,
    bool currentEmailAlreadyVerified = false,
  }) async {
    try {
      if (!await _networkInfo.isConnected) {
        return const Left(NetworkFailure());
      }
      final result = await _remoteDataSource.verifyEmailChangeOtp(
        newEmail: newEmail,
        otpCode: otpCode,
        currentEmail: currentEmail,
        verifyCurrentEmail: verifyCurrentEmail,
        newEmailAlreadyVerified: newEmailAlreadyVerified,
        currentEmailAlreadyVerified: currentEmailAlreadyVerified,
      );
      return Right(result);
    } catch (error) {
      return Left(
        ErrorMapper.mapExceptionToFailure(error, fallbackEmail: newEmail),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> resendEmailChangeVerification({
    required String newEmail,
  }) async {
    try {
      if (!await _networkInfo.isConnected) {
        return const Left(NetworkFailure());
      }
      await _remoteDataSource.resendEmailChangeVerification(
        newEmail: newEmail,
      );
      return const Right(unit);
    } catch (error) {
      return Left(
        ErrorMapper.mapExceptionToFailure(error, fallbackEmail: newEmail),
      );
    }
  }

  @override
  Future<Either<Failure, ChangeEmailResultEntity>> checkEmailChangeStatus({
    required String targetEmail,
  }) async {
    try {
      if (!await _networkInfo.isConnected) {
        return const Left(NetworkFailure());
      }
      final result = await _remoteDataSource.checkEmailChangeStatus(
        targetEmail: targetEmail,
      );
      return Right(result);
    } catch (error) {
      return Left(
        ErrorMapper.mapExceptionToFailure(error, fallbackEmail: targetEmail),
      );
    }
  }
}
