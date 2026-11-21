import 'package:equatable/equatable.dart';
import 'package:shiftex/core/routes/routes_names.dart';

/// Lifecycle status configured on the Admin advertisements table.
enum AdvertisementCampaignStatus {
  draft,
  published,
  scheduled,
  deactivated,
  unknown;

  static AdvertisementCampaignStatus fromString(String? raw) {
    return switch ((raw ?? '').trim().toLowerCase()) {
      'draft' => AdvertisementCampaignStatus.draft,
      'published' => AdvertisementCampaignStatus.published,
      'scheduled' => AdvertisementCampaignStatus.scheduled,
      'deactivated' => AdvertisementCampaignStatus.deactivated,
      _ => AdvertisementCampaignStatus.unknown,
    };
  }
}

/// Frequency capping window configured on the Admin campaign.
enum AdvertisementFrequencyType {
  oncePerSession,
  oncePerDay,
  oncePerWeek,
  oncePerUser,
  unlimited;

  String get rawValue => switch (this) {
    AdvertisementFrequencyType.oncePerSession => 'once_per_session',
    AdvertisementFrequencyType.oncePerDay => 'once_per_day',
    AdvertisementFrequencyType.oncePerWeek => 'once_per_week',
    AdvertisementFrequencyType.oncePerUser => 'once_per_user',
    AdvertisementFrequencyType.unlimited => 'unlimited',
  };

  static AdvertisementFrequencyType fromString(String? raw) {
    return switch ((raw ?? '').trim().toLowerCase()) {
      'once_per_day' => AdvertisementFrequencyType.oncePerDay,
      'once_per_week' => AdvertisementFrequencyType.oncePerWeek,
      'once_per_user' => AdvertisementFrequencyType.oncePerUser,
      'unlimited' || 'always' => AdvertisementFrequencyType.unlimited,
      _ => AdvertisementFrequencyType.oncePerSession,
    };
  }
}

/// Action type executed when the customer taps a configured CTA button.
enum AdvertisementCtaActionType {
  internalRoute,
  externalUrl;

  String get rawValue => switch (this) {
    AdvertisementCtaActionType.internalRoute => 'internal_route',
    AdvertisementCtaActionType.externalUrl => 'external_url',
  };

  static AdvertisementCtaActionType? fromString(String? raw) {
    return switch ((raw ?? '').trim().toLowerCase()) {
      'internal_route' => AdvertisementCtaActionType.internalRoute,
      'external_url' => AdvertisementCtaActionType.externalUrl,
      _ => null,
    };
  }
}

/// Domain representation of an Admin-published promotional popup advertisement.
class AdvertisementEntity extends Equatable {
  static const Set<String> allowedInternalRoutes = <String>{
    RoutesNames.home,
    RoutesNames.customerQr,
    RoutesNames.claimRewards,
    RoutesNames.activityHistory,
  };

  final String id;
  final String title;
  final String offerDetails;
  final String? imageUrl;
  final int popupDurationSeconds;
  final AdvertisementFrequencyType frequencyType;
  final int frequencyLimit;
  final DateTime startAt;
  final DateTime endAt;
  final AdvertisementCampaignStatus status;
  final DateTime? deactivatedAt;
  final String? ctaLabel;
  final AdvertisementCtaActionType? ctaActionType;
  final String? ctaActionValue;
  final int priority;
  final DateTime? publishedAt;
  final DateTime? serverNow;

  const AdvertisementEntity({
    required this.id,
    required this.title,
    required this.offerDetails,
    this.imageUrl,
    required this.popupDurationSeconds,
    required this.frequencyType,
    required this.frequencyLimit,
    required this.startAt,
    required this.endAt,
    this.status = AdvertisementCampaignStatus.published,
    this.deactivatedAt,
    this.ctaLabel,
    this.ctaActionType,
    this.ctaActionValue,
    this.priority = 0,
    this.publishedAt,
    this.serverNow,
  });

  /// Returns true when the campaign is published, not deactivated, has valid
  /// duration, and [referenceUtc] falls cleanly within `[startAt, endAt]`.
  bool isEligibleAt(DateTime referenceUtc) {
    final checkTime = referenceUtc.toUtc();
    if (id.trim().isEmpty || title.trim().isEmpty) return false;
    if (status != AdvertisementCampaignStatus.published) return false;
    if (deactivatedAt != null) return false;
    if (popupDurationSeconds <= 0) return false;
    if (startAt.toUtc().isAfter(checkTime)) return false;
    if (endAt.toUtc().isBefore(checkTime)) return false;
    return true;
  }

  /// Effective bounded popup duration in seconds.
  int get effectiveDurationSeconds =>
      popupDurationSeconds < 1 ? 6 : popupDurationSeconds;

  /// Effective positive frequency limit within [frequencyType] window.
  int get effectiveFrequencyLimit => frequencyLimit < 1 ? 1 : frequencyLimit;

  /// Returns a validated HTTPS image URI string or null when absent/unsafe.
  String? get validatedImageUrl {
    final raw = imageUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !uri.hasScheme ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.trim().isEmpty) {
      return null;
    }
    return uri.toString();
  }

  /// Validates configured internal route destination against known customer routes.
  String? get resolvedInternalRoute {
    if (ctaActionType != AdvertisementCtaActionType.internalRoute) return null;
    final raw = (ctaActionValue ?? '').trim();
    if (raw.isEmpty) return null;
    final normalized = raw.startsWith('/') ? raw : '/$raw';
    return allowedInternalRoutes.contains(normalized) ? normalized : null;
  }

  /// Validates configured external destination URL strictly allowing HTTPS URLs.
  Uri? get resolvedExternalUri {
    if (ctaActionType != AdvertisementCtaActionType.externalUrl) return null;
    final raw = (ctaActionValue ?? '').trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !uri.hasScheme ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.trim().isEmpty) {
      return null;
    }
    return uri;
  }

  /// True only when the Admin explicitly configured both a CTA label and a valid action.
  bool get hasConfiguredCta {
    final label = ctaLabel?.trim() ?? '';
    if (label.isEmpty || ctaActionType == null) return false;
    return resolvedInternalRoute != null || resolvedExternalUri != null;
  }

  @override
  List<Object?> get props => [
    id,
    title,
    offerDetails,
    imageUrl,
    popupDurationSeconds,
    frequencyType,
    frequencyLimit,
    startAt,
    endAt,
    status,
    deactivatedAt,
    ctaLabel,
    ctaActionType,
    ctaActionValue,
    priority,
    publishedAt,
    serverNow,
  ];
}
