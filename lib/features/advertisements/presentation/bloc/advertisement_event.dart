import 'package:equatable/equatable.dart';

abstract class AdvertisementEvent extends Equatable {
  const AdvertisementEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched when an approved customer session becomes active on app startup
/// or post-login. Repeated calls for the same active session are ignored.
class AdvertisementSessionStarted extends AdvertisementEvent {
  final String userId;
  final bool forceNewSession;

  const AdvertisementSessionStarted({
    required this.userId,
    this.forceNewSession = false,
  });

  @override
  List<Object?> get props => [userId, forceNewSession];
}

/// Dispatched when the customer logs out, switches accounts, or loses approval.
class AdvertisementSessionEnded extends AdvertisementEvent {
  const AdvertisementSessionEnded();
}

/// Internal countdown tick triggered once per second while popup is open.
class AdvertisementCountdownTicked extends AdvertisementEvent {
  const AdvertisementCountdownTicked();
}

/// Dispatched when the customer taps Close or system Back to dismiss the popup.
class AdvertisementDismissRequested extends AdvertisementEvent {
  const AdvertisementDismissRequested();
}

/// Dispatched when the customer taps the popup's configured CTA button.
class AdvertisementCtaPressed extends AdvertisementEvent {
  const AdvertisementCtaPressed();
}

/// Marks a pending CTA navigation action as handled so listeners don't replay it.
class AdvertisementPendingActionHandled extends AdvertisementEvent {
  const AdvertisementPendingActionHandled();
}
