import 'package:equatable/equatable.dart';

/// Domain entity representing the customer's accrual-only personal QR pass.
class CustomerQrEntity extends Equatable {
  final String customerId;
  final String fullName;
  final String membershipId;
  final String membershipTier;
  final String tokenId;
  final String tokenCode;
  final String qrPayload;
  final String tokenPurpose;
  final bool allowDeduction;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;

  const CustomerQrEntity({
    required this.customerId,
    required this.fullName,
    required this.membershipId,
    required this.membershipTier,
    required this.tokenId,
    required this.tokenCode,
    required this.qrPayload,
    required this.tokenPurpose,
    required this.allowDeduction,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
  });

  /// Ensures this pass is strictly accrual-only and cannot charge or deduct points.
  bool get isAccrualOnly => tokenPurpose == 'accrual' && !allowDeduction;

  bool isExpiredAt(DateTime now) {
    return status == 'expired' ||
        status == 'revoked' ||
        status == 'used' ||
        !expiresAt.isAfter(now);
  }

  bool get isCurrentlyExpired => isExpiredAt(DateTime.now().toUtc());

  Duration remainingAt(DateTime now) {
    if (isExpiredAt(now)) {
      return Duration.zero;
    }
    return expiresAt.difference(now);
  }

  @override
  List<Object?> get props => [
    customerId,
    fullName,
    membershipId,
    membershipTier,
    tokenId,
    tokenCode,
    qrPayload,
    tokenPurpose,
    allowDeduction,
    status,
    expiresAt,
    createdAt,
  ];
}
