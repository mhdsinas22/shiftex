import 'package:equatable/equatable.dart';

enum ActivityKind {
  dailyStreak,
  posPurchase,
  claimRedemption,
  festivalBonus,
  registrationBonus,
  adminAdjustment,
  lockedRelease;

  static ActivityKind fromString(String? raw, String? txType) {
    return switch (raw) {
      'daily_streak' => ActivityKind.dailyStreak,
      'pos_purchase' => ActivityKind.posPurchase,
      'claim_redemption' => ActivityKind.claimRedemption,
      'festival_bonus' => ActivityKind.festivalBonus,
      'registration_bonus' => ActivityKind.registrationBonus,
      'admin_adjustment' => ActivityKind.adminAdjustment,
      'locked_release' => ActivityKind.lockedRelease,
      _ => switch (txType) {
        'daily_streak' => ActivityKind.dailyStreak,
        'merchant_reward' => ActivityKind.posPurchase,
        'discount_redemption' => ActivityKind.claimRedemption,
        'streak_unlock' => ActivityKind.lockedRelease,
        _ => ActivityKind.adminAdjustment,
      },
    };
  }
}

class ActivityTransactionDetailsEntity extends Equatable {
  final String? merchantName;
  final String? terminalId;
  final String? claimVoucherCode;
  final String? rewardName;
  final String? orderReference;
  final String? billNumber;
  final double? purchaseAmount;
  final int instantPoints;
  final int futureLockedPoints;
  final DateTime? unlockAt;
  final DateTime? unlockedAt;
  final String? allocationStatus;
  final int? streakDay;
  final String? cycleReference;
  final bool inProgressStreak;
  final String? campaignName;
  final String? campaignCode;
  final String? campaignValidity;
  final String? adjustmentReason;
  final String? auditStatus;
  final String? rejectedReason;
  final String? flaggedReason;
  final DateTime? redeemedAt;
  final String? auditReference;
  final int? requestedPoints;

  const ActivityTransactionDetailsEntity({
    this.merchantName,
    this.terminalId,
    this.claimVoucherCode,
    this.rewardName,
    this.orderReference,
    this.billNumber,
    this.purchaseAmount,
    this.instantPoints = 0,
    this.futureLockedPoints = 0,
    this.unlockAt,
    this.unlockedAt,
    this.allocationStatus,
    this.streakDay,
    this.cycleReference,
    this.inProgressStreak = false,
    this.campaignName,
    this.campaignCode,
    this.campaignValidity,
    this.adjustmentReason,
    this.auditStatus,
    this.rejectedReason,
    this.flaggedReason,
    this.redeemedAt,
    this.auditReference,
    this.requestedPoints,
  });

  bool get hasSplitPoints => instantPoints > 0 && futureLockedPoints > 0;

  @override
  List<Object?> get props => [
    merchantName,
    terminalId,
    claimVoucherCode,
    rewardName,
    orderReference,
    billNumber,
    purchaseAmount,
    instantPoints,
    futureLockedPoints,
    unlockAt,
    unlockedAt,
    allocationStatus,
    streakDay,
    cycleReference,
    inProgressStreak,
    campaignName,
    campaignCode,
    campaignValidity,
    adjustmentReason,
    auditStatus,
    rejectedReason,
    flaggedReason,
    redeemedAt,
    auditReference,
    requestedPoints,
  ];
}

class ActivityTransactionEntity extends Equatable {
  final String id;
  final String recordSource;
  final ActivityKind kind;
  final String transactionType;
  final String title;
  final String description;
  final String referenceCode;
  final int pointsDelta;
  final int availablePointsPart;
  final int lockedPointsPart;
  final double historicalInrValue;
  final double historicalRate;
  final int historicalPointsPerRupee;
  final String currencyCode;
  final String status;
  final DateTime createdAt;
  final ActivityTransactionDetailsEntity details;
  final bool hasLoadedDetailedAudit;

  const ActivityTransactionEntity({
    required this.id,
    required this.recordSource,
    required this.kind,
    required this.transactionType,
    required this.title,
    required this.description,
    required this.referenceCode,
    required this.pointsDelta,
    required this.availablePointsPart,
    required this.lockedPointsPart,
    required this.historicalInrValue,
    required this.historicalRate,
    required this.historicalPointsPerRupee,
    required this.currencyCode,
    required this.status,
    required this.createdAt,
    required this.details,
    this.hasLoadedDetailedAudit = false,
  });

  bool get isCredit => pointsDelta > 0;
  bool get isDebit => pointsDelta < 0;
  bool get isReleaseEvent => kind == ActivityKind.lockedRelease;
  bool get isFailedOrCancelledClaim => recordSource == 'claim_audit';

  bool get isExpandable =>
      kind == ActivityKind.claimRedemption ||
      kind == ActivityKind.posPurchase ||
      kind == ActivityKind.dailyStreak ||
      kind == ActivityKind.festivalBonus ||
      kind == ActivityKind.adminAdjustment ||
      kind == ActivityKind.lockedRelease;

  ActivityTransactionEntity copyWith({
    String? status,
    ActivityTransactionDetailsEntity? details,
    bool? hasLoadedDetailedAudit,
  }) {
    return ActivityTransactionEntity(
      id: id,
      recordSource: recordSource,
      kind: kind,
      transactionType: transactionType,
      title: title,
      description: description,
      referenceCode: referenceCode,
      pointsDelta: pointsDelta,
      availablePointsPart: availablePointsPart,
      lockedPointsPart: lockedPointsPart,
      historicalInrValue: historicalInrValue,
      historicalRate: historicalRate,
      historicalPointsPerRupee: historicalPointsPerRupee,
      currencyCode: currencyCode,
      status: status ?? this.status,
      createdAt: createdAt,
      details: details ?? this.details,
      hasLoadedDetailedAudit:
          hasLoadedDetailedAudit ?? this.hasLoadedDetailedAudit,
    );
  }

  @override
  List<Object?> get props => [
    id,
    recordSource,
    kind,
    transactionType,
    title,
    description,
    referenceCode,
    pointsDelta,
    availablePointsPart,
    lockedPointsPart,
    historicalInrValue,
    historicalRate,
    historicalPointsPerRupee,
    currencyCode,
    status,
    createdAt,
    details,
    hasLoadedDetailedAudit,
  ];
}
