import 'package:equatable/equatable.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_category.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_entity.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_filter.dart';

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

class NotificationsStarted extends NotificationEvent {
  final String userId;

  const NotificationsStarted(this.userId);

  @override
  List<Object?> get props => [userId];
}

class NotificationsStopped extends NotificationEvent {
  const NotificationsStopped();
}

class NotificationsLoadRequested extends NotificationEvent {
  final NotificationFilter? filter;
  final bool syncCampaigns;

  const NotificationsLoadRequested({
    this.filter,
    this.syncCampaigns = false,
  });

  @override
  List<Object?> get props => [filter, syncCampaigns];
}

class NotificationsRefreshed extends NotificationEvent {
  const NotificationsRefreshed();
}

class NotificationsLoadMoreRequested extends NotificationEvent {
  const NotificationsLoadMoreRequested();
}

class NotificationFilterChanged extends NotificationEvent {
  final NotificationFilter filter;

  const NotificationFilterChanged(this.filter);

  @override
  List<Object?> get props => [filter];
}

class NotificationMarkedAsRead extends NotificationEvent {
  final String notificationId;

  const NotificationMarkedAsRead(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

class NotificationOpened extends NotificationEvent {
  final NotificationEntity notification;

  const NotificationOpened(this.notification);

  @override
  List<Object?> get props => [notification];
}

class NotificationsAllMarkedAsRead extends NotificationEvent {
  const NotificationsAllMarkedAsRead();
}

class NotificationRealtimeReceived extends NotificationEvent {
  final NotificationRealtimeEvent realtimeEvent;

  const NotificationRealtimeReceived(this.realtimeEvent);

  @override
  List<Object?> get props => [realtimeEvent];
}

class NotificationRealtimeStatusChanged extends NotificationEvent {
  final NotificationRealtimeConnectionState connectionState;

  const NotificationRealtimeStatusChanged(this.connectionState);

  @override
  List<Object?> get props => [connectionState];
}

class NotificationUnreadCountRequested extends NotificationEvent {
  const NotificationUnreadCountRequested();
}

class NotificationNavigationHandled extends NotificationEvent {
  const NotificationNavigationHandled();
}

class NotificationFeedbackCleared extends NotificationEvent {
  const NotificationFeedbackCleared();
}
