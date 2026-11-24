import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/error_mapper.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/network/network_info.dart';
import 'package:shiftex/features/change_password/data/datasources/change_password_remote_data_source.dart';
import 'package:shiftex/features/change_password/domain/repositories/change_password_repository.dart';

/// Repository implementation coordinating connectivity checks and safe error mapping
/// for password changes.
class ChangePasswordRepositoryImpl implements ChangePasswordRepository {
  final ChangePasswordRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;

  const ChangePasswordRepositoryImpl({
    required ChangePasswordRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  }) : _remoteDataSource = remoteDataSource,
       _networkInfo = networkInfo;

  @override
  Future<Either<Failure, Unit>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      if (!await _networkInfo.isConnected) {
        return const Left(NetworkFailure());
      }
      await _remoteDataSource.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return const Right(unit);
    } catch (error) {
      return Left(ErrorMapper.mapExceptionToFailure(error));
    }
  }
}
