import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/error_mapper.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/network/network_info.dart';
import 'package:shiftex/features/change_phone/data/datasources/change_phone_remote_data_source.dart';
import 'package:shiftex/features/change_phone/domain/entities/change_phone_result_entity.dart';
import 'package:shiftex/features/change_phone/domain/repositories/change_phone_repository.dart';

/// Repository implementation coordinating connectivity checks and safe error
/// mapping for direct phone number updates on `public.profiles`.
class ChangePhoneRepositoryImpl implements ChangePhoneRepository {
  final ChangePhoneRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;

  const ChangePhoneRepositoryImpl({
    required ChangePhoneRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  }) : _remoteDataSource = remoteDataSource,
       _networkInfo = networkInfo;

  @override
  Future<Either<Failure, ChangePhoneResultEntity>> changePhoneNumber({
    required String newPhoneNumber,
    String? currentPhoneNumber,
  }) async {
    try {
      if (!await _networkInfo.isConnected) {
        return const Left(NetworkFailure());
      }
      final result = await _remoteDataSource.changePhoneNumber(
        newPhoneNumber: newPhoneNumber,
        currentPhoneNumber: currentPhoneNumber,
      );
      return Right(result);
    } catch (error) {
      return Left(ErrorMapper.mapExceptionToFailure(error));
    }
  }
}
