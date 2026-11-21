import 'package:shiftex/features/activity_history/domain/entities/activity_filter.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_history_page_entity.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_transaction_entity.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_wallet_summary_entity.dart';
import 'package:shiftex/features/activity_history/domain/entities/monthly_statement_entity.dart';

class LedgerReconciliationModel extends LedgerReconciliationEntity {
  const LedgerReconciliationModel({
    required super.hasDiscrepancy,
    required super.availableOffsetPoints,
    required super.lockedOffsetPoints,
    required super.expectedAvailableFromLedger,
    required super.expectedLockedFromAllocations,
  });

  factory LedgerReconciliationModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const LedgerReconciliationModel(
        hasDiscrepancy: false,
        availableOffsetPoints: 0,
        lockedOffsetPoints: 0,
        expectedAvailableFromLedger: 0,
        expectedLockedFromAllocations: 0,
      );
    }
    return LedgerReconciliationModel(
      hasDiscrepancy: (json['has_discrepancy'] as bool?) ?? false,
      availableOffsetPoints:
          (json['available_offset_points'] as num?)?.toInt() ?? 0,
      lockedOffsetPoints: (json['locked_offset_points'] as num?)?.toInt() ?? 0,
      expectedAvailableFromLedger:
          (json['expected_available_from_ledger'] as num?)?.toInt() ?? 0,
      expectedLockedFromAllocations:
          (json['expected_locked_from_allocations'] as num?)?.toInt() ?? 0,
    );
  }
}

class ActivityWalletSummaryModel extends ActivityWalletSummaryEntity {
  const ActivityWalletSummaryModel({
    required super.customerCode,
    required super.membershipTier,
    required super.netAvailablePoints,
    required super.netAvailableInr,
    required super.reservedPoints,
    required super.lockedPoints,
    required super.lockedInr,
    required super.lifetimeEarnedPoints,
    required super.lifetimeEarnedInr,
    required super.totalRedeemedPoints,
    required super.totalRedeemedInr,
    required super.walletLifetimeEarnedPoints,
    required super.currentPointsToInrRate,
    required super.currentPointsPerRupee,
    required super.currencyCode,
    required super.timezone,
    required super.reconciliation,
  });

  factory ActivityWalletSummaryModel.fromJson(Map<String, dynamic> json) {
    final recRaw = json['reconciliation'];
    return ActivityWalletSummaryModel(
      customerCode: (json['customer_code'] as String?) ?? 'SHFT-0000',
      membershipTier:
          (json['membership_tier'] as String?) ?? 'Pebble Black Member',
      netAvailablePoints: (json['net_available_points'] as num?)?.toInt() ?? 0,
      netAvailableInr: _parseDouble(json['net_available_inr']),
      reservedPoints: (json['reserved_points'] as num?)?.toInt() ?? 0,
      lockedPoints: (json['locked_points'] as num?)?.toInt() ?? 0,
      lockedInr: _parseDouble(json['locked_inr']),
      lifetimeEarnedPoints:
          (json['lifetime_earned_points'] as num?)?.toInt() ?? 0,
      lifetimeEarnedInr: _parseDouble(json['lifetime_earned_inr']),
      totalRedeemedPoints:
          (json['total_redeemed_points'] as num?)?.toInt() ?? 0,
      totalRedeemedInr: _parseDouble(json['total_redeemed_inr']),
      walletLifetimeEarnedPoints:
          (json['wallet_lifetime_earned_points'] as num?)?.toInt() ?? 0,
      currentPointsToInrRate: _parseDouble(
        json['current_points_to_inr_rate'],
        fallback: 0.10,
      ),
      currentPointsPerRupee:
          (json['current_points_per_rupee'] as num?)?.toInt() ?? 10,
      currencyCode: (json['currency_code'] as String?) ?? 'INR',
      timezone: (json['timezone'] as String?) ?? 'Asia/Kolkata',
      reconciliation: LedgerReconciliationModel.fromJson(
        recRaw is Map ? Map<String, dynamic>.from(recRaw) : null,
      ),
    );
  }
}

class ActivityTransactionDetailsModel extends ActivityTransactionDetailsEntity {
  const ActivityTransactionDetailsModel({
    super.merchantName,
    super.terminalId,
    super.claimVoucherCode,
    super.rewardName,
    super.orderReference,
    super.billNumber,
    super.purchaseAmount,
    super.instantPoints,
    super.futureLockedPoints,
    super.unlockAt,
    super.unlockedAt,
    super.allocationStatus,
    super.streakDay,
    super.cycleReference,
    super.inProgressStreak,
    super.campaignName,
    super.campaignCode,
    super.campaignValidity,
    super.adjustmentReason,
    super.auditStatus,
    super.rejectedReason,
    super.flaggedReason,
    super.redeemedAt,
    super.auditReference,
    super.requestedPoints,
  });

  factory ActivityTransactionDetailsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ActivityTransactionDetailsModel();
    }
    return ActivityTransactionDetailsModel(
      merchantName: json['merchant_name'] as String?,
      terminalId: json['terminal_id'] as String?,
      claimVoucherCode: json['claim_voucher_code'] as String?,
      rewardName: json['reward_name'] as String?,
      orderReference: json['order_reference'] as String?,
      billNumber: json['bill_number'] as String?,
      purchaseAmount:
          json['purchase_amount'] != null
              ? _parseDouble(json['purchase_amount'])
              : null,
      instantPoints: (json['instant_points'] as num?)?.toInt() ?? 0,
      futureLockedPoints: (json['future_locked_points'] as num?)?.toInt() ?? 0,
      unlockAt: _parseDate(json['unlock_at']),
      unlockedAt: _parseDate(json['unlocked_at']),
      allocationStatus: json['allocation_status'] as String?,
      streakDay: (json['streak_day'] as num?)?.toInt(),
      cycleReference: json['cycle_reference'] as String?,
      inProgressStreak: (json['in_progress_streak'] as bool?) ?? false,
      campaignName: json['campaign_name'] as String?,
      campaignCode: json['campaign_code'] as String?,
      campaignValidity: json['campaign_validity'] as String?,
      adjustmentReason: json['adjustment_reason'] as String?,
      auditStatus: json['audit_status'] as String?,
      rejectedReason: json['rejected_reason'] as String?,
      flaggedReason: json['flagged_reason'] as String?,
      redeemedAt: _parseDate(json['redeemed_at']),
      auditReference: json['audit_reference'] as String?,
      requestedPoints: (json['requested_points'] as num?)?.toInt(),
    );
  }
}

class ActivityTransactionModel extends ActivityTransactionEntity {
  const ActivityTransactionModel({
    required super.id,
    required super.recordSource,
    required super.kind,
    required super.transactionType,
    required super.title,
    required super.description,
    required super.referenceCode,
    required super.pointsDelta,
    required super.availablePointsPart,
    required super.lockedPointsPart,
    required super.historicalInrValue,
    required super.historicalRate,
    required super.historicalPointsPerRupee,
    required super.currencyCode,
    required super.status,
    required super.createdAt,
    required super.details,
    super.hasLoadedDetailedAudit,
  });

  factory ActivityTransactionModel.fromJson(Map<String, dynamic> json) {
    final txType = (json['transaction_type'] as String?) ?? 'point_adjustment';
    final kind = ActivityKind.fromString(
      json['activity_kind'] as String?,
      txType,
    );
    final detailsRaw = json['details'];

    return ActivityTransactionModel(
      id: (json['id'] as String?) ?? '',
      recordSource: (json['record_source'] as String?) ?? 'ledger',
      kind: kind,
      transactionType: txType,
      title: (json['title'] as String?) ?? 'Activity',
      description: (json['description'] as String?) ?? '',
      referenceCode: (json['reference_code'] as String?) ?? '',
      pointsDelta: (json['points_delta'] as num?)?.toInt() ?? 0,
      availablePointsPart:
          (json['available_points_part'] as num?)?.toInt() ?? 0,
      lockedPointsPart: (json['locked_points_part'] as num?)?.toInt() ?? 0,
      historicalInrValue: _parseDouble(json['inr_value']),
      historicalRate: _parseDouble(json['historical_rate'], fallback: 0.10),
      historicalPointsPerRupee: (json['points_per_rupee'] as num?)?.toInt() ?? 10,
      currencyCode: (json['currency_code'] as String?) ?? 'INR',
      status: (json['status'] as String?) ?? 'Completed',
      createdAt: _parseDate(json['created_at']) ?? DateTime.now().toUtc(),
      details: ActivityTransactionDetailsModel.fromJson(
        detailsRaw is Map ? Map<String, dynamic>.from(detailsRaw) : null,
      ),
    );
  }
}

class ActivityHistoryPageModel extends ActivityHistoryPageEntity {
  const ActivityHistoryPageModel({
    required super.summary,
    required super.filter,
    required super.limit,
    required super.offset,
    required super.hasMore,
    required super.transactions,
  });

  factory ActivityHistoryPageModel.fromJson(Map<String, dynamic> json) {
    final summaryRaw = json['summary'];
    final txRaw = json['transactions'];
    final filterStr = (json['filter'] as String?) ?? 'all';
    final filter = switch (filterStr) {
      'earned' => ActivityFilter.earned,
      'claims' => ActivityFilter.claims,
      'daily_streak' => ActivityFilter.dailyStreak,
      _ => ActivityFilter.all,
    };

    final items = <ActivityTransactionEntity>[];
    if (txRaw is List) {
      for (final item in txRaw) {
        if (item is Map) {
          items.add(
            ActivityTransactionModel.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return ActivityHistoryPageModel(
      summary: ActivityWalletSummaryModel.fromJson(
        summaryRaw is Map ? Map<String, dynamic>.from(summaryRaw) : const {},
      ),
      filter: filter,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      hasMore: (json['has_more'] as bool?) ?? false,
      transactions: items,
    );
  }
}

class StatementLineItemModel extends StatementLineItemEntity {
  const StatementLineItemModel({
    required super.transactionId,
    required super.rawId,
    required super.transactionType,
    required super.title,
    required super.description,
    required super.pointsCredited,
    required super.pointsDeducted,
    required super.historicalInr,
    required super.historicalRate,
    required super.currencyCode,
    required super.isLockedAllocation,
    required super.status,
    required super.createdAt,
  });

  factory StatementLineItemModel.fromJson(Map<String, dynamic> json) {
    return StatementLineItemModel(
      transactionId: (json['transaction_id'] as String?) ?? '',
      rawId: (json['raw_id'] as String?) ?? '',
      transactionType: (json['transaction_type'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      pointsCredited: (json['points_credited'] as num?)?.toInt() ?? 0,
      pointsDeducted: (json['points_deducted'] as num?)?.toInt() ?? 0,
      historicalInr: _parseDouble(json['historical_inr']),
      historicalRate: _parseDouble(json['historical_rate'], fallback: 0.10),
      currencyCode: (json['currency_code'] as String?) ?? 'INR',
      isLockedAllocation: (json['is_locked_allocation'] as bool?) ?? false,
      status: (json['status'] as String?) ?? 'Completed',
      createdAt: _parseDate(json['created_at']) ?? DateTime.now().toUtc(),
    );
  }
}

class MonthlyStatementModel extends MonthlyStatementEntity {
  const MonthlyStatementModel({
    required super.customerName,
    required super.membershipId,
    required super.year,
    required super.month,
    required super.timezone,
    required super.openingAvailableBalance,
    required super.totalEarnedPoints,
    required super.totalEarnedInr,
    required super.totalRedeemedPoints,
    required super.totalRedeemedInr,
    required super.lockedAllocatedPoints,
    required super.lockedReleasedPoints,
    required super.closingAvailableBalance,
    required super.generatedAt,
    required super.items,
  });

  factory MonthlyStatementModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <StatementLineItemEntity>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          items.add(
            StatementLineItemModel.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return MonthlyStatementModel(
      customerName: (json['customer_name'] as String?) ?? 'SHIIFTEX Member',
      membershipId: (json['membership_id'] as String?) ?? 'SHFT-0000',
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
      timezone: (json['timezone'] as String?) ?? 'Asia/Kolkata',
      openingAvailableBalance:
          (json['opening_available_balance'] as num?)?.toInt() ?? 0,
      totalEarnedPoints: (json['total_earned_points'] as num?)?.toInt() ?? 0,
      totalEarnedInr: _parseDouble(json['total_earned_inr']),
      totalRedeemedPoints:
          (json['total_redeemed_points'] as num?)?.toInt() ?? 0,
      totalRedeemedInr: _parseDouble(json['total_redeemed_inr']),
      lockedAllocatedPoints:
          (json['locked_allocated_points'] as num?)?.toInt() ?? 0,
      lockedReleasedPoints:
          (json['locked_released_points'] as num?)?.toInt() ?? 0,
      closingAvailableBalance:
          (json['closing_available_balance'] as num?)?.toInt() ?? 0,
      generatedAt: _parseDate(json['generated_at']) ?? DateTime.now().toUtc(),
      items: items,
    );
  }
}

double _parseDouble(dynamic value, {double fallback = 0.0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toUtc();
}
