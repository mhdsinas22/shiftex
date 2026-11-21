import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/advertisements/domain/entities/advertisement_entity.dart';
import 'package:shiftex/features/advertisements/domain/repositories/advertisement_repository.dart';

class GetEligibleAdvertisementParams extends Equatable {
  final String userId;
  final String sessionId;
  final DateTime? nowOverride;

  const GetEligibleAdvertisementParams({
    required this.userId,
    required this.sessionId,
    this.nowOverride,
  });

  @override
  List<Object?> get props => [userId, sessionId, nowOverride];
}

class GetEligibleAdvertisementUseCase
    implements UseCase<AdvertisementEntity?, GetEligibleAdvertisementParams> {
  final AdvertisementRepository _repository;

  const GetEligibleAdvertisementUseCase(this._repository);

  @override
  Future<Either<Failure, AdvertisementEntity?>> call(
    GetEligibleAdvertisementParams params,
  ) {
    return _repository.getEligibleAdvertisement(
      userId: params.userId,
      sessionId: params.sessionId,
      nowOverride: params.nowOverride,
    );
  }
}
