import 'package:equatable/equatable.dart';
import 'package:shiftex/features/home/domain/entities/advertisement_campaign_entity.dart';
import 'package:shiftex/features/home/domain/entities/daily_streak_entity.dart';
import 'package:shiftex/features/home/domain/entities/locked_point_allocation_entity.dart';
import 'package:shiftex/features/home/domain/entities/point_transaction_entity.dart';
import 'package:shiftex/features/home/domain/entities/wallet_summary_entity.dart';

class HomeDashboardEntity extends Equatable {
  final String customerId;
  final String fullName;
  final String email;
  final String mobileNumber;
  final WalletSummaryEntity wallet;
  final LockedPointAllocationEntity? nextUnlockAllocation;
  final List<LockedPointAllocationEntity> lockedAllocations;
  final DailyStreakEntity streak;
  final List<PointTransactionEntity> recentTransactions;
  final List<AdvertisementCampaignEntity> advertisements;

  const HomeDashboardEntity({
    required this.customerId,
    required this.fullName,
    required this.email,
    required this.mobileNumber,
    required this.wallet,
    this.nextUnlockAllocation,
    required this.lockedAllocations,
    required this.streak,
    required this.recentTransactions,
    required this.advertisements,
  });

  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'Member';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  HomeDashboardEntity copyWith({
    String? customerId,
    String? fullName,
    String? email,
    String? mobileNumber,
    WalletSummaryEntity? wallet,
    LockedPointAllocationEntity? nextUnlockAllocation,
    List<LockedPointAllocationEntity>? lockedAllocations,
    DailyStreakEntity? streak,
    List<PointTransactionEntity>? recentTransactions,
    List<AdvertisementCampaignEntity>? advertisements,
  }) {
    return HomeDashboardEntity(
      customerId: customerId ?? this.customerId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      wallet: wallet ?? this.wallet,
      nextUnlockAllocation: nextUnlockAllocation ?? this.nextUnlockAllocation,
      lockedAllocations: lockedAllocations ?? this.lockedAllocations,
      streak: streak ?? this.streak,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      advertisements: advertisements ?? this.advertisements,
    );
  }

  @override
  List<Object?> get props => [
    customerId,
    fullName,
    email,
    mobileNumber,
    wallet,
    nextUnlockAllocation,
    lockedAllocations,
    streak,
    recentTransactions,
    advertisements,
  ];
}
