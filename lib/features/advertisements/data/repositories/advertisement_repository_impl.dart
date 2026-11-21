import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/error_mapper.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/advertisements/data/datasources/advertisement_local_data_source.dart';
import 'package:shiftex/features/advertisements/data/datasources/advertisement_remote_data_source.dart';
import 'package:shiftex/features/advertisements/data/models/advertisement_model.dart';
import 'package:shiftex/features/advertisements/domain/entities/advertisement_entity.dart';
import 'package:shiftex/features/advertisements/domain/entities/advertisement_event_type.dart';
import 'package:shiftex/features/advertisements/domain/repositories/advertisement_repository.dart';

class AdvertisementRepositoryImpl implements AdvertisementRepository {
  final AdvertisementRemoteDataSource _remoteDataSource;
  final AdvertisementLocalDataSource _localDataSource;

  const AdvertisementRepositoryImpl({
    required AdvertisementRemoteDataSource remoteDataSource,
    required AdvertisementLocalDataSource localDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource;

  @override
  Future<Either<Failure, AdvertisementEntity?>> getEligibleAdvertisement({
    required String userId,
    required String sessionId,
    DateTime? nowOverride,
  }) async {
    if (userId.trim().isEmpty || sessionId.trim().isEmpty) {
      return const Right(null);
    }

    if (_localDataSource.hasEvaluatedSession(sessionId)) {
      return const Right(null);
    }

    final refNow = (nowOverride ?? DateTime.now()).toUtc();

    try {
      await _flushPendingEvents(userId);
      final remoteAds = await _remoteDataSource.fetchActiveAdvertisements(
        userId: userId,
        sessionId: sessionId,
      );

      final referenceTime =
          remoteAds
              .map((ad) => ad.serverNow)
              .whereType<DateTime>()
              .firstOrNull ??
          refNow;

      await _localDataSource.cacheAdvertisements(
        userId: userId,
        advertisements: remoteAds,
        cachedAtUtc: referenceTime,
      );

      final selected = await _selectBestEligible(
        candidates: remoteAds,
        userId: userId,
        sessionId: sessionId,
        referenceUtc: referenceTime,
      );
      _localDataSource.markSessionEvaluated(sessionId);
      return Right(selected);
    } catch (error) {
      final failure = ErrorMapper.mapExceptionToFailure(error);
      if (failure is SessionExpiredFailure) {
        return Left(failure);
      }

      // Offline / transient network fallback using verified cached active ads.
      final cached = await _localDataSource.getCachedAdvertisements(
        userId: userId,
        referenceUtc: refNow,
      );
      if (cached.isNotEmpty) {
        final selected = await _selectBestEligible(
          candidates: cached,
          userId: userId,
          sessionId: sessionId,
          referenceUtc: refNow,
        );
        _localDataSource.markSessionEvaluated(sessionId);
        return Right(selected);
      }

      return Left(failure);
    }
  }

  Future<AdvertisementEntity?> _selectBestEligible({
    required List<AdvertisementModel> candidates,
    required String userId,
    required String sessionId,
    required DateTime referenceUtc,
  }) async {
    final eligible = <AdvertisementModel>[];
    for (final ad in candidates) {
      final effectiveRef = ad.serverNow ?? referenceUtc;
      if (!ad.isEligibleAt(effectiveRef)) continue;
      final allowedByCap = await _localDataSource.isWithinFrequencyCap(
        advertisement: ad,
        userId: userId,
        sessionId: sessionId,
        referenceUtc: effectiveRef,
      );
      if (allowedByCap) {
        eligible.add(ad);
      }
    }

    if (eligible.isEmpty) return null;

    eligible.sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      if (byPriority != 0) return byPriority;
      final aPublished = (a.publishedAt ?? a.startAt).toUtc();
      final bPublished = (b.publishedAt ?? b.startAt).toUtc();
      final byPublished = bPublished.compareTo(aPublished);
      if (byPublished != 0) return byPublished;
      return b.id.compareTo(a.id);
    });

    return eligible.first;
  }

  @override
  Future<Either<Failure, void>> recordEvent({
    required String userId,
    required String advertisementId,
    required AdvertisementEventType eventType,
    required String sessionId,
    required int presentationSequence,
    Map<String, dynamic>? metadata,
    DateTime? nowOverride,
  }) async {
    if (userId.trim().isEmpty ||
        advertisementId.trim().isEmpty ||
        sessionId.trim().isEmpty) {
      return const Right(null);
    }

    final now = (nowOverride ?? DateTime.now()).toUtc();
    if (eventType == AdvertisementEventType.impression) {
      await _localDataSource.recordLocalImpression(
        userId: userId,
        advertisementId: advertisementId,
        sessionId: sessionId,
        recordedAtUtc: now,
      );
    }

    final idempotencyKey =
        '$sessionId:$advertisementId:${eventType.rpcValue}:$presentationSequence';
    final enrichedMetadata = <String, dynamic>{
      ...?metadata,
      'idempotency_key': idempotencyKey,
      'recorded_client_at': now.toIso8601String(),
    };

    try {
      await _remoteDataSource.trackEvent(
        advertisementId: advertisementId,
        eventType: eventType,
        sessionId: sessionId,
        metadata: enrichedMetadata,
      );
      await _flushPendingEvents(userId);
      return const Right(null);
    } catch (error) {
      await _localDataSource.enqueuePendingEvent(
        userId: userId,
        event: PendingAdAnalyticsEvent(
          advertisementId: advertisementId,
          eventType: eventType.rpcValue,
          sessionId: sessionId,
          metadata: enrichedMetadata,
        ),
      );
      return Left(ErrorMapper.mapExceptionToFailure(error));
    }
  }

  Future<void> _flushPendingEvents(String userId) async {
    final pending = await _localDataSource.getPendingEvents(userId: userId);
    if (pending.isEmpty) return;

    final remaining = <PendingAdAnalyticsEvent>[];
    for (int i = 0; i < pending.length; i++) {
      final item = pending[i];
      final type = AdvertisementEventType.values.where(
        (t) => t.rpcValue == item.eventType,
      );
      if (type.isEmpty) continue;
      try {
        await _remoteDataSource.trackEvent(
          advertisementId: item.advertisementId,
          eventType: type.first,
          sessionId: item.sessionId,
          metadata: item.metadata,
        );
      } catch (_) {
        remaining.addAll(pending.sublist(i));
        break;
      }
    }
    await _localDataSource.replacePendingEvents(
      userId: userId,
      remaining: remaining,
    );
  }

  @override
  Future<Either<Failure, void>> clearSession({required String sessionId}) async {
    _localDataSource.clearSession(sessionId);
    return const Right(null);
  }
}
