import 'package:equatable/equatable.dart';
import 'package:shiftex/features/advertisements/domain/entities/advertisement_entity.dart';

/// Enum-driven lifecycle states for the customer promotional ad popup.
enum AdvertisementStatus {
  initial,
  loading,
  showing,
  dismissed,
  empty,
  error,
}

/// Validated one-shot CTA action emitted when the customer clicks a popup CTA.
class AdvertisementPendingCtaAction extends Equatable {
  final String advertisementId;
  final AdvertisementCtaActionType actionType;
  final String? internalRoute;
  final Uri? externalUri;

  const AdvertisementPendingCtaAction({
    required this.advertisementId,
    required this.actionType,
    this.internalRoute,
    this.externalUri,
  });

  @override
  List<Object?> get props => [
    advertisementId,
    actionType,
    internalRoute,
    externalUri,
  ];
}

class AdvertisementState extends Equatable {
  final AdvertisementStatus status;
  final AdvertisementEntity? activeAdvertisement;
  final int remainingSeconds;
  final int totalSeconds;
  final String? activeUserId;
  final String? sessionId;
  final int presentationSequence;
  final AdvertisementPendingCtaAction? pendingCtaAction;
  final int ctaActionSequence;
  final String? errorMessage;

  const AdvertisementState({
    this.status = AdvertisementStatus.initial,
    this.activeAdvertisement,
    this.remainingSeconds = 0,
    this.totalSeconds = 0,
    this.activeUserId,
    this.sessionId,
    this.presentationSequence = 0,
    this.pendingCtaAction,
    this.ctaActionSequence = 0,
    this.errorMessage,
  });

  AdvertisementState copyWith({
    AdvertisementStatus? status,
    AdvertisementEntity? activeAdvertisement,
    bool clearActiveAdvertisement = false,
    int? remainingSeconds,
    int? totalSeconds,
    String? activeUserId,
    String? sessionId,
    int? presentationSequence,
    AdvertisementPendingCtaAction? pendingCtaAction,
    bool clearPendingCtaAction = false,
    int? ctaActionSequence,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AdvertisementState(
      status: status ?? this.status,
      activeAdvertisement:
          clearActiveAdvertisement
              ? null
              : (activeAdvertisement ?? this.activeAdvertisement),
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      activeUserId: activeUserId ?? this.activeUserId,
      sessionId: sessionId ?? this.sessionId,
      presentationSequence: presentationSequence ?? this.presentationSequence,
      pendingCtaAction:
          clearPendingCtaAction
              ? null
              : (pendingCtaAction ?? this.pendingCtaAction),
      ctaActionSequence: ctaActionSequence ?? this.ctaActionSequence,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    activeAdvertisement,
    remainingSeconds,
    totalSeconds,
    activeUserId,
    sessionId,
    presentationSequence,
    pendingCtaAction,
    ctaActionSequence,
    errorMessage,
  ];
}
