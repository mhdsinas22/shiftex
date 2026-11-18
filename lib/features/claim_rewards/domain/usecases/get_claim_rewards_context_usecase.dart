import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/claim_wallet_context_entity.dart';
import 'package:shiftex/features/claim_rewards/domain/repositories/claim_rewards_repository.dart';

class GetClaimRewardsContextUseCase
    implements UseCase<ClaimWalletContextEntity, NoParams> {
  final ClaimRewardsRepository _repository;

  const GetClaimRewardsContextUseCase(this._repository);

  @override
  Future<Either<Failure, ClaimWalletContextEntity>> call(NoParams params) {
    return _repository.getClaimRewardsContext();
  }
}
