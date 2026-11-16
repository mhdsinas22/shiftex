import 'package:equatable/equatable.dart';
import 'package:shiftex/features/account_approval/domain/entities/approval_status.dart';

class CustomerProfileEntity extends Equatable {
  final String id;
  final String fullName;
  final String email;
  final String mobileNumber;
  final AccountApprovalStatus approvalStatus;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomerProfileEntity({
    required this.id,
    required this.fullName,
    required this.email,
    required this.mobileNumber,
    required this.approvalStatus,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isApproved => approvalStatus == AccountApprovalStatus.approved;
  bool get isPending => approvalStatus == AccountApprovalStatus.pending;
  bool get isRejected => approvalStatus == AccountApprovalStatus.rejected;
  bool get isSuspended => approvalStatus == AccountApprovalStatus.suspended;

  @override
  List<Object?> get props => [
    id,
    fullName,
    email,
    mobileNumber,
    approvalStatus,
    approvedBy,
    approvedAt,
    rejectionReason,
    createdAt,
    updatedAt,
  ];
}
