import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/claim_operation_result_entity.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/claim_wallet_context_entity.dart';

abstract class ClaimRewardsRepository {
  Future<Either<Failure, ClaimWalletContextEntity>> getClaimRewardsContext();

  Future<Either<Failure, ClaimOperationResultEntity>> createRewardClaim({
    required int points,
    String? idempotencyKey,
  });

  Future<Either<Failure, ClaimOperationResultEntity>> getCustomerClaimStatus({
    required String claimId,
  });

  Future<Either<Failure, ClaimOperationResultEntity>> cancelRewardClaim({
    required String claimId,
  });
}
