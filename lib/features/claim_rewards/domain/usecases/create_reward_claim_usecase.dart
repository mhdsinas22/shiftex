import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/claim_operation_result_entity.dart';
import 'package:shiftex/features/claim_rewards/domain/repositories/claim_rewards_repository.dart';

class CreateRewardClaimParams extends Equatable {
  final int points;
  final String? idempotencyKey;

  const CreateRewardClaimParams({
    required this.points,
    this.idempotencyKey,
  });

  @override
  List<Object?> get props => [points, idempotencyKey];
}

class CreateRewardClaimUseCase
    implements UseCase<ClaimOperationResultEntity, CreateRewardClaimParams> {
  final ClaimRewardsRepository _repository;

  const CreateRewardClaimUseCase(this._repository);

  @override
  Future<Either<Failure, ClaimOperationResultEntity>> call(
    CreateRewardClaimParams params,
  ) {
    if (params.points <= 0) {
      return Future.value(
        const Left(
          ValidationFailure('Enter a positive whole number of points.'),
        ),
      );
    }
    return _repository.createRewardClaim(
      points: params.points,
      idempotencyKey: params.idempotencyKey,
    );
  }
}
