import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/claim_operation_result_entity.dart';
import 'package:shiftex/features/claim_rewards/domain/repositories/claim_rewards_repository.dart';

class CancelRewardClaimParams extends Equatable {
  final String claimId;

  const CancelRewardClaimParams({required this.claimId});

  @override
  List<Object?> get props => [claimId];
}

class CancelRewardClaimUseCase
    implements UseCase<ClaimOperationResultEntity, CancelRewardClaimParams> {
  final ClaimRewardsRepository _repository;

  const CancelRewardClaimUseCase(this._repository);

  @override
  Future<Either<Failure, ClaimOperationResultEntity>> call(
    CancelRewardClaimParams params,
  ) {
    return _repository.cancelRewardClaim(claimId: params.claimId);
  }
}
