import 'package:equatable/equatable.dart';

class LedgerReconciliationEntity extends Equatable {
  final bool hasDiscrepancy;
  final int availableOffsetPoints;
  final int lockedOffsetPoints;
  final int expectedAvailableFromLedger;
  final int expectedLockedFromAllocations;

  const LedgerReconciliationEntity({
    required this.hasDiscrepancy,
    required this.availableOffsetPoints,
    required this.lockedOffsetPoints,
    required this.expectedAvailableFromLedger,
    required this.expectedLockedFromAllocations,
  });

  @override
  List<Object?> get props => [
    hasDiscrepancy,
    availableOffsetPoints,
    lockedOffsetPoints,
    expectedAvailableFromLedger,
    expectedLockedFromAllocations,
  ];
}

class ActivityWalletSummaryEntity extends Equatable {
  final String customerCode;
  final String membershipTier;
  final int netAvailablePoints;
  final double netAvailableInr;
  final int reservedPoints;
  final int lockedPoints;
  final double lockedInr;
  final int lifetimeEarnedPoints;
  final double lifetimeEarnedInr;
  final int totalRedeemedPoints;
  final double totalRedeemedInr;
  final int walletLifetimeEarnedPoints;
  final double currentPointsToInrRate;
  final int currentPointsPerRupee;
  final String currencyCode;
  final String timezone;
  final LedgerReconciliationEntity reconciliation;

  const ActivityWalletSummaryEntity({
    required this.customerCode,
    required this.membershipTier,
    required this.netAvailablePoints,
    required this.netAvailableInr,
    required this.reservedPoints,
    required this.lockedPoints,
    required this.lockedInr,
    required this.lifetimeEarnedPoints,
    required this.lifetimeEarnedInr,
    required this.totalRedeemedPoints,
    required this.totalRedeemedInr,
    required this.walletLifetimeEarnedPoints,
    required this.currentPointsToInrRate,
    required this.currentPointsPerRupee,
    required this.currencyCode,
    required this.timezone,
    required this.reconciliation,
  });

  @override
  List<Object?> get props => [
    customerCode,
    membershipTier,
    netAvailablePoints,
    netAvailableInr,
    reservedPoints,
    lockedPoints,
    lockedInr,
    lifetimeEarnedPoints,
    lifetimeEarnedInr,
    totalRedeemedPoints,
    totalRedeemedInr,
    walletLifetimeEarnedPoints,
    currentPointsToInrRate,
    currentPointsPerRupee,
    currencyCode,
    timezone,
    reconciliation,
  ];
}
