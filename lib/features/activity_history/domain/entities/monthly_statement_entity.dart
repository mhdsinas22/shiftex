import 'dart:typed_data';

import 'package:equatable/equatable.dart';

enum StatementExportFormat { pdf, csv }

class StatementLineItemEntity extends Equatable {
  final String transactionId;
  final String rawId;
  final String transactionType;
  final String title;
  final String description;
  final int pointsCredited;
  final int pointsDeducted;
  final double historicalInr;
  final double historicalRate;
  final String currencyCode;
  final bool isLockedAllocation;
  final String status;
  final DateTime createdAt;

  const StatementLineItemEntity({
    required this.transactionId,
    required this.rawId,
    required this.transactionType,
    required this.title,
    required this.description,
    required this.pointsCredited,
    required this.pointsDeducted,
    required this.historicalInr,
    required this.historicalRate,
    required this.currencyCode,
    required this.isLockedAllocation,
    required this.status,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    transactionId,
    rawId,
    transactionType,
    title,
    description,
    pointsCredited,
    pointsDeducted,
    historicalInr,
    historicalRate,
    currencyCode,
    isLockedAllocation,
    status,
    createdAt,
  ];
}

class MonthlyStatementEntity extends Equatable {
  final String customerName;
  final String membershipId;
  final int year;
  final int month;
  final String timezone;
  final int openingAvailableBalance;
  final int totalEarnedPoints;
  final double totalEarnedInr;
  final int totalRedeemedPoints;
  final double totalRedeemedInr;
  final int lockedAllocatedPoints;
  final int lockedReleasedPoints;
  final int closingAvailableBalance;
  final DateTime generatedAt;
  final List<StatementLineItemEntity> items;

  const MonthlyStatementEntity({
    required this.customerName,
    required this.membershipId,
    required this.year,
    required this.month,
    required this.timezone,
    required this.openingAvailableBalance,
    required this.totalEarnedPoints,
    required this.totalEarnedInr,
    required this.totalRedeemedPoints,
    required this.totalRedeemedInr,
    required this.lockedAllocatedPoints,
    required this.lockedReleasedPoints,
    required this.closingAvailableBalance,
    required this.generatedAt,
    required this.items,
  });

  @override
  List<Object?> get props => [
    customerName,
    membershipId,
    year,
    month,
    timezone,
    openingAvailableBalance,
    totalEarnedPoints,
    totalEarnedInr,
    totalRedeemedPoints,
    totalRedeemedInr,
    lockedAllocatedPoints,
    lockedReleasedPoints,
    closingAvailableBalance,
    generatedAt,
    items,
  ];
}

class ExportedStatementResultEntity extends Equatable {
  final StatementExportFormat format;
  final String fileName;
  final String? filePath;
  final Uint8List bytes;
  final MonthlyStatementEntity statement;

  const ExportedStatementResultEntity({
    required this.format,
    required this.fileName,
    required this.filePath,
    required this.bytes,
    required this.statement,
  });

  @override
  List<Object?> get props => [format, fileName, filePath, bytes, statement];
}
