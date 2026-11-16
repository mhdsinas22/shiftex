import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';
import 'package:shiftex/features/authentication/domain/repositories/authentication_repository.dart';

class GetCurrentSessionProfileUseCase
    implements UseCase<CustomerProfileEntity?, NoParams> {
  final AuthenticationRepository _repository;

  const GetCurrentSessionProfileUseCase(this._repository);

  @override
  Future<Either<Failure, CustomerProfileEntity?>> call(NoParams params) {
    return _repository.getCurrentSessionProfile();
  }
}
