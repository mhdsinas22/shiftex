import 'package:equatable/equatable.dart';

enum RewardClaimStatus {
  pending,
  redeemed,
  expired,
  cancelled;

  static RewardClaimStatus fromString(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'pending' => RewardClaimStatus.pending,
      'redeemed' => RewardClaimStatus.redeemed,
      'expired' => RewardClaimStatus.expired,
      'cancelled' => RewardClaimStatus.cancelled,
      _ => RewardClaimStatus.pending,
    };
  }
}

/// Domain entity representing an atomic single-use reward redemption claim
/// backed by a cryptographic Admin POS scanner token.
class RewardClaimEntity extends Equatable {
  final String id;
  final String userId;
  final String? qrTokenId;
  final String claimReference;
  final String qrPayload;
  final int points;
  final double pointsToInrRate;
  final double discountAmount;
  final RewardClaimStatus status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? redeemedAt;
  final String? billNumber;
  final String? branchName;
  final DateTime? releasedAt;

  const RewardClaimEntity({
    required this.id,
    required this.userId,
    this.qrTokenId,
    required this.claimReference,
    required this.qrPayload,
    required this.points,
    required this.pointsToInrRate,
    required this.discountAmount,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.redeemedAt,
    this.billNumber,
    this.branchName,
    this.releasedAt,
  });

  bool get isPending => status == RewardClaimStatus.pending;
  bool get isRedeemed => status == RewardClaimStatus.redeemed;
  bool get isExpired => status == RewardClaimStatus.expired;
  bool get isCancelled => status == RewardClaimStatus.cancelled;

  bool get hasSecurePayload =>
      qrPayload.startsWith('SHIIFTEX:CLAIM:V1:') &&
      qrPayload.contains(claimReference);

  bool isExpiredAt(DateTime now) {
    if (status == RewardClaimStatus.expired ||
        status == RewardClaimStatus.cancelled) {
      return true;
    }
    if (status == RewardClaimStatus.pending) {
      return !expiresAt.isAfter(now);
    }
    return false;
  }

  int remainingSecondsAt(DateTime now) {
    if (status != RewardClaimStatus.pending) {
      return 0;
    }
    final remaining = expiresAt.difference(now).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    qrTokenId,
    claimReference,
    qrPayload,
    points,
    pointsToInrRate,
    discountAmount,
    status,
    expiresAt,
    createdAt,
    redeemedAt,
    billNumber,
    branchName,
    releasedAt,
  ];
}
