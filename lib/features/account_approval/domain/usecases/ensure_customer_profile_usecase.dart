import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';
import 'package:shiftex/features/account_approval/domain/repositories/account_approval_repository.dart';

class EnsureCustomerProfileParams extends Equatable {
  final String? fullName;
  final String? mobileNumber;

  const EnsureCustomerProfileParams({
    this.fullName,
    this.mobileNumber,
  });

  @override
  List<Object?> get props => [fullName, mobileNumber];
}

class EnsureCustomerProfileUseCase
    implements UseCase<CustomerProfileEntity, EnsureCustomerProfileParams> {
  final AccountApprovalRepository _repository;

  const EnsureCustomerProfileUseCase(this._repository);

  @override
  Future<Either<Failure, CustomerProfileEntity>> call(
    EnsureCustomerProfileParams params,
  ) {
    return _repository.ensureCustomerProfile(
      fullName: params.fullName,
      mobileNumber: params.mobileNumber,
    );
  }
}
