import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_category.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_entity.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_filter.dart';
import 'package:shiftex/features/notifications/domain/usecases/get_notifications_usecase.dart';
import 'package:shiftex/features/notifications/domain/usecases/get_unread_notification_count_usecase.dart';
import 'package:shiftex/features/notifications/domain/usecases/mark_all_notifications_read_usecase.dart';
import 'package:shiftex/features/notifications/domain/usecases/mark_notification_read_usecase.dart';
import 'package:shiftex/features/notifications/domain/usecases/watch_notifications_realtime_usecase.dart';
import 'package:shiftex/features/notifications/presentation/bloc/notification_event.dart';
import 'package:shiftex/features/notifications/presentation/bloc/notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  static const int defaultPageSize = 20;

  final GetNotificationsUseCase _getNotificationsUseCase;
  final MarkNotificationReadUseCase _markNotificationReadUseCase;
  final MarkAllNotificationsReadUseCase _markAllNotificationsReadUseCase;
  final GetUnreadNotificationCountUseCase _getUnreadNotificationCountUseCase;
  final WatchNotificationsRealtimeUseCase _watchNotificationsRealtimeUseCase;

  StreamSubscription<NotificationRealtimeEvent>? _realtimeSub;
  StreamSubscription<NotificationRealtimeConnectionState>? _connectionSub;
  int _navSeq = 0;

  NotificationBloc({
    required GetNotificationsUseCase getNotificationsUseCase,
    required MarkNotificationReadUseCase markNotificationReadUseCase,
    required MarkAllNotificationsReadUseCase markAllNotificationsReadUseCase,
    required GetUnreadNotificationCountUseCase getUnreadNotificationCountUseCase,
    required WatchNotificationsRealtimeUseCase watchNotificationsRealtimeUseCase,
  })  : _getNotificationsUseCase = getNotificationsUseCase,
        _markNotificationReadUseCase = markNotificationReadUseCase,
        _markAllNotificationsReadUseCase = markAllNotificationsReadUseCase,
        _getUnreadNotificationCountUseCase = getUnreadNotificationCountUseCase,
        _watchNotificationsRealtimeUseCase = watchNotificationsRealtimeUseCase,
        super(const NotificationState()) {
    on<NotificationsStarted>(_onStarted);
    on<NotificationsStopped>(_onStopped);
    on<NotificationsLoadRequested>(_onLoadRequested);
    on<NotificationsRefreshed>(_onRefreshed);
    on<NotificationsLoadMoreRequested>(_onLoadMoreRequested);
    on<NotificationFilterChanged>(_onFilterChanged);
    on<NotificationMarkedAsRead>(_onMarkedAsRead);
    on<NotificationOpened>(_onNotificationOpened);
    on<NotificationsAllMarkedAsRead>(_onAllMarkedAsRead);
    on<NotificationRealtimeReceived>(_onRealtimeReceived);
    on<NotificationRealtimeStatusChanged>(_onRealtimeStatusChanged);
    on<NotificationUnreadCountRequested>(_onUnreadCountRequested);
    on<NotificationNavigationHandled>(_onNavigationHandled);
    on<NotificationFeedbackCleared>(_onFeedbackCleared);
  }

  Future<void> _onStarted(
    NotificationsStarted event,
    Emitter<NotificationState> emit,
  ) async {
    final trimmedUserId = event.userId.trim();
    if (trimmedUserId.isEmpty) return;

    if (state.activeUserId == trimmedUserId && _realtimeSub != null) {
      add(const NotificationUnreadCountRequested());
      return;
    }

    final previousUserId = state.activeUserId;
    await _cancelSubscriptions();
    if (previousUserId != null && previousUserId != trimmedUserId) {
      await _watchNotificationsRealtimeUseCase.stop(userId: previousUserId);
      emit(const NotificationState());
    }

    emit(
      state.copyWith(
        activeUserId: trimmedUserId,
        clearErrorMessage: true,
      ),
    );

    try {
      _connectionSub = _watchNotificationsRealtimeUseCase
          .connectionStateStream
          .listen(
            (connState) => add(NotificationRealtimeStatusChanged(connState)),
          );
      _realtimeSub = _watchNotificationsRealtimeUseCase(
        userId: trimmedUserId,
      ).listen(
        (rtEvent) => add(NotificationRealtimeReceived(rtEvent)),
        onError: (_) => add(
          const NotificationRealtimeStatusChanged(
            NotificationRealtimeConnectionState.error,
          ),
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          realtimeConnectionState: NotificationRealtimeConnectionState.error,
        ),
      );
    }

    await _loadNotifications(
      emit: emit,
      filter: state.activeFilter,
      syncCampaigns: true,
      isRefresh: false,
    );
  }

  Future<void> _onStopped(
    NotificationsStopped event,
    Emitter<NotificationState> emit,
  ) async {
    final previousUserId = state.activeUserId;
    await _cancelSubscriptions();
    await _watchNotificationsRealtimeUseCase.stop(userId: previousUserId);
    emit(const NotificationState());
  }

  Future<void> _onLoadRequested(
    NotificationsLoadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    await _loadNotifications(
      emit: emit,
      filter: event.filter ?? state.activeFilter,
      syncCampaigns: event.syncCampaigns,
      isRefresh: false,
    );
  }

  Future<void> _onRefreshed(
    NotificationsRefreshed event,
    Emitter<NotificationState> emit,
  ) async {
    await _loadNotifications(
      emit: emit,
      filter: state.activeFilter,
      syncCampaigns: true,
      isRefresh: true,
    );
  }

  Future<void> _onFilterChanged(
    NotificationFilterChanged event,
    Emitter<NotificationState> emit,
  ) async {
    if (event.filter == state.activeFilter &&
        state.status == NotificationStatus.loaded &&
        !state.isFromCache) {
      return;
    }

    emit(
      state.copyWith(
        activeFilter: event.filter,
        isLoadingMore: false,
      ),
    );

    await _loadNotifications(
      emit: emit,
      filter: event.filter,
      syncCampaigns: false,
      isRefresh: state.notifications.isNotEmpty,
    );
  }

  Future<void> _loadNotifications({
    required Emitter<NotificationState> emit,
    required NotificationFilter filter,
    required bool syncCampaigns,
    required bool isRefresh,
  }) async {
    emit(
      state.copyWith(
        status: isRefresh
            ? NotificationStatus.refreshing
            : NotificationStatus.loading,
        activeFilter: filter,
        clearErrorMessage: true,
      ),
    );

    final result = await _getNotificationsUseCase(
      GetNotificationsParams(
        filter: filter,
        limit: defaultPageSize,
        offset: 0,
        syncCampaigns: syncCampaigns,
      ),
    );

    result.fold(
      (failure) {
        if (state.notifications.isNotEmpty) {
          emit(
            state.copyWith(
              status: NotificationStatus.loaded,
              feedbackMessage: failure.message,
              isFeedbackError: true,
              feedbackSequence: state.feedbackSequence + 1,
            ),
          );
        } else {
          emit(
            state.copyWith(
              status: NotificationStatus.error,
              errorMessage: failure.message,
            ),
          );
        }
      },
      (page) {
        emit(
          state.copyWith(
            status: NotificationStatus.loaded,
            activeFilter: page.filter,
            counts: page.counts,
            notifications: _deduplicateNotifications(page.notifications),
            hasMore: page.hasMore,
            isLoadingMore: false,
            isFromCache: page.isFromCache,
            clearErrorMessage: true,
          ),
        );
      },
    );
  }

  Future<void> _onLoadMoreRequested(
    NotificationsLoadMoreRequested event,
    Emitter<NotificationState> emit,
  ) async {
    if (state.isLoadingMore ||
        !state.hasMore ||
        state.status == NotificationStatus.loading ||
        state.isFromCache) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    final result = await _getNotificationsUseCase(
      GetNotificationsParams(
        filter: state.activeFilter,
        limit: defaultPageSize,
        offset: state.notifications.length,
        syncCampaigns: false,
      ),
    );

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            isLoadingMore: false,
            feedbackMessage: failure.message,
            isFeedbackError: true,
            feedbackSequence: state.feedbackSequence + 1,
          ),
        );
      },
      (page) {
        final merged = _deduplicateNotifications([
          ...state.notifications,
          ...page.notifications,
        ]);
        emit(
          state.copyWith(
            status: NotificationStatus.loaded,
            counts: page.counts,
            notifications: merged,
            hasMore: page.hasMore,
            isLoadingMore: false,
            isFromCache: page.isFromCache,
          ),
        );
      },
    );
  }

  Future<void> _onMarkedAsRead(
    NotificationMarkedAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    final targetIndex = state.notifications.indexWhere(
      (n) => n.id == event.notificationId,
    );
    if (targetIndex == -1 && !state.hasUnread) {
      return;
    }

    final existing =
        targetIndex >= 0 ? state.notifications[targetIndex] : null;
    if (existing != null && existing.isRead) {
      return;
    }

    final previousItems = state.notifications;
    final previousCounts = state.counts;
    final optimisticNow = DateTime.now().toUtc();

    final optimisticList = state.notifications
        .map(
          (item) => item.id == event.notificationId
              ? item.copyWith(readAt: optimisticNow)
              : item,
        )
        .where(
          (item) =>
              state.activeFilter != NotificationFilter.unread || item.isUnread,
        )
        .toList();

    final optimisticUnread =
        state.counts.unread > 0 ? state.counts.unread - 1 : 0;

    emit(
      state.copyWith(
        notifications: optimisticList,
        counts: state.counts.copyWith(unread: optimisticUnread),
      ),
    );

    final result = await _markNotificationReadUseCase(event.notificationId);
    result.fold(
      (failure) {
        emit(
          state.copyWith(
            notifications: previousItems,
            counts: previousCounts,
            feedbackMessage: failure.message,
            isFeedbackError: true,
            feedbackSequence: state.feedbackSequence + 1,
          ),
        );
      },
      (serverResult) {
        final reconciled = state.notifications
            .map(
              (item) => item.id == event.notificationId
                  ? item.copyWith(readAt: serverResult.readAt)
                  : item,
            )
            .where(
              (item) =>
                  state.activeFilter != NotificationFilter.unread ||
                  item.isUnread,
            )
            .toList();
        emit(
          state.copyWith(
            notifications: reconciled,
            counts: state.counts.copyWith(unread: serverResult.unreadCount),
          ),
        );
      },
    );
  }

  Future<void> _onNotificationOpened(
    NotificationOpened event,
    Emitter<NotificationState> emit,
  ) async {
    final notification = event.notification;
    if (notification.isUnread) {
      add(NotificationMarkedAsRead(notification.id));
    }

    final intent = _resolveNavigationIntent(notification);
    emit(state.copyWith(navigationIntent: intent));
  }

  NotificationNavigationIntent _resolveNavigationIntent(
    NotificationEntity notification,
  ) {
    _navSeq += 1;

    if (notification.category == NotificationCategory.announcements) {
      if (notification.title.trim().isEmpty &&
          notification.body.trim().isEmpty &&
          notification.advertisementId == null) {
        return NotificationNavigationIntent(
          unavailableMessage: 'This announcement is no longer available.',
          sequence: _navSeq,
        );
      }
      return NotificationNavigationIntent(
        route: RoutesNames.home,
        campaignDetail: notification,
        sequence: _navSeq,
      );
    }

    switch (notification.type) {
      case NotificationType.posPointsCredited:
      case NotificationType.festivalBonusCredited:
      case NotificationType.adminPointAdjustment:
      case NotificationType.claimGenerated:
      case NotificationType.claimRedeemed:
      case NotificationType.claimRejected:
        return NotificationNavigationIntent(
          route: RoutesNames.activityHistory,
          sequence: _navSeq,
        );
      case NotificationType.dailyStreakClaimed:
      case NotificationType.streakMilestoneCompleted:
        return NotificationNavigationIntent(
          route: RoutesNames.home,
          scrollTarget: NotificationScrollTarget.streak,
          sequence: _navSeq,
        );
      case NotificationType.lockedPointsReleased:
      case NotificationType.claimExpired:
        return NotificationNavigationIntent(
          route: RoutesNames.home,
          scrollTarget: NotificationScrollTarget.wallet,
          sequence: _navSeq,
        );
      case NotificationType.accountApproved:
        return NotificationNavigationIntent(
          route: RoutesNames.home,
          sequence: _navSeq,
        );
      case NotificationType.accountStatusChanged:
        return NotificationNavigationIntent(
          route: RoutesNames.pendingApproval,
          sequence: _navSeq,
        );
      case NotificationType.campaignPublished:
      case NotificationType.promotionalOffer:
      case NotificationType.festivalAnnouncement:
      case NotificationType.systemAnnouncement:
        final dest = notification.destinationRoute;
        if (dest == RoutesNames.home ||
            dest == RoutesNames.activityHistory ||
            dest == RoutesNames.customerQr ||
            dest == RoutesNames.claimRewards) {
          return NotificationNavigationIntent(
            route: dest,
            scrollTarget: notification.scrollTarget,
            sequence: _navSeq,
          );
        }
        return NotificationNavigationIntent(
          unavailableMessage:
              'Related notification details could not be opened.',
          sequence: _navSeq,
        );
    }
  }

  Future<void> _onAllMarkedAsRead(
    NotificationsAllMarkedAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    if (!state.hasUnread || state.isUpdating) return;

    final previousStatus = state.status;
    final previousItems = state.notifications;
    final previousCounts = state.counts;
    final optimisticNow = DateTime.now().toUtc();

    final optimisticList = state.activeFilter == NotificationFilter.unread
        ? <NotificationEntity>[]
        : state.notifications
            .map((item) => item.isUnread ? item.copyWith(readAt: optimisticNow) : item)
            .toList();

    emit(
      state.copyWith(
        status: NotificationStatus.updating,
        notifications: optimisticList,
        counts: state.counts.copyWith(unread: 0),
      ),
    );

    final result = await _markAllNotificationsReadUseCase();
    result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: previousStatus == NotificationStatus.updating
                ? NotificationStatus.loaded
                : previousStatus,
            notifications: previousItems,
            counts: previousCounts,
            feedbackMessage: failure.message,
            isFeedbackError: true,
            feedbackSequence: state.feedbackSequence + 1,
          ),
        );
      },
      (serverResult) {
        final finalItems = state.activeFilter == NotificationFilter.unread
            ? <NotificationEntity>[]
            : state.notifications
                .map(
                  (item) => item.isUnread
                      ? item.copyWith(readAt: serverResult.readAt)
                      : item,
                )
                .toList();
        emit(
          state.copyWith(
            status: NotificationStatus.loaded,
            notifications: finalItems,
            counts: state.counts.copyWith(unread: serverResult.unreadCount),
            feedbackMessage: serverResult.updatedCount > 0
                ? 'All notifications marked as read'
                : null,
            isFeedbackError: false,
            feedbackSequence: state.feedbackSequence + 1,
          ),
        );
      },
    );
  }

  void _onRealtimeReceived(
    NotificationRealtimeReceived event,
    Emitter<NotificationState> emit,
  ) {
    final rtEvent = event.realtimeEvent;
    final activeUid = state.activeUserId;

    if (rtEvent.eventType == NotificationRealtimeEventType.delete) {
      final deletedId = rtEvent.deletedId;
      if (deletedId == null || deletedId.isEmpty) return;

      final existingIndex = state.notifications.indexWhere(
        (item) => item.id == deletedId,
      );
      if (existingIndex == -1) {
        add(const NotificationUnreadCountRequested());
        return;
      }

      final removed = state.notifications[existingIndex];
      final updatedList = List<NotificationEntity>.from(state.notifications)
        ..removeAt(existingIndex);
      emit(
        state.copyWith(
          notifications: updatedList,
          counts: state.counts.copyWith(
            all: state.counts.all > 0 ? state.counts.all - 1 : 0,
            unread: removed.isUnread && state.counts.unread > 0
                ? state.counts.unread - 1
                : state.counts.unread,
            pointsRewards:
                removed.category == NotificationCategory.pointsRewards &&
                        state.counts.pointsRewards > 0
                    ? state.counts.pointsRewards - 1
                    : state.counts.pointsRewards,
            announcements:
                removed.category == NotificationCategory.announcements &&
                        state.counts.announcements > 0
                    ? state.counts.announcements - 1
                    : state.counts.announcements,
          ),
        ),
      );
      return;
    }

    final incoming = rtEvent.notification;
    if (incoming == null) return;
    if (activeUid != null && incoming.userId != activeUid) return;

    final existingIndex = state.notifications.indexWhere(
      (item) => item.id == incoming.id,
    );

    if (rtEvent.eventType == NotificationRealtimeEventType.insert) {
      if (existingIndex >= 0) {
        // Deduplicate: replace with newer server snapshot without double counting.
        final updatedList = List<NotificationEntity>.from(state.notifications);
        updatedList[existingIndex] = incoming;
        emit(state.copyWith(notifications: updatedList));
        return;
      }

      final newCounts = NotificationCountsEntity(
        all: state.counts.all + 1,
        unread: state.counts.unread + (incoming.isUnread ? 1 : 0),
        pointsRewards: state.counts.pointsRewards +
            (incoming.category == NotificationCategory.pointsRewards ? 1 : 0),
        announcements: state.counts.announcements +
            (incoming.category == NotificationCategory.announcements ? 1 : 0),
      );

      final updatedList = List<NotificationEntity>.from(state.notifications);
      if (_matchesFilter(incoming, state.activeFilter)) {
        updatedList.insert(0, incoming);
      }

      emit(
        state.copyWith(
          status: state.status == NotificationStatus.initial
              ? NotificationStatus.loaded
              : state.status,
          notifications: _deduplicateNotifications(updatedList),
          counts: newCounts,
          clearErrorMessage: true,
        ),
      );
      return;
    }

    if (rtEvent.eventType == NotificationRealtimeEventType.update) {
      if (existingIndex == -1) {
        add(const NotificationUnreadCountRequested());
        return;
      }

      final previous = state.notifications[existingIndex];
      var updatedUnread = state.counts.unread;
      if (previous.isUnread && incoming.isRead) {
        updatedUnread = updatedUnread > 0 ? updatedUnread - 1 : 0;
      } else if (previous.isRead && incoming.isUnread) {
        updatedUnread += 1;
      }

      final updatedList = List<NotificationEntity>.from(state.notifications);
      if (_matchesFilter(incoming, state.activeFilter)) {
        updatedList[existingIndex] = incoming;
      } else {
        updatedList.removeAt(existingIndex);
      }

      emit(
        state.copyWith(
          notifications: updatedList,
          counts: state.counts.copyWith(unread: updatedUnread),
        ),
      );
    }
  }

  void _onRealtimeStatusChanged(
    NotificationRealtimeStatusChanged event,
    Emitter<NotificationState> emit,
  ) {
    final prev = state.realtimeConnectionState;
    emit(state.copyWith(realtimeConnectionState: event.connectionState));
    if (event.connectionState ==
            NotificationRealtimeConnectionState.subscribed &&
        (prev == NotificationRealtimeConnectionState.reconnecting ||
            prev == NotificationRealtimeConnectionState.error)) {
      add(const NotificationUnreadCountRequested());
    }
  }

  Future<void> _onUnreadCountRequested(
    NotificationUnreadCountRequested event,
    Emitter<NotificationState> emit,
  ) async {
    final result = await _getUnreadNotificationCountUseCase();
    result.fold(
      (_) {},
      (unreadCount) {
        emit(
          state.copyWith(
            counts: state.counts.copyWith(unread: unreadCount),
          ),
        );
      },
    );
  }

  void _onNavigationHandled(
    NotificationNavigationHandled event,
    Emitter<NotificationState> emit,
  ) {
    emit(state.copyWith(clearNavigationIntent: true));
  }

  void _onFeedbackCleared(
    NotificationFeedbackCleared event,
    Emitter<NotificationState> emit,
  ) {
    emit(state.copyWith(clearFeedbackMessage: true));
  }

  bool _matchesFilter(NotificationEntity item, NotificationFilter filter) {
    switch (filter) {
      case NotificationFilter.all:
        return true;
      case NotificationFilter.unread:
        return item.isUnread;
      case NotificationFilter.pointsRewards:
        return item.category == NotificationCategory.pointsRewards;
      case NotificationFilter.announcements:
        return item.category == NotificationCategory.announcements;
    }
  }

  List<NotificationEntity> _deduplicateNotifications(
    List<NotificationEntity> items,
  ) {
    final seen = <String>{};
    final result = <NotificationEntity>[];
    for (final item in items) {
      if (item.id.isNotEmpty && seen.add(item.id)) {
        result.add(item);
      }
    }
    return result;
  }

  Future<void> _cancelSubscriptions() async {
    await _realtimeSub?.cancel();
    _realtimeSub = null;
    await _connectionSub?.cancel();
    _connectionSub = null;
  }

  @override
  Future<void> close() async {
    await _cancelSubscriptions();
    return super.close();
  }
}
