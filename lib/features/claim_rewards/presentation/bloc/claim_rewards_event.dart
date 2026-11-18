import 'package:equatable/equatable.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/reward_claim_entity.dart';

abstract class ClaimRewardsEvent extends Equatable {
  const ClaimRewardsEvent();

  @override
  List<Object?> get props => [];
}

class ClaimRewardsStarted extends ClaimRewardsEvent {
  final int? fallbackAvailablePoints;
  final double? fallbackPointsToInrRate;
  final int? fallbackLockedPoints;

  const ClaimRewardsStarted({
    this.fallbackAvailablePoints,
    this.fallbackPointsToInrRate,
    this.fallbackLockedPoints,
  });

  @override
  List<Object?> get props => [
    fallbackAvailablePoints,
    fallbackPointsToInrRate,
    fallbackLockedPoints,
  ];
}

class ClaimRewardsContextRefreshed extends ClaimRewardsEvent {
  const ClaimRewardsContextRefreshed();
}

class ClaimPresetSelected extends ClaimRewardsEvent {
  final int points;

  const ClaimPresetSelected(this.points);

  @override
  List<Object?> get props => [points];
}

class ClaimFullRequested extends ClaimRewardsEvent {
  const ClaimFullRequested();
}

class ClaimCustomAmountChanged extends ClaimRewardsEvent {
  final String rawInput;

  const ClaimCustomAmountChanged(this.rawInput);

  @override
  List<Object?> get props => [rawInput];
}

class ClaimGenerateRequested extends ClaimRewardsEvent {
  final String? idempotencyKey;

  const ClaimGenerateRequested({this.idempotencyKey});

  @override
  List<Object?> get props => [idempotencyKey];
}

class ClaimPendingResumed extends ClaimRewardsEvent {
  final RewardClaimEntity claim;

  const ClaimPendingResumed(this.claim);

  @override
  List<Object?> get props => [claim];
}

class ClaimStatusCheckRequested extends ClaimRewardsEvent {
  const ClaimStatusCheckRequested();
}

class ClaimCountdownTicked extends ClaimRewardsEvent {
  final DateTime? now;

  const ClaimCountdownTicked({this.now});

  @override
  List<Object?> get props => [now];
}

class ClaimCancelRequested extends ClaimRewardsEvent {
  final String claimId;

  const ClaimCancelRequested(this.claimId);

  @override
  List<Object?> get props => [claimId];
}

class ClaimPrepareNewRequested extends ClaimRewardsEvent {
  const ClaimPrepareNewRequested();
}

class ClaimFeedbackCleared extends ClaimRewardsEvent {
  const ClaimFeedbackCleared();
}
