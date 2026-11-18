import 'package:equatable/equatable.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/claim_wallet_context_entity.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/reward_claim_entity.dart';

/// Combined atomic claim and synchronized wallet snapshot returned by
/// claim creation, status check, and cancellation RPCs.
class ClaimOperationResultEntity extends Equatable {
  final RewardClaimEntity claim;
  final ClaimWalletContextEntity wallet;

  const ClaimOperationResultEntity({
    required this.claim,
    required this.wallet,
  });

  @override
  List<Object?> get props => [claim, wallet];
}
