import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/advertisements/domain/repositories/advertisement_repository.dart';

class ClearAdvertisementSessionParams extends Equatable {
  final String sessionId;

  const ClearAdvertisementSessionParams({required this.sessionId});

  @override
  List<Object?> get props => [sessionId];
}

class ClearAdvertisementSessionUseCase
    implements UseCase<void, ClearAdvertisementSessionParams> {
  final AdvertisementRepository _repository;

  const ClearAdvertisementSessionUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(ClearAdvertisementSessionParams params) {
    return _repository.clearSession(sessionId: params.sessionId);
  }
}
