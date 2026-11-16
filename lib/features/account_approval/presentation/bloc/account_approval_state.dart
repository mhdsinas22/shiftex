import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';

abstract class AccountApprovalState extends Equatable {
  final CustomerProfileEntity? profile;

  const AccountApprovalState({this.profile});

  @override
  List<Object?> get props => [profile];
}

class AccountApprovalInitial extends AccountApprovalState {
  const AccountApprovalInitial();
}

class AccountApprovalLoading extends AccountApprovalState {
  const AccountApprovalLoading({super.profile});
}

class AccountApprovalLoaded extends AccountApprovalState {
  final CustomerProfileEntity customerProfile;

  const AccountApprovalLoaded(this.customerProfile)
    : super(profile: customerProfile);

  @override
  List<Object?> get props => [customerProfile];
}

class AccountApprovalError extends AccountApprovalState {
  final Failure failure;

  const AccountApprovalError({
    required this.failure,
    super.profile,
  });

  @override
  List<Object?> get props => [failure, profile];
}
