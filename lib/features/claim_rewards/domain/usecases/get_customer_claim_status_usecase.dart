import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/claim_operation_result_entity.dart';
import 'package:shiftex/features/claim_rewards/domain/repositories/claim_rewards_repository.dart';

class GetCustomerClaimStatusParams extends Equatable {
  final String claimId;

  const GetCustomerClaimStatusParams({required this.claimId});

  @override
  List<Object?> get props => [claimId];
}

class GetCustomerClaimStatusUseCase
    implements
        UseCase<ClaimOperationResultEntity, GetCustomerClaimStatusParams> {
  final ClaimRewardsRepository _repository;

  const GetCustomerClaimStatusUseCase(this._repository);

  @override
  Future<Either<Failure, ClaimOperationResultEntity>> call(
    GetCustomerClaimStatusParams params,
  ) {
    return _repository.getCustomerClaimStatus(claimId: params.claimId);
  }
}
