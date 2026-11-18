import 'package:equatable/equatable.dart';

class WalletSummaryEntity extends Equatable {
  final String customerCode;
  final String membershipTier;
  final int availablePoints;
  final int lockedPoints;
  final int lifetimeEarnedPoints;
  final int lifetimeRedeemedPoints;
  final int pointsEarnedToday;
  final double pointsToInrRate;

  const WalletSummaryEntity({
    required this.customerCode,
    required this.membershipTier,
    required this.availablePoints,
    required this.lockedPoints,
    required this.lifetimeEarnedPoints,
    required this.lifetimeRedeemedPoints,
    required this.pointsEarnedToday,
    required this.pointsToInrRate,
  });

  double get availableInr => availablePoints * pointsToInrRate;
  double get lockedInr => lockedPoints * pointsToInrRate;
  double get earnedTodayInr => pointsEarnedToday * pointsToInrRate;

  int get pointsPerOneInr =>
      pointsToInrRate > 0 ? (1.0 / pointsToInrRate).round() : 10;

  @override
  List<Object?> get props => [
    customerCode,
    membershipTier,
    availablePoints,
    lockedPoints,
    lifetimeEarnedPoints,
    lifetimeRedeemedPoints,
    pointsEarnedToday,
    pointsToInrRate,
  ];
}
