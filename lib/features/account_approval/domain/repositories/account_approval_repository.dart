import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';

abstract class AccountApprovalRepository {
  Future<Either<Failure, CustomerProfileEntity>> ensureCustomerProfile({
    String? fullName,
    String? mobileNumber,
  });

  Future<Either<Failure, CustomerProfileEntity>> fetchCurrentCustomerProfile();
}
