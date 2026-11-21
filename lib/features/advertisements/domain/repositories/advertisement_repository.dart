import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/advertisements/domain/entities/advertisement_entity.dart';
import 'package:shiftex/features/advertisements/domain/entities/advertisement_event_type.dart';

/// Contract for fetching eligible published customer advertisements, enforcing
/// frequency caps with offline cache support, and recording analytics events.
abstract class AdvertisementRepository {
  Future<Either<Failure, AdvertisementEntity?>> getEligibleAdvertisement({
    required String userId,
    required String sessionId,
    DateTime? nowOverride,
  });

  Future<Either<Failure, void>> recordEvent({
    required String userId,
    required String advertisementId,
    required AdvertisementEventType eventType,
    required String sessionId,
    required int presentationSequence,
    Map<String, dynamic>? metadata,
    DateTime? nowOverride,
  });

  Future<Either<Failure, void>> clearSession({required String sessionId});
}
