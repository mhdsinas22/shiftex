import 'package:equatable/equatable.dart';

enum PointTransactionType {
  dailyStreak('daily_streak'),
  merchantReward('merchant_reward'),
  discountRedemption('discount_redemption'),
  pointAdjustment('point_adjustment'),
  streakUnlock('streak_unlock');

  final String value;
  const PointTransactionType(this.value);

  static PointTransactionType fromString(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'merchant_reward':
        return PointTransactionType.merchantReward;
      case 'discount_redemption':
        return PointTransactionType.discountRedemption;
      case 'point_adjustment':
        return PointTransactionType.pointAdjustment;
      case 'streak_unlock':
        return PointTransactionType.streakUnlock;
      case 'daily_streak':
      default:
        return PointTransactionType.dailyStreak;
    }
  }
}

class PointTransactionEntity extends Equatable {
  final String id;
  final PointTransactionType type;
  final String title;
  final String description;
  final int pointsDelta;
  final bool isLockedAllocation;
  final DateTime createdAt;

  const PointTransactionEntity({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.pointsDelta,
    required this.isLockedAllocation,
    required this.createdAt,
  });

  bool get isCredit => pointsDelta >= 0;

  double inrEquivalent(double rate) => pointsDelta.abs() * rate;

  @override
  List<Object?> get props => [
    id,
    type,
    title,
    description,
    pointsDelta,
    isLockedAllocation,
    createdAt,
  ];
}
