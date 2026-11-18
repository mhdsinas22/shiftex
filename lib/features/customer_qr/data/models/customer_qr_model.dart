import 'package:shiftex/features/customer_qr/domain/entities/customer_qr_entity.dart';

class CustomerQrModel extends CustomerQrEntity {
  const CustomerQrModel({
    required super.customerId,
    required super.fullName,
    required super.membershipId,
    required super.membershipTier,
    required super.tokenId,
    required super.tokenCode,
    required super.qrPayload,
    required super.tokenPurpose,
    required super.allowDeduction,
    required super.status,
    required super.expiresAt,
    required super.createdAt,
  });

  factory CustomerQrModel.fromJson(Map<String, dynamic> json) {
    final fullName = (json['full_name'] as String? ?? '').trim();
    final membershipTier = (json['membership_tier'] as String? ?? '').trim();

    return CustomerQrModel(
      customerId: json['customer_id'] as String? ?? '',
      fullName: fullName.isEmpty ? 'SHIIFTEX Member' : fullName,
      membershipId: (json['membership_id'] as String? ?? '').trim(),
      membershipTier:
          membershipTier.isEmpty ? 'Pebble Black Member' : membershipTier,
      tokenId: json['token_id'] as String? ?? '',
      tokenCode: (json['token_code'] as String? ?? '').trim(),
      qrPayload: (json['qr_payload'] as String? ?? '').trim(),
      tokenPurpose: json['token_purpose'] as String? ?? 'accrual',
      allowDeduction: json['allow_deduction'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
      expiresAt: _parseTimestamp(json['expires_at']),
      createdAt: _parseTimestamp(json['created_at']),
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value).toUtc();
    }
    return DateTime.now().toUtc();
  }
}
