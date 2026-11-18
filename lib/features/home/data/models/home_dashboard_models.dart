import 'package:shiftex/features/home/domain/entities/advertisement_campaign_entity.dart';
import 'package:shiftex/features/home/domain/entities/customer_qr_token_entity.dart';
import 'package:shiftex/features/home/domain/entities/daily_streak_entity.dart';
import 'package:shiftex/features/home/domain/entities/home_dashboard_entity.dart';
import 'package:shiftex/features/home/domain/entities/locked_point_allocation_entity.dart';
import 'package:shiftex/features/home/domain/entities/point_transaction_entity.dart';
import 'package:shiftex/features/home/domain/entities/wallet_summary_entity.dart';

class WalletSummaryModel extends WalletSummaryEntity {
  const WalletSummaryModel({
    required super.customerCode,
    required super.membershipTier,
    required super.availablePoints,
    required super.lockedPoints,
    required super.lifetimeEarnedPoints,
    required super.lifetimeRedeemedPoints,
    required super.pointsEarnedToday,
    required super.pointsToInrRate,
  });

  factory WalletSummaryModel.fromJson(Map<String, dynamic> json) {
    return WalletSummaryModel(
      customerCode: (json['customer_code'] as String?) ?? 'SHFT-0000',
      membershipTier:
          (json['membership_tier'] as String?) ?? 'Pebble Black Member',
      availablePoints: (json['available_points'] as num?)?.toInt() ?? 0,
      lockedPoints: (json['locked_points'] as num?)?.toInt() ?? 0,
      lifetimeEarnedPoints:
          (json['lifetime_earned_points'] as num?)?.toInt() ?? 0,
      lifetimeRedeemedPoints:
          (json['lifetime_redeemed_points'] as num?)?.toInt() ?? 0,
      pointsEarnedToday: (json['points_earned_today'] as num?)?.toInt() ?? 0,
      pointsToInrRate:
          double.tryParse((json['points_to_inr_rate'] ?? '0.10').toString()) ??
          0.10,
    );
  }
}

class LockedPointAllocationModel extends LockedPointAllocationEntity {
  const LockedPointAllocationModel({
    required super.id,
    required super.sourceType,
    required super.points,
    required super.status,
    required super.description,
    required super.lockedAt,
    required super.unlockAt,
  });

  factory LockedPointAllocationModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();
    return LockedPointAllocationModel(
      id: (json['id'] as String?) ?? '',
      sourceType: (json['source_type'] as String?) ?? 'daily_streak',
      points: (json['points'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? 'locked',
      description: (json['description'] as String?) ?? '',
      lockedAt:
          DateTime.tryParse(json['locked_at']?.toString() ?? '') ?? now,
      unlockAt:
          DateTime.tryParse(json['unlock_at']?.toString() ?? '') ??
          now.add(const Duration(days: 7)),
    );
  }
}

class DailyStreakModel extends DailyStreakEntity {
  const DailyStreakModel({
    required super.dailyLoginEnabled,
    required super.dailyPoints,
    required super.currentStreakDay,
    required super.claimedToday,
    required super.daysRemaining,
    required super.cycleDate,
    required super.nextResetAt,
    required super.justCompletedDay7,
    required super.completedStreakPoints,
    super.completedUnlockAt,
  });

  factory DailyStreakModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();
    return DailyStreakModel(
      dailyLoginEnabled: (json['daily_login_enabled'] as bool?) ?? true,
      dailyPoints: (json['daily_points'] as num?)?.toInt() ?? 15,
      currentStreakDay: (json['current_streak_day'] as num?)?.toInt() ?? 1,
      claimedToday: (json['claimed_today'] as bool?) ?? false,
      daysRemaining: (json['days_remaining'] as num?)?.toInt() ?? 6,
      cycleDate: (json['cycle_date'] as String?) ?? '',
      nextResetAt:
          DateTime.tryParse(json['next_reset_at']?.toString() ?? '') ??
          now.add(const Duration(hours: 12)),
      justCompletedDay7: (json['just_completed_day_7'] as bool?) ?? false,
      completedStreakPoints:
          (json['completed_streak_points'] as num?)?.toInt() ?? 0,
      completedUnlockAt:
          json['completed_unlock_at'] != null
              ? DateTime.tryParse(json['completed_unlock_at'].toString())
              : null,
    );
  }
}

class AdvertisementCampaignModel extends AdvertisementCampaignEntity {
  const AdvertisementCampaignModel({
    required super.id,
    required super.title,
    required super.offerDetails,
    super.imageUrl,
    required super.popupDurationSeconds,
    required super.frequencyType,
    required super.frequencyLimit,
    required super.startAt,
    required super.endAt,
  });

  factory AdvertisementCampaignModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();
    final rawImage = (json['image_url'] as String?)?.trim();
    return AdvertisementCampaignModel(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      offerDetails: (json['offer_details'] as String?) ?? '',
      imageUrl: (rawImage != null && rawImage.isNotEmpty) ? rawImage : null,
      popupDurationSeconds:
          (json['popup_duration_seconds'] as num?)?.toInt() ?? 6,
      frequencyType: (json['frequency_type'] as String?) ?? 'once_per_session',
      frequencyLimit: (json['frequency_limit'] as num?)?.toInt() ?? 1,
      startAt: DateTime.tryParse(json['start_at']?.toString() ?? '') ?? now,
      endAt:
          DateTime.tryParse(json['end_at']?.toString() ?? '') ??
          now.add(const Duration(days: 7)),
    );
  }
}

class PointTransactionModel extends PointTransactionEntity {
  const PointTransactionModel({
    required super.id,
    required super.type,
    required super.title,
    required super.description,
    required super.pointsDelta,
    required super.isLockedAllocation,
    required super.createdAt,
  });

  factory PointTransactionModel.fromJson(Map<String, dynamic> json) {
    return PointTransactionModel(
      id: (json['id'] as String?) ?? '',
      type: PointTransactionType.fromString(
        json['transaction_type'] as String?,
      ),
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      pointsDelta: (json['points_delta'] as num?)?.toInt() ?? 0,
      isLockedAllocation: (json['is_locked_allocation'] as bool?) ?? false,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

class CustomerQrTokenModel extends CustomerQrTokenEntity {
  const CustomerQrTokenModel({
    required super.id,
    required super.tokenCode,
    required super.qrPayload,
    required super.status,
    required super.expiresAt,
    required super.createdAt,
  });

  factory CustomerQrTokenModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();
    return CustomerQrTokenModel(
      id: (json['id'] as String?) ?? '',
      tokenCode: (json['token_code'] as String?) ?? 'CLM-0000-X00',
      qrPayload: (json['qr_payload'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'active',
      expiresAt:
          DateTime.tryParse(json['expires_at']?.toString() ?? '') ??
          now.add(const Duration(minutes: 5)),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? now,
    );
  }
}

class HomeDashboardModel extends HomeDashboardEntity {
  const HomeDashboardModel({
    required super.customerId,
    required super.fullName,
    required super.email,
    required super.mobileNumber,
    required super.wallet,
    super.nextUnlockAllocation,
    required super.lockedAllocations,
    required super.streak,
    required super.recentTransactions,
    required super.advertisements,
  });

  factory HomeDashboardModel.fromJson(
    Map<String, dynamic> json, {
    List<AdvertisementCampaignEntity> advertisements = const [],
  }) {
    final profileMap =
        Map<String, dynamic>.from(
          (json['profile'] as Map?) ?? const <String, dynamic>{},
        );
    final walletMap =
        Map<String, dynamic>.from(
          (json['wallet'] as Map?) ?? const <String, dynamic>{},
        );
    final streakMap =
        Map<String, dynamic>.from(
          (json['streak'] as Map?) ?? const <String, dynamic>{},
        );
    final nextUnlockRaw = json['next_unlock_allocation'];
    final allocationsRaw = (json['locked_allocations'] as List?) ?? const [];
    final transactionsRaw = (json['recent_transactions'] as List?) ?? const [];

    return HomeDashboardModel(
      customerId: (profileMap['id'] as String?) ?? '',
      fullName: (profileMap['full_name'] as String?) ?? 'Member',
      email: (profileMap['email'] as String?) ?? '',
      mobileNumber: (profileMap['mobile_number'] as String?) ?? '',
      wallet: WalletSummaryModel.fromJson(walletMap),
      nextUnlockAllocation:
          nextUnlockRaw is Map
              ? LockedPointAllocationModel.fromJson(
                Map<String, dynamic>.from(nextUnlockRaw),
              )
              : null,
      lockedAllocations:
          allocationsRaw
              .whereType<Map>()
              .map(
                (item) => LockedPointAllocationModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
      streak: DailyStreakModel.fromJson(streakMap),
      recentTransactions:
          transactionsRaw
              .whereType<Map>()
              .map(
                (item) => PointTransactionModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
      advertisements: advertisements,
    );
  }
}
