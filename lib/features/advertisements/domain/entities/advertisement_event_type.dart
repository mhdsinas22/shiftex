/// Supported analytics event types recorded for customer promotional popups
/// and consumed by Admin campaign analytics (views, clicks, dismissals, CTR).
enum AdvertisementEventType {
  impression,
  dismissal,
  autoDismissal,
  ctaClick;

  String get rpcValue => switch (this) {
    AdvertisementEventType.impression => 'impression',
    AdvertisementEventType.dismissal => 'dismissal',
    AdvertisementEventType.autoDismissal => 'auto_dismissal',
    AdvertisementEventType.ctaClick => 'cta_click',
  };
}
