import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/home/domain/repositories/home_repository.dart';

class TrackAdvertisementEventParams extends Equatable {
  final String advertisementId;
  final String eventType;
  final String? sessionId;

  const TrackAdvertisementEventParams({
    required this.advertisementId,
    required this.eventType,
    this.sessionId,
  });

  @override
  List<Object?> get props => [advertisementId, eventType, sessionId];
}

class TrackAdvertisementEventUseCase
    implements UseCase<void, TrackAdvertisementEventParams> {
  final HomeRepository _repository;

  const TrackAdvertisementEventUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(TrackAdvertisementEventParams params) {
    return _repository.trackAdvertisementEvent(
      advertisementId: params.advertisementId,
      eventType: params.eventType,
      sessionId: params.sessionId,
    );
  }
}
