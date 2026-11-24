import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/change_phone/domain/entities/change_phone_result_entity.dart';
import 'package:shiftex/features/change_phone/domain/repositories/change_phone_repository.dart';

/// Parameters for updating the authenticated customer's phone number.
class ChangePhoneParams extends Equatable {
  final String newPhoneNumber;
  final String? currentPhoneNumber;

  const ChangePhoneParams({
    required this.newPhoneNumber,
    this.currentPhoneNumber,
  });

  @override
  List<Object?> get props => [newPhoneNumber, currentPhoneNumber];
}

/// Directly updates the authenticated customer's phone number in Supabase
/// `public.profiles.mobile_number` while preserving their existing user UUID.
class ChangePhoneUseCase
    implements UseCase<ChangePhoneResultEntity, ChangePhoneParams> {
  final ChangePhoneRepository _repository;

  const ChangePhoneUseCase(this._repository);

  @override
  Future<Either<Failure, ChangePhoneResultEntity>> call(
    ChangePhoneParams params,
  ) {
    return _repository.changePhoneNumber(
      newPhoneNumber: params.newPhoneNumber,
      currentPhoneNumber: params.currentPhoneNumber,
    );
  }
}
