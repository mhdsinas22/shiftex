import 'package:equatable/equatable.dart';

/// Persisted customer impression record used to enforce session, daily,
/// weekly, and per-user frequency caps both online and offline.
class AdvertisementImpressionRecord extends Equatable {
  final String advertisementId;
  final String sessionId;
  final DateTime recordedAt;

  const AdvertisementImpressionRecord({
    required this.advertisementId,
    required this.sessionId,
    required this.recordedAt,
  });

  factory AdvertisementImpressionRecord.fromJson(Map<String, dynamic> json) {
    return AdvertisementImpressionRecord(
      advertisementId: (json['advertisement_id'] as String?) ?? '',
      sessionId: (json['session_id'] as String?) ?? '',
      recordedAt:
          DateTime.tryParse(json['recorded_at']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'advertisement_id': advertisementId,
      'session_id': sessionId,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [advertisementId, sessionId, recordedAt];
}
