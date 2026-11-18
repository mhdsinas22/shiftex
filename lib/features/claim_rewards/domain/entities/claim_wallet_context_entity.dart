import 'package:equatable/equatable.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/reward_claim_entity.dart';

/// Represents the authenticated customer's instant claimable wallet snapshot,
/// active conversion rate, and any currently active pending claim.
class ClaimWalletContextEntity extends Equatable {
  final String customerCode;
  final String membershipTier;
  final int availablePoints;
  final int reservedPoints;
  final int lockedPoints;
  final double pointsToInrRate;
  final RewardClaimEntity? activePendingClaim;

  const ClaimWalletContextEntity({
    required this.customerCode,
    required this.membershipTier,
    required this.availablePoints,
    required this.reservedPoints,
    required this.lockedPoints,
    required this.pointsToInrRate,
    this.activePendingClaim,
  });

  double discountForPoints(int points) {
    if (points <= 0 || pointsToInrRate <= 0) {
      return 0.0;
    }
    return ((points * pointsToInrRate) * 100).roundToDouble() / 100.0;
  }

  double get availableInr => discountForPoints(availablePoints);

  int get pointsPerOneInr =>
      pointsToInrRate > 0 ? (1.0 / pointsToInrRate).round() : 10;

  int remainingPointsAfter(int selectedPoints) {
    if (selectedPoints <= 0) return availablePoints;
    final remaining = availablePoints - selectedPoints;
    return remaining < 0 ? 0 : remaining;
  }

  double remainingInrAfter(int selectedPoints) =>
      discountForPoints(remainingPointsAfter(selectedPoints));

  ClaimWalletContextEntity copyWith({
    String? customerCode,
    String? membershipTier,
    int? availablePoints,
    int? reservedPoints,
    int? lockedPoints,
    double? pointsToInrRate,
    RewardClaimEntity? activePendingClaim,
    bool clearActivePendingClaim = false,
  }) {
    return ClaimWalletContextEntity(
      customerCode: customerCode ?? this.customerCode,
      membershipTier: membershipTier ?? this.membershipTier,
      availablePoints: availablePoints ?? this.availablePoints,
      reservedPoints: reservedPoints ?? this.reservedPoints,
      lockedPoints: lockedPoints ?? this.lockedPoints,
      pointsToInrRate: pointsToInrRate ?? this.pointsToInrRate,
      activePendingClaim:
          clearActivePendingClaim
              ? null
              : (activePendingClaim ?? this.activePendingClaim),
    );
  }

  @override
  List<Object?> get props => [
    customerCode,
    membershipTier,
    availablePoints,
    reservedPoints,
    lockedPoints,
    pointsToInrRate,
    activePendingClaim,
  ];
}
