import 'package:shiftex/features/advertisements/domain/entities/advertisement_entity.dart';

/// Data transfer & cache model for [AdvertisementEntity], backward-compatible
/// with both existing and extended Admin `advertisements` columns.
class AdvertisementModel extends AdvertisementEntity {
  const AdvertisementModel({
    required super.id,
    required super.title,
    required super.offerDetails,
    super.imageUrl,
    required super.popupDurationSeconds,
    required super.frequencyType,
    required super.frequencyLimit,
    required super.startAt,
    required super.endAt,
    super.status,
    super.deactivatedAt,
    super.ctaLabel,
    super.ctaActionType,
    super.ctaActionValue,
    super.priority,
    super.publishedAt,
    super.serverNow,
  });

  factory AdvertisementModel.fromJson(Map<String, dynamic> json) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final rawTitle =
        (json['title'] as String?) ?? (json['product_name'] as String?) ?? '';
    final rawImage = (json['image_url'] as String?)?.trim();
    final rawStart = json['start_at'] ?? json['start_date'];
    final rawEnd = json['end_at'] ?? json['end_date'];
    final rawFrequencyType = json['frequency_type'] as String?;
    final rawFrequencyLimit =
        (json['frequency_limit'] as num?) ?? (json['frequency_cap'] as num?);
    final rawCtaLabel = (json['cta_label'] as String?)?.trim();
    final rawCtaActionValue = (json['cta_action_value'] as String?)?.trim();

    return AdvertisementModel(
      id: (json['id'] as String?)?.trim() ?? '',
      title: rawTitle.trim(),
      offerDetails: ((json['offer_details'] as String?) ?? '').trim(),
      imageUrl: (rawImage != null && rawImage.isNotEmpty) ? rawImage : null,
      popupDurationSeconds:
          (json['popup_duration_seconds'] as num?)?.toInt() ?? 6,
      frequencyType: AdvertisementFrequencyType.fromString(rawFrequencyType),
      frequencyLimit: rawFrequencyLimit?.toInt() ?? 1,
      startAt:
          DateTime.tryParse(rawStart?.toString() ?? '')?.toUtc() ??
          DateTime.utc(2999),
      endAt: DateTime.tryParse(rawEnd?.toString() ?? '')?.toUtc() ?? epoch,
      // RPC returns only published rows; explicit 'status' is still checked when cached or directly serialized.
      status: AdvertisementCampaignStatus.fromString(
        (json['status'] as String?) ?? 'published',
      ),
      deactivatedAt:
          DateTime.tryParse(json['deactivated_at']?.toString() ?? '')?.toUtc(),
      ctaLabel:
          (rawCtaLabel != null && rawCtaLabel.isNotEmpty) ? rawCtaLabel : null,
      ctaActionType: AdvertisementCtaActionType.fromString(
        json['cta_action_type'] as String?,
      ),
      ctaActionValue:
          (rawCtaActionValue != null && rawCtaActionValue.isNotEmpty)
              ? rawCtaActionValue
              : null,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      publishedAt:
          DateTime.tryParse(json['published_at']?.toString() ?? '')?.toUtc(),
      serverNow:
          DateTime.tryParse(json['server_now']?.toString() ?? '')?.toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'offer_details': offerDetails,
      'image_url': imageUrl,
      'popup_duration_seconds': popupDurationSeconds,
      'frequency_type': frequencyType.rawValue,
      'frequency_limit': frequencyLimit,
      'start_at': startAt.toUtc().toIso8601String(),
      'end_at': endAt.toUtc().toIso8601String(),
      'status': status.name,
      'deactivated_at': deactivatedAt?.toUtc().toIso8601String(),
      'cta_label': ctaLabel,
      'cta_action_type': ctaActionType?.rawValue,
      'cta_action_value': ctaActionValue,
      'priority': priority,
      'published_at': publishedAt?.toUtc().toIso8601String(),
    };
  }
}
