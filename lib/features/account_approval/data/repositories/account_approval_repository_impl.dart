import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/error_mapper.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/account_approval/data/datasources/account_approval_remote_data_source.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';
import 'package:shiftex/features/account_approval/domain/repositories/account_approval_repository.dart';

class AccountApprovalRepositoryImpl implements AccountApprovalRepository {
  final AccountApprovalRemoteDataSource _remoteDataSource;

  const AccountApprovalRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, CustomerProfileEntity>> ensureCustomerProfile({
    String? fullName,
    String? mobileNumber,
  }) async {
    try {
      final profile = await _remoteDataSource.ensureCustomerProfile(
        fullName: fullName,
        mobileNumber: mobileNumber,
      );
      return Right(profile);
    } catch (e) {
      return Left(ErrorMapper.mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, CustomerProfileEntity>>
  fetchCurrentCustomerProfile() async {
    try {
      final profile = await _remoteDataSource.fetchCurrentCustomerProfile();
      return Right(profile);
    } catch (e) {
      return Left(ErrorMapper.mapExceptionToFailure(e));
    }
  }
}
