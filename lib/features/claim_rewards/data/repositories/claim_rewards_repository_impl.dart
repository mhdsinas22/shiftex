import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/error_mapper.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/claim_rewards/data/datasources/claim_rewards_remote_data_source.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/claim_operation_result_entity.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/claim_wallet_context_entity.dart';
import 'package:shiftex/features/claim_rewards/domain/repositories/claim_rewards_repository.dart';

class ClaimRewardsRepositoryImpl implements ClaimRewardsRepository {
  final ClaimRewardsRemoteDataSource _remoteDataSource;

  const ClaimRewardsRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, ClaimWalletContextEntity>> getClaimRewardsContext() async {
    try {
      final walletContext = await _remoteDataSource.getClaimRewardsContext();
      return Right(walletContext);
    } catch (e) {
      return Left(ErrorMapper.mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, ClaimOperationResultEntity>> createRewardClaim({
    required int points,
    String? idempotencyKey,
  }) async {
    try {
      final result = await _remoteDataSource.createRewardClaim(
        points: points,
        idempotencyKey: idempotencyKey,
      );
      return Right(result);
    } catch (e) {
      return Left(ErrorMapper.mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, ClaimOperationResultEntity>> getCustomerClaimStatus({
    required String claimId,
  }) async {
    try {
      final result = await _remoteDataSource.getCustomerClaimStatus(
        claimId: claimId,
      );
      return Right(result);
    } catch (e) {
      return Left(ErrorMapper.mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, ClaimOperationResultEntity>> cancelRewardClaim({
    required String claimId,
  }) async {
    try {
      final result = await _remoteDataSource.cancelRewardClaim(
        claimId: claimId,
      );
      return Right(result);
    } catch (e) {
      return Left(ErrorMapper.mapExceptionToFailure(e));
    }
  }
}
