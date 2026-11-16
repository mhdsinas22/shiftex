import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';
import 'package:shiftex/features/account_approval/domain/repositories/account_approval_repository.dart';

class GetApprovalStatusUseCase
    implements UseCase<CustomerProfileEntity, NoParams> {
  final AccountApprovalRepository _repository;

  const GetApprovalStatusUseCase(this._repository);

  @override
  Future<Either<Failure, CustomerProfileEntity>> call(NoParams params) {
    return _repository.fetchCurrentCustomerProfile();
  }
}
