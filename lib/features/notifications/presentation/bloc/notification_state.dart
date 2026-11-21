import 'package:equatable/equatable.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_category.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_entity.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_filter.dart';

enum NotificationStatus {
  initial,
  loading,
  loaded,
  refreshing,
  updating,
  error,
}

class NotificationNavigationIntent extends Equatable {
  final String? route;
  final NotificationScrollTarget scrollTarget;
  final NotificationEntity? campaignDetail;
  final String? unavailableMessage;
  final int sequence;

  const NotificationNavigationIntent({
    this.route,
    this.scrollTarget = NotificationScrollTarget.none,
    this.campaignDetail,
    this.unavailableMessage,
    required this.sequence,
  });

  bool get hasCampaignDetail => campaignDetail != null;
  bool get hasRoute => route != null && route!.isNotEmpty;

  @override
  List<Object?> get props => [
        route,
        scrollTarget,
        campaignDetail,
        unavailableMessage,
        sequence,
      ];
}

class NotificationState extends Equatable {
  final NotificationStatus status;
  final String? activeUserId;
  final NotificationFilter activeFilter;
  final NotificationCountsEntity counts;
  final List<NotificationEntity> notifications;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isFromCache;
  final NotificationRealtimeConnectionState realtimeConnectionState;
  final NotificationNavigationIntent? navigationIntent;
  final String? feedbackMessage;
  final String? errorMessage;
  final bool isFeedbackError;
  final int feedbackSequence;

  const NotificationState({
    this.status = NotificationStatus.initial,
    this.activeUserId,
    this.activeFilter = NotificationFilter.all,
    this.counts = const NotificationCountsEntity(),
    this.notifications = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.isFromCache = false,
    this.realtimeConnectionState =
        NotificationRealtimeConnectionState.disconnected,
    this.navigationIntent,
    this.feedbackMessage,
    this.errorMessage,
    this.isFeedbackError = false,
    this.feedbackSequence = 0,
  });

  int get unreadCount => counts.unread;
  bool get hasUnread => counts.unread > 0;
  bool get isUpdating => status == NotificationStatus.updating;

  NotificationState copyWith({
    NotificationStatus? status,
    String? activeUserId,
    bool clearActiveUserId = false,
    NotificationFilter? activeFilter,
    NotificationCountsEntity? counts,
    List<NotificationEntity>? notifications,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isFromCache,
    NotificationRealtimeConnectionState? realtimeConnectionState,
    NotificationNavigationIntent? navigationIntent,
    bool clearNavigationIntent = false,
    String? feedbackMessage,
    bool clearFeedbackMessage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isFeedbackError,
    int? feedbackSequence,
  }) {
    return NotificationState(
      status: status ?? this.status,
      activeUserId:
          clearActiveUserId ? null : (activeUserId ?? this.activeUserId),
      activeFilter: activeFilter ?? this.activeFilter,
      counts: counts ?? this.counts,
      notifications: notifications ?? this.notifications,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isFromCache: isFromCache ?? this.isFromCache,
      realtimeConnectionState:
          realtimeConnectionState ?? this.realtimeConnectionState,
      navigationIntent: clearNavigationIntent
          ? null
          : (navigationIntent ?? this.navigationIntent),
      feedbackMessage: clearFeedbackMessage
          ? null
          : (feedbackMessage ?? this.feedbackMessage),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isFeedbackError: isFeedbackError ?? this.isFeedbackError,
      feedbackSequence: feedbackSequence ?? this.feedbackSequence,
    );
  }

  @override
  List<Object?> get props => [
        status,
        activeUserId,
        activeFilter,
        counts,
        notifications,
        hasMore,
        isLoadingMore,
        isFromCache,
        realtimeConnectionState,
        navigationIntent,
        feedbackMessage,
        errorMessage,
        isFeedbackError,
        feedbackSequence,
      ];
}
