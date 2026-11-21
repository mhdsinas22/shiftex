import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/advertisements/domain/entities/advertisement_event_type.dart';
import 'package:shiftex/features/advertisements/domain/repositories/advertisement_repository.dart';

class TrackAdvertisementAnalyticsParams extends Equatable {
  final String userId;
  final String advertisementId;
  final AdvertisementEventType eventType;
  final String sessionId;
  final int presentationSequence;
  final Map<String, dynamic>? metadata;
  final DateTime? nowOverride;

  const TrackAdvertisementAnalyticsParams({
    required this.userId,
    required this.advertisementId,
    required this.eventType,
    required this.sessionId,
    required this.presentationSequence,
    this.metadata,
    this.nowOverride,
  });

  @override
  List<Object?> get props => [
    userId,
    advertisementId,
    eventType,
    sessionId,
    presentationSequence,
    metadata,
    nowOverride,
  ];
}

class TrackAdvertisementAnalyticsUseCase
    implements UseCase<void, TrackAdvertisementAnalyticsParams> {
  final AdvertisementRepository _repository;

  const TrackAdvertisementAnalyticsUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(TrackAdvertisementAnalyticsParams params) {
    return _repository.recordEvent(
      userId: params.userId,
      advertisementId: params.advertisementId,
      eventType: params.eventType,
      sessionId: params.sessionId,
      presentationSequence: params.presentationSequence,
      metadata: params.metadata,
      nowOverride: params.nowOverride,
    );
  }
}
