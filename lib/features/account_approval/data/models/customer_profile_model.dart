import 'package:shiftex/features/account_approval/domain/entities/approval_status.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';

class CustomerProfileModel extends CustomerProfileEntity {
  const CustomerProfileModel({
    required super.id,
    required super.fullName,
    required super.email,
    required super.mobileNumber,
    required super.approvalStatus,
    super.approvedBy,
    super.approvedAt,
    super.rejectionReason,
    required super.createdAt,
    required super.updatedAt,
  });

  factory CustomerProfileModel.fromJson(Map<String, dynamic> json) {
    return CustomerProfileModel(
      id: json['id'] as String,
      fullName: (json['full_name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      mobileNumber: (json['mobile_number'] as String?) ?? '',
      approvalStatus: AccountApprovalStatus.fromString(
        json['approval_status'] as String?,
      ),
      approvedBy: json['approved_by'] as String?,
      approvedAt:
          json['approved_at'] != null
              ? DateTime.tryParse(json['approved_at'].toString())
              : null,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'mobile_number': mobileNumber,
      'approval_status': approvalStatus.value,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
