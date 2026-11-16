import 'package:equatable/equatable.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';

class AuthenticatedUserEntity extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final String mobileNumber;
  final bool isEmailVerified;
  final CustomerProfileEntity? profile;

  const AuthenticatedUserEntity({
    required this.id,
    required this.email,
    required this.fullName,
    required this.mobileNumber,
    required this.isEmailVerified,
    this.profile,
  });

  @override
  List<Object?> get props => [
    id,
    email,
    fullName,
    mobileNumber,
    isEmailVerified,
    profile,
  ];
}
