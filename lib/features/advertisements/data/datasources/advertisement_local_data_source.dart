import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shiftex/features/advertisements/data/models/advertisement_model.dart';
import 'package:shiftex/features/advertisements/domain/entities/advertisement_entity.dart';
import 'package:shiftex/features/advertisements/domain/entities/advertisement_impression_record.dart';

/// Abstraction over key-value persistence so unit tests run deterministically
/// without platform keychain plugins while production persists via SecureStorage.
abstract class AdKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureAdKeyValueStore implements AdKeyValueStore {
  final FlutterSecureStorage _storage;
  final Map<String, String> _memoryFallback = <String, String>{};

  SecureAdKeyValueStore(this._storage);

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key) ?? _memoryFallback[key];
    } catch (_) {
      return _memoryFallback[key];
    }
  }

  @override
  Future<void> write(String key, String value) async {
    _memoryFallback[key] = value;
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // Fail gracefully when keychain is unavailable (e.g., headless tests).
    }
  }

  @override
  Future<void> delete(String key) async {
    _memoryFallback.remove(key);
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}

class PendingAdAnalyticsEvent {
  final String advertisementId;
  final String eventType;
  final String sessionId;
  final Map<String, dynamic> metadata;

  const PendingAdAnalyticsEvent({
    required this.advertisementId,
    required this.eventType,
    required this.sessionId,
    required this.metadata,
  });

  factory PendingAdAnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return PendingAdAnalyticsEvent(
      advertisementId: (json['advertisement_id'] as String?) ?? '',
      eventType: (json['event_type'] as String?) ?? '',
      sessionId: (json['session_id'] as String?) ?? '',
      metadata:
          json['metadata'] is Map
              ? Map<String, dynamic>.from(json['metadata'] as Map)
              : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'advertisement_id': advertisementId,
      'event_type': eventType,
      'session_id': sessionId,
      'metadata': metadata,
    };
  }
}

abstract class AdvertisementLocalDataSource {
  bool hasEvaluatedSession(String sessionId);
  void markSessionEvaluated(String sessionId);
  void clearSession(String sessionId);

  Future<void> cacheAdvertisements({
    required String userId,
    required List<AdvertisementModel> advertisements,
    required DateTime cachedAtUtc,
  });

  Future<List<AdvertisementModel>> getCachedAdvertisements({
    required String userId,
    required DateTime referenceUtc,
  });

  Future<bool> isWithinFrequencyCap({
    required AdvertisementEntity advertisement,
    required String userId,
    required String sessionId,
    required DateTime referenceUtc,
  });

  Future<void> recordLocalImpression({
    required String userId,
    required String advertisementId,
    required String sessionId,
    required DateTime recordedAtUtc,
  });

  Future<void> enqueuePendingEvent({
    required String userId,
    required PendingAdAnalyticsEvent event,
  });

  Future<List<PendingAdAnalyticsEvent>> getPendingEvents({
    required String userId,
  });

  Future<void> replacePendingEvents({
    required String userId,
    required List<PendingAdAnalyticsEvent> remaining,
  });
}

class AdvertisementLocalDataSourceImpl implements AdvertisementLocalDataSource {
  static const Duration cacheTtl = Duration(hours: 6);
  static const String _cachePrefix = 'shiiftex_ad_cache_v1_';
  static const String _freqPrefix = 'shiiftex_ad_freq_v1_';
  static const String _lifetimePrefix = 'shiiftex_ad_lifetime_v1_';
  static const String _pendingPrefix = 'shiiftex_ad_pending_v1_';

  final AdKeyValueStore _store;

  final Set<String> _evaluatedSessions = <String>{};
  final Map<String, List<AdvertisementImpressionRecord>> _sessionImpressions =
      <String, List<AdvertisementImpressionRecord>>{};

  AdvertisementLocalDataSourceImpl(this._store);

  @override
  bool hasEvaluatedSession(String sessionId) =>
      _evaluatedSessions.contains(sessionId);

  @override
  void markSessionEvaluated(String sessionId) {
    if (sessionId.trim().isEmpty) return;
    _evaluatedSessions.add(sessionId);
  }

  @override
  void clearSession(String sessionId) {
    _evaluatedSessions.remove(sessionId);
    _sessionImpressions.remove(sessionId);
  }

  @override
  Future<void> cacheAdvertisements({
    required String userId,
    required List<AdvertisementModel> advertisements,
    required DateTime cachedAtUtc,
  }) async {
    final payload = jsonEncode({
      'cached_at': cachedAtUtc.toUtc().toIso8601String(),
      'items': advertisements.map((e) => e.toJson()).toList(),
    });
    await _store.write('$_cachePrefix$userId', payload);
  }

  @override
  Future<List<AdvertisementModel>> getCachedAdvertisements({
    required String userId,
    required DateTime referenceUtc,
  }) async {
    final raw = await _store.read('$_cachePrefix$userId');
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      final cachedAt =
          DateTime.tryParse(decoded['cached_at']?.toString() ?? '')?.toUtc();
      if (cachedAt == null ||
          referenceUtc.toUtc().difference(cachedAt) > cacheTtl) {
        return const [];
      }
      final items = decoded['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map(
            (row) => AdvertisementModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .where((ad) => ad.isEligibleAt(referenceUtc))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<AdvertisementImpressionRecord>> _readRecentRecords(
    String userId,
  ) async {
    final raw = await _store.read('$_freqPrefix$userId');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (e) => AdvertisementImpressionRecord.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .where((r) => r.advertisementId.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, int>> _readLifetimeCounts(String userId) async {
    final raw = await _store.read('$_lifetimePrefix$userId');
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
      );
    } catch (_) {
      return <String, int>{};
    }
  }

  @override
  Future<bool> isWithinFrequencyCap({
    required AdvertisementEntity advertisement,
    required String userId,
    required String sessionId,
    required DateTime referenceUtc,
  }) async {
    final limit = advertisement.effectiveFrequencyLimit;
    final ref = referenceUtc.toUtc();

    switch (advertisement.frequencyType) {
      case AdvertisementFrequencyType.unlimited:
        return true;

      case AdvertisementFrequencyType.oncePerSession:
        final sessionCount =
            (_sessionImpressions[sessionId] ?? const [])
                .where((r) => r.advertisementId == advertisement.id)
                .length;
        return sessionCount < limit;

      case AdvertisementFrequencyType.oncePerDay:
        final records = await _readRecentRecords(userId);
        final windowStart = ref.subtract(const Duration(hours: 24));
        final dayCount =
            records
                .where(
                  (r) =>
                      r.advertisementId == advertisement.id &&
                      !r.recordedAt.isBefore(windowStart),
                )
                .length;
        return dayCount < limit;

      case AdvertisementFrequencyType.oncePerWeek:
        final records = await _readRecentRecords(userId);
        final windowStart = ref.subtract(const Duration(days: 7));
        final weekCount =
            records
                .where(
                  (r) =>
                      r.advertisementId == advertisement.id &&
                      !r.recordedAt.isBefore(windowStart),
                )
                .length;
        return weekCount < limit;

      case AdvertisementFrequencyType.oncePerUser:
        final counts = await _readLifetimeCounts(userId);
        return (counts[advertisement.id] ?? 0) < limit;
    }
  }

  @override
  Future<void> recordLocalImpression({
    required String userId,
    required String advertisementId,
    required String sessionId,
    required DateTime recordedAtUtc,
  }) async {
    final now = recordedAtUtc.toUtc();
    final record = AdvertisementImpressionRecord(
      advertisementId: advertisementId,
      sessionId: sessionId,
      recordedAt: now,
    );

    final sessionList = _sessionImpressions.putIfAbsent(
      sessionId,
      () => <AdvertisementImpressionRecord>[],
    );
    sessionList.add(record);

    final pruneCutoff = now.subtract(const Duration(days: 30));
    final existing = await _readRecentRecords(userId);
    final updated = [
      ...existing.where((r) => !r.recordedAt.isBefore(pruneCutoff)),
      record,
    ];
    await _store.write(
      '$_freqPrefix$userId',
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );

    final counts = await _readLifetimeCounts(userId);
    counts[advertisementId] = (counts[advertisementId] ?? 0) + 1;
    await _store.write('$_lifetimePrefix$userId', jsonEncode(counts));
  }

  @override
  Future<void> enqueuePendingEvent({
    required String userId,
    required PendingAdAnalyticsEvent event,
  }) async {
    final existing = await getPendingEvents(userId: userId);
    final updated = [...existing, event];
    final capped =
        updated.length > 50 ? updated.sublist(updated.length - 50) : updated;
    await _store.write(
      '$_pendingPrefix$userId',
      jsonEncode(capped.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<List<PendingAdAnalyticsEvent>> getPendingEvents({
    required String userId,
  }) async {
    final raw = await _store.read('$_pendingPrefix$userId');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (e) =>
                PendingAdAnalyticsEvent.fromJson(Map<String, dynamic>.from(e)),
          )
          .where((e) => e.advertisementId.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> replacePendingEvents({
    required String userId,
    required List<PendingAdAnalyticsEvent> remaining,
  }) async {
    if (remaining.isEmpty) {
      await _store.delete('$_pendingPrefix$userId');
      return;
    }
    await _store.write(
      '$_pendingPrefix$userId',
      jsonEncode(remaining.map((e) => e.toJson()).toList()),
    );
  }
}
