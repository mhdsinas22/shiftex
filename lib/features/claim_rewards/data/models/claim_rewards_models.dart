import 'package:shiftex/features/claim_rewards/domain/entities/claim_operation_result_entity.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/claim_wallet_context_entity.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/reward_claim_entity.dart';

class RewardClaimModel extends RewardClaimEntity {
  const RewardClaimModel({
    required super.id,
    required super.userId,
    super.qrTokenId,
    required super.claimReference,
    required super.qrPayload,
    required super.points,
    required super.pointsToInrRate,
    required super.discountAmount,
    required super.status,
    required super.expiresAt,
    required super.createdAt,
    super.redeemedAt,
    super.billNumber,
    super.branchName,
    super.releasedAt,
  });

  factory RewardClaimModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();
    return RewardClaimModel(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      qrTokenId: json['qr_token_id'] as String?,
      claimReference: ((json['claim_reference'] as String?) ?? '').trim(),
      qrPayload: ((json['qr_payload'] as String?) ?? '').trim(),
      points: (json['points'] as num?)?.toInt() ?? 0,
      pointsToInrRate:
          double.tryParse((json['points_to_inr_rate'] ?? '0.10').toString()) ??
          0.10,
      discountAmount:
          double.tryParse((json['discount_amount'] ?? '0').toString()) ?? 0.0,
      status: RewardClaimStatus.fromString(json['status'] as String?),
      expiresAt:
          DateTime.tryParse(json['expires_at']?.toString() ?? '')?.toUtc() ??
          now.add(const Duration(minutes: 5)),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toUtc() ??
          now,
      redeemedAt: DateTime.tryParse(
        json['redeemed_at']?.toString() ?? '',
      )?.toUtc(),
      billNumber: json['bill_number'] as String?,
      branchName: json['branch_name'] as String?,
      releasedAt: DateTime.tryParse(
        json['released_at']?.toString() ?? '',
      )?.toUtc(),
    );
  }
}

class ClaimWalletContextModel extends ClaimWalletContextEntity {
  const ClaimWalletContextModel({
    required super.customerCode,
    required super.membershipTier,
    required super.availablePoints,
    required super.reservedPoints,
    required super.lockedPoints,
    required super.pointsToInrRate,
    super.activePendingClaim,
  });

  factory ClaimWalletContextModel.fromJson(
    Map<String, dynamic> json, {
    double fallbackRate = 0.10,
  }) {
    final walletRaw = json['wallet'];
    final wallet =
        walletRaw is Map<String, dynamic>
            ? walletRaw
            : (walletRaw is Map
                ? Map<String, dynamic>.from(walletRaw)
                : json);

    final pendingRaw = json['active_pending_claim'];
    RewardClaimModel? pendingClaim;
    if (pendingRaw is Map) {
      pendingClaim = RewardClaimModel.fromJson(
        Map<String, dynamic>.from(pendingRaw),
      );
    }

    return ClaimWalletContextModel(
      customerCode: (wallet['customer_code'] as String?) ?? 'SHFT-0000',
      membershipTier:
          (wallet['membership_tier'] as String?) ?? 'Pebble Black Member',
      availablePoints: (wallet['available_points'] as num?)?.toInt() ?? 0,
      reservedPoints: (wallet['reserved_points'] as num?)?.toInt() ?? 0,
      lockedPoints: (wallet['locked_points'] as num?)?.toInt() ?? 0,
      pointsToInrRate:
          double.tryParse(
            (wallet['points_to_inr_rate'] ?? fallbackRate).toString(),
          ) ??
          fallbackRate,
      activePendingClaim: pendingClaim,
    );
  }
}

class ClaimOperationResultModel extends ClaimOperationResultEntity {
  const ClaimOperationResultModel({
    required super.claim,
    required super.wallet,
  });

  factory ClaimOperationResultModel.fromJson(Map<String, dynamic> json) {
    final claimRaw = json['claim'];
    if (claimRaw is! Map) {
      throw const FormatException('Missing claim payload in RPC response.');
    }
    final claim = RewardClaimModel.fromJson(
      Map<String, dynamic>.from(claimRaw),
    );
    final wallet = ClaimWalletContextModel.fromJson(
      json,
      fallbackRate: claim.pointsToInrRate,
    ).copyWith(
      activePendingClaim: claim.isPending ? claim : null,
      clearActivePendingClaim: !claim.isPending,
    );
    return ClaimOperationResultModel(claim: claim, wallet: wallet);
  }
}
