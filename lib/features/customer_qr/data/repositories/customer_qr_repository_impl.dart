import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/error_mapper.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/customer_qr/data/datasources/customer_qr_remote_data_source.dart';
import 'package:shiftex/features/customer_qr/domain/entities/customer_qr_entity.dart';
import 'package:shiftex/features/customer_qr/domain/repositories/customer_qr_repository.dart';

class CustomerQrRepositoryImpl implements CustomerQrRepository {
  final CustomerQrRemoteDataSource _remoteDataSource;

  const CustomerQrRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, CustomerQrEntity>> getCustomerPersonalQr({
    bool forceRegenerate = false,
  }) async {
    try {
      final model = await _remoteDataSource.getCustomerPersonalQr(
        forceRegenerate: forceRegenerate,
      );
      return Right(model);
    } catch (e) {
      return Left(ErrorMapper.mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, bool>> revokePersonalQr() async {
    try {
      final revoked = await _remoteDataSource.revokePersonalQr();
      return Right(revoked);
    } catch (e) {
      return Left(ErrorMapper.mapExceptionToFailure(e));
    }
  }
}
