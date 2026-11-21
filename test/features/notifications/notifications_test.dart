import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiftex/core/errors/error_mapper.dart';
import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shiftex/features/home/presentation/widgets/home_header_bar.dart';
import 'package:shiftex/features/notifications/data/datasources/notification_local_data_source.dart';
import 'package:shiftex/features/notifications/data/datasources/notification_remote_data_source.dart';
import 'package:shiftex/features/notifications/data/models/notification_model.dart';
import 'package:shiftex/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_category.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_entity.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_filter.dart';
import 'package:shiftex/features/notifications/domain/usecases/get_notifications_usecase.dart';
import 'package:shiftex/features/notifications/domain/usecases/get_unread_notification_count_usecase.dart';
import 'package:shiftex/features/notifications/domain/usecases/mark_all_notifications_read_usecase.dart';
import 'package:shiftex/features/notifications/domain/usecases/mark_notification_read_usecase.dart';
import 'package:shiftex/features/notifications/domain/usecases/watch_notifications_realtime_usecase.dart';
import 'package:shiftex/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:shiftex/features/notifications/presentation/bloc/notification_event.dart';
import 'package:shiftex/features/notifications/presentation/bloc/notification_state.dart';
import 'package:shiftex/features/notifications/presentation/pages/notifications_page.dart';
import 'package:shiftex/features/notifications/presentation/widgets/notification_card.dart';
import 'package:shiftex/features/notifications/presentation/widgets/unread_indicator.dart';

class _InMemoryNotificationStore implements NotificationKeyValueStore {
  final Map<String, String> _storage = <String, String>{};

  @override
  Future<void> delete(String key) async => _storage.remove(key);

  @override
  Future<String?> read(String key) async => _storage[key];

  @override
  Future<void> write(String key, String value) async => _storage[key] = value;
}

class _FakeNotificationRemoteDataSource
    implements NotificationRemoteDataSource {
  String? activeUserId = 'user-1';
  final List<NotificationModel> serverItems = [];
  Object? nextFetchError;
  Object? nextMarkError;
  Completer<void>? fetchDelay;
  int fetchCalls = 0;
  int watchCalls = 0;
  int stopCalls = 0;
  final List<NotificationFilter> requestedFilters = [];
  final List<int> requestedOffsets = [];

  final StreamController<NotificationRealtimeEvent> realtimeController =
      StreamController<NotificationRealtimeEvent>.broadcast();
  final StreamController<NotificationRealtimeConnectionState>
      connectionController =
      StreamController<NotificationRealtimeConnectionState>.broadcast();

  @override
  String? get currentUserId => activeUserId;

  @override
  Stream<NotificationRealtimeConnectionState> get realtimeConnectionState =>
      connectionController.stream;

  NotificationCountsModel _computeCounts(String uid) {
    final owned = serverItems.where((n) => n.userId == uid).toList();
    return NotificationCountsModel(
      all: owned.length,
      unread: owned.where((n) => n.isUnread).length,
      pointsRewards: owned
          .where((n) => n.category == NotificationCategory.pointsRewards)
          .length,
      announcements: owned
          .where((n) => n.category == NotificationCategory.announcements)
          .length,
    );
  }

  @override
  Future<NotificationPageModel> getNotifications({
    required NotificationFilter filter,
    int limit = 20,
    int offset = 0,
    bool syncCampaigns = false,
  }) async {
    fetchCalls++;
    requestedFilters.add(filter);
    requestedOffsets.add(offset);

    if (fetchDelay != null) {
      await fetchDelay!.future;
    }

    final uid = activeUserId;
    if (uid == null) {
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }

    if (nextFetchError != null) {
      throw nextFetchError!;
    }

    final owned = serverItems.where((n) => n.userId == uid).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final filtered = owned.where((item) {
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
    }).toList();

    final slice = filtered.skip(offset).take(limit).toList();
    final hasMore = offset + slice.length < filtered.length;

    return NotificationPageModel(
      filter: filter,
      limit: limit,
      offset: offset,
      hasMore: hasMore,
      counts: _computeCounts(uid),
      notifications: slice,
    );
  }

  @override
  Future<MarkNotificationReadResultModel> markNotificationAsRead(
    String notificationId,
  ) async {
    final uid = activeUserId;
    if (uid == null) {
      throw const AppAuthException('Session expired', code: 'session_expired');
    }
    if (nextMarkError != null) {
      throw nextMarkError!;
    }

    final now = DateTime.now().toUtc();
    final index = serverItems.indexWhere(
      (n) => n.id == notificationId && n.userId == uid,
    );
    if (index == -1) {
      throw const AppAuthException('Not found', code: 'server_failure');
    }

    final existing = serverItems[index];
    if (existing.isUnread) {
      serverItems[index] = NotificationModel.fromEntity(
        existing.copyWith(readAt: now),
      );
    }

    return MarkNotificationReadResultModel(
      id: notificationId,
      readAt: serverItems[index].readAt ?? now,
      unreadCount: _computeCounts(uid).unread,
    );
  }

  @override
  Future<MarkAllNotificationsReadResultModel> markAllAsRead() async {
    final uid = activeUserId;
    if (uid == null) {
      throw const AppAuthException('Session expired', code: 'session_expired');
    }
    if (nextMarkError != null) {
      throw nextMarkError!;
    }

    final now = DateTime.now().toUtc();
    var updated = 0;
    for (var i = 0; i < serverItems.length; i++) {
      final item = serverItems[i];
      if (item.userId == uid && item.isUnread) {
        serverItems[i] = NotificationModel.fromEntity(
          item.copyWith(readAt: now),
        );
        updated++;
      }
    }

    return MarkAllNotificationsReadResultModel(
      updatedCount: updated,
      unreadCount: 0,
      readAt: now,
    );
  }

  @override
  Future<int> getUnreadCount() async {
    final uid = activeUserId;
    if (uid == null) {
      throw const AppAuthException('Session expired', code: 'session_expired');
    }
    if (nextFetchError != null) {
      throw nextFetchError!;
    }
    return _computeCounts(uid).unread;
  }

  @override
  Stream<NotificationRealtimeEvent> watchNotifications({
    required String userId,
  }) {
    if (activeUserId != userId) {
      throw const AppAuthException('Session expired', code: 'session_expired');
    }
    watchCalls++;
    connectionController.add(NotificationRealtimeConnectionState.subscribed);
    return realtimeController.stream;
  }

  @override
  Future<void> stopRealtime() async {
    stopCalls++;
    connectionController.add(NotificationRealtimeConnectionState.disconnected);
  }

  Future<void> dispose() async {
    await realtimeController.close();
    await connectionController.close();
  }
}

NotificationModel _buildSampleNotification({
  required String id,
  String userId = 'user-1',
  NotificationCategory category = NotificationCategory.pointsRewards,
  NotificationType type = NotificationType.posPointsCredited,
  String title = 'Points Credited at Metro Fresh Mart',
  String body = '+80 pts (≈ ₹8.00) credited by Merchant Scan POS #4',
  int? pointsAmount = 80,
  double? cashValue = 8.0,
  String? badgeLabel,
  Map<String, dynamic> metadata = const {},
  DateTime? readAt,
  DateTime? createdAt,
}) {
  return NotificationModel(
    id: id,
    userId: userId,
    category: category,
    type: type,
    title: title,
    body: body,
    pointsAmount: pointsAmount,
    cashValue: cashValue,
    badgeLabel: badgeLabel,
    metadata: metadata,
    readAt: readAt,
    createdAt: createdAt ?? DateTime.now().toUtc(),
  );
}

List<NotificationModel> _buildScreenshotSeedList() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 14, 45);
  final morning = DateTime(now.year, now.month, now.day, 9, 12);
  final yesterdayEve = today.subtract(const Duration(days: 1, hours: 0)).copyWith(
    hour: 18,
    minute: 0,
  );
  final yesterdayAfternoon = yesterdayEve.copyWith(hour: 16, minute: 15);
  final twoDaysAgo = today.subtract(const Duration(days: 2));

  return [
    _buildSampleNotification(
      id: 'n-pos',
      category: NotificationCategory.pointsRewards,
      type: NotificationType.posPointsCredited,
      title: 'Points Credited at Metro Fresh Mart',
      body: '+80 pts (≈ ₹8.00) credited by Merchant Scan POS #4',
      pointsAmount: 80,
      cashValue: 8.0,
      createdAt: today,
    ),
    _buildSampleNotification(
      id: 'n-streak',
      category: NotificationCategory.pointsRewards,
      type: NotificationType.dailyStreakClaimed,
      title: 'Daily Login Streak Day 4 Claimed',
      body: '+15 pts added to your available balance. 3 days left to streak bonus!',
      pointsAmount: 15,
      cashValue: 1.5,
      metadata: const {'scroll_target': 'streak', 'streak_day': 4},
      createdAt: morning,
    ),
    _buildSampleNotification(
      id: 'n-unlock',
      category: NotificationCategory.pointsRewards,
      type: NotificationType.lockedPointsReleased,
      title: 'Milestone Reward Unlocked!',
      body:
          'Your 550 locked points have completed settlement clearance and are now available.',
      pointsAmount: 550,
      cashValue: 55.0,
      metadata: const {'scroll_target': 'wallet'},
      createdAt: yesterdayEve,
    ),
    _buildSampleNotification(
      id: 'n-claim',
      category: NotificationCategory.claims,
      type: NotificationType.claimRedeemed,
      title: 'Claim Reward Redeemed',
      body:
          '100 pts redeemed for ₹10.00 cashier discount at Blue Tokai. Ref CLM-9942-X7B.',
      pointsAmount: -100,
      cashValue: 10.0,
      readAt: yesterdayAfternoon,
      createdAt: yesterdayAfternoon,
    ),
    _buildSampleNotification(
      id: 'n-festive',
      category: NotificationCategory.announcements,
      type: NotificationType.festivalAnnouncement,
      title: 'Diwali Mahotsav 2X Bonus Live',
      body: 'Earn 2x rewards across all partner stores on bills above ₹500.',
      badgeLabel: 'Festive',
      pointsAmount: null,
      cashValue: null,
      metadata: const {
        'advertisement_id': 'ad-diwali-1',
        'offer_details':
            'Earn double points across every partner counter above ₹500.',
      },
      readAt: twoDaysAgo,
      createdAt: twoDaysAgo,
    ),
    _buildSampleNotification(
      id: 'n-festive-bonus',
      category: NotificationCategory.pointsRewards,
      type: NotificationType.festivalBonusCredited,
      title: 'Festival Bonus Credited',
      body: '+100 pts (≈ ₹10.00) • Diwali bonus credited to your wallet.',
      badgeLabel: 'Festive',
      pointsAmount: 100,
      cashValue: 10.0,
      readAt: twoDaysAgo,
      createdAt: twoDaysAgo.subtract(const Duration(hours: 2)),
    ),
    _buildSampleNotification(
      id: 'n-claim-rejected',
      category: NotificationCategory.claims,
      type: NotificationType.claimRejected,
      title: 'Claim Rejected',
      body:
          'Claim CLM-101 (50 pts) declined at counter: Bill cancelled. Reserved pts released.',
      pointsAmount: 50,
      cashValue: 5.0,
      readAt: twoDaysAgo,
      createdAt: twoDaysAgo.subtract(const Duration(hours: 4)),
    ),
  ];
}

Future<void> _pumpBlocFrames(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 30));
  }
}

void main() {
  group('Notification Models, Formatter & Repository Tests', () {
    late _InMemoryNotificationStore kvStore;
    late NotificationLocalDataSourceImpl localDataSource;
    late _FakeNotificationRemoteDataSource remoteDataSource;
    late NotificationRepositoryImpl repository;

    setUp(() {
      kvStore = _InMemoryNotificationStore();
      localDataSource = NotificationLocalDataSourceImpl(kvStore);
      remoteDataSource = _FakeNotificationRemoteDataSource();
      repository = NotificationRepositoryImpl(
        remoteDataSource: remoteDataSource,
        localDataSource: localDataSource,
      );
    });

    tearDown(() async {
      await remoteDataSource.dispose();
    });

    test('parses RPC page payload and formats relative timestamps accurately', () {
      final now = DateTime(2026, 11, 19, 18, 0);
      final todaySample = DateTime(2026, 11, 19, 14, 45);
      final yesterdaySample = DateTime(2026, 11, 18, 18, 0);
      final olderSample = DateTime(2026, 10, 14, 9, 5);

      expect(
        NotificationFormatters.formatTimestamp(todaySample, now: now),
        'Today, 02:45 PM',
      );
      expect(
        NotificationFormatters.formatTimestamp(yesterdaySample, now: now),
        'Yesterday, 06:00 PM',
      );
      expect(
        NotificationFormatters.formatTimestamp(olderSample, now: now),
        '14 Oct, 09:05 AM',
      );

      final parsed = NotificationPageModel.fromJson({
        'filter': 'all',
        'limit': 20,
        'offset': 0,
        'has_more': true,
        'counts': {
          'all': 7,
          'unread': 3,
          'points_rewards': 4,
          'announcements': 1,
        },
        'notifications': [
          {
            'id': 'notif-1',
            'user_id': 'user-1',
            'category': 'announcements',
            'notification_type': 'festival_announcement',
            'title': 'Diwali Mahotsav 2X Bonus Live',
            'body': 'Earn 2x rewards',
            'badge_label': 'Festive',
            'metadata': {'advertisement_id': 'ad-1'},
            'created_at': '2026-11-19T09:00:00Z',
          },
        ],
      });

      expect(parsed.hasMore, isTrue);
      expect(parsed.counts.all, 7);
      expect(parsed.counts.unread, 3);
      expect(parsed.notifications.single.badgeLabel, 'Festive');
      expect(
        parsed.notifications.single.type,
        NotificationType.festivalAnnouncement,
      );
      expect(parsed.notifications.single.advertisementId, 'ad-1');
    });

    test('serves user-isolated cached notifications when offline and clears on logout', () async {
      remoteDataSource.serverItems.addAll(_buildScreenshotSeedList());
      // Seed another customer's private notification on the fake remote
      remoteDataSource.serverItems.add(
        _buildSampleNotification(
          id: 'other-user-notif',
          userId: 'user-2',
          title: 'Private Customer 2 Alert',
        ),
      );

      final onlineRes = await repository.getNotifications(
        filter: NotificationFilter.all,
      );
      expect(onlineRes.isRight(), isTrue);
      final onlinePage = onlineRes.getOrElse(() => throw StateError('expected'));
      expect(onlinePage.notifications.length, 7);
      expect(
        onlinePage.notifications.any((n) => n.userId == 'user-2'),
        isFalse,
      );

      // Simulate offline SocketException -> falls back cleanly to cached filtered list
      remoteDataSource.nextFetchError = const SocketException('Offline');
      final offlineUnread = await repository.getNotifications(
        filter: NotificationFilter.unread,
      );
      expect(offlineUnread.isRight(), isTrue);
      final cachedPage = offlineUnread.getOrElse(
        () => throw StateError('expected'),
      );
      expect(cachedPage.isFromCache, isTrue);
      expect(cachedPage.notifications.length, 3);

      // Clearing cache on logout ensures user-2 never sees user-1's cache
      await repository.stopRealtimeAndClearCache(userId: 'user-1');
      final afterLogoutCache = await localDataSource.getCachedPage(
        userId: 'user-1',
      );
      expect(afterLogoutCache, isNull);
    });

    test('returns SessionExpiredFailure when unauthenticated', () async {
      remoteDataSource.activeUserId = null;
      final res = await repository.getNotifications(
        filter: NotificationFilter.all,
      );
      expect(res, isA<Left<Failure, NotificationPageEntity>>());
      res.fold(
        (failure) => expect(failure, isA<SessionExpiredFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('maps missing backend RPC PostgrestException cleanly without profile error message', () {
      const postgrestError = PostgrestException(
        message: 'Could not find the function public.get_customer_notifications',
        code: 'PGRST202',
      );
      final failure = ErrorMapper.mapExceptionToFailure(postgrestError);
      expect(failure, isA<ServerFailure>());
      expect(failure.message.toLowerCase(), isNot(contains('account profile')));
      expect(failure.message.toLowerCase(), contains('database migration'));
    });
  });

  group('NotificationBloc Logic, Realtime & Navigation Tests', () {
    late _InMemoryNotificationStore kvStore;
    late NotificationLocalDataSourceImpl localDataSource;
    late _FakeNotificationRemoteDataSource remoteDataSource;
    late NotificationRepositoryImpl repository;
    late NotificationBloc bloc;

    NotificationBloc createBloc() {
      return NotificationBloc(
        getNotificationsUseCase: GetNotificationsUseCase(repository),
        markNotificationReadUseCase: MarkNotificationReadUseCase(repository),
        markAllNotificationsReadUseCase:
            MarkAllNotificationsReadUseCase(repository),
        getUnreadNotificationCountUseCase:
            GetUnreadNotificationCountUseCase(repository),
        watchNotificationsRealtimeUseCase:
            WatchNotificationsRealtimeUseCase(repository),
      );
    }

    setUp(() {
      kvStore = _InMemoryNotificationStore();
      localDataSource = NotificationLocalDataSourceImpl(kvStore);
      remoteDataSource = _FakeNotificationRemoteDataSource();
      repository = NotificationRepositoryImpl(
        remoteDataSource: remoteDataSource,
        localDataSource: localDataSource,
      );
      remoteDataSource.serverItems.addAll(_buildScreenshotSeedList());
      bloc = createBloc();
    });

    tearDown(() async {
      await bloc.close();
      await remoteDataSource.dispose();
    });

    test('NotificationsStarted loads initial feed, subscribes once, and prevents duplicate listeners', () async {
      bloc.add(const NotificationsStarted('user-1'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.status, NotificationStatus.loaded);
      expect(bloc.state.notifications.length, 7);
      expect(bloc.state.counts.all, 7);
      expect(bloc.state.counts.unread, 3);
      expect(remoteDataSource.watchCalls, 1);

      // Re-dispatching for same active user must NOT recreate realtime channel
      bloc.add(const NotificationsStarted('user-1'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(remoteDataSource.watchCalls, 1);

      // Logout clears active session and stops channel
      bloc.add(const NotificationsStopped());
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.status, NotificationStatus.initial);
      expect(bloc.state.notifications, isEmpty);
      expect(remoteDataSource.stopCalls, 1);
    });

    test('filter switching filters Unread, Points & Rewards, and Announcements cleanly', () async {
      bloc.add(const NotificationsStarted('user-1'));
      await Future<void>.delayed(const Duration(milliseconds: 40));

      bloc.add(const NotificationFilterChanged(NotificationFilter.unread));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.activeFilter, NotificationFilter.unread);
      expect(bloc.state.notifications.length, 3);
      expect(bloc.state.notifications.every((n) => n.isUnread), isTrue);

      bloc.add(
        const NotificationFilterChanged(NotificationFilter.pointsRewards),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.notifications.length, 4);
      expect(
        bloc.state.notifications.every(
          (n) => n.category == NotificationCategory.pointsRewards,
        ),
        isTrue,
      );

      bloc.add(
        const NotificationFilterChanged(NotificationFilter.announcements),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.notifications.length, 1);
      expect(bloc.state.notifications.single.badgeLabel, 'Festive');
    });

    test('mark individual read & mark all as read synchronize counts and server state', () async {
      bloc.add(const NotificationsStarted('user-1'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.unreadCount, 3);

      bloc.add(const NotificationMarkedAsRead('n-pos'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.unreadCount, 2);
      expect(
        bloc.state.notifications.firstWhere((n) => n.id == 'n-pos').isRead,
        isTrue,
      );

      bloc.add(const NotificationsAllMarkedAsRead());
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.unreadCount, 0);
      expect(bloc.state.notifications.every((n) => n.isRead), isTrue);
    });

    test('realtime insert deduplicates IDs, ignores other users, and updates read transitions live', () async {
      bloc.add(const NotificationsStarted('user-1'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.counts.all, 7);
      expect(bloc.state.unreadCount, 3);

      final rtInsert = _buildSampleNotification(
        id: 'n-rt-1',
        title: 'Points Credited at Urban Grocers',
        body: '+120 pts (≈ ₹12.00) credited by POS #2',
        pointsAmount: 120,
      );

      // Push same realtime INSERT twice + push another customer's alert
      remoteDataSource.realtimeController.add(
        NotificationRealtimeEvent(
          eventType: NotificationRealtimeEventType.insert,
          notification: rtInsert,
        ),
      );
      remoteDataSource.realtimeController.add(
        NotificationRealtimeEvent(
          eventType: NotificationRealtimeEventType.insert,
          notification: rtInsert,
        ),
      );
      remoteDataSource.realtimeController.add(
        NotificationRealtimeEvent(
          eventType: NotificationRealtimeEventType.insert,
          notification: _buildSampleNotification(
            id: 'other-rt',
            userId: 'user-99',
          ),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.counts.all, 8);
      expect(bloc.state.unreadCount, 4);
      expect(
        bloc.state.notifications.where((n) => n.id == 'n-rt-1').length,
        1,
      );
      expect(
        bloc.state.notifications.any((n) => n.userId == 'user-99'),
        isFalse,
      );

      // Realtime update marking it read decrements unread count live
      remoteDataSource.realtimeController.add(
        NotificationRealtimeEvent(
          eventType: NotificationRealtimeEventType.update,
          notification: NotificationModel.fromEntity(
            rtInsert.copyWith(readAt: DateTime.now().toUtc()),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.unreadCount, 3);
    });

    test('pagination appends additional pages cleanly without duplicates', () async {
      remoteDataSource.serverItems
        ..clear()
        ..addAll(
          List.generate(
            25,
            (i) => _buildSampleNotification(
              id: 'page-item-$i',
              title: 'Event $i',
              createdAt: DateTime.now().toUtc().subtract(Duration(minutes: i)),
            ),
          ),
        );

      bloc.add(const NotificationsStarted('user-1'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.notifications.length, 20);
      expect(bloc.state.hasMore, isTrue);

      bloc.add(const NotificationsLoadMoreRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.notifications.length, 25);
      expect(bloc.state.hasMore, isFalse);
    });

    test('tapping notifications resolves exact route targets and handles missing announcement gracefully', () async {
      bloc.add(const NotificationsStarted('user-1'));
      await Future<void>.delayed(const Duration(milliseconds: 40));

      final items = bloc.state.notifications;
      bloc.add(NotificationOpened(items.firstWhere((n) => n.id == 'n-pos')));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.navigationIntent?.route, RoutesNames.activityHistory);

      bloc.add(NotificationOpened(items.firstWhere((n) => n.id == 'n-streak')));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.navigationIntent?.route, RoutesNames.home);
      expect(
        bloc.state.navigationIntent?.scrollTarget,
        NotificationScrollTarget.streak,
      );

      bloc.add(NotificationOpened(items.firstWhere((n) => n.id == 'n-unlock')));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.navigationIntent?.route, RoutesNames.home);
      expect(
        bloc.state.navigationIntent?.scrollTarget,
        NotificationScrollTarget.wallet,
      );

      bloc.add(NotificationOpened(items.firstWhere((n) => n.id == 'n-festive')));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.navigationIntent?.hasCampaignDetail, isTrue);

      bloc.add(
        NotificationOpened(
          _buildSampleNotification(
            id: 'missing-ad',
            category: NotificationCategory.announcements,
            type: NotificationType.campaignPublished,
            title: '',
            body: '',
            pointsAmount: null,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.navigationIntent?.unavailableMessage, isNotNull);
    });
  });

  group('Notifications Center UI, Bell Badge & Responsive Widget Tests', () {
    late _InMemoryNotificationStore kvStore;
    late NotificationLocalDataSourceImpl localDataSource;
    late _FakeNotificationRemoteDataSource remoteDataSource;
    late NotificationRepositoryImpl repository;
    late NotificationBloc bloc;

    setUp(() {
      kvStore = _InMemoryNotificationStore();
      localDataSource = NotificationLocalDataSourceImpl(kvStore);
      remoteDataSource = _FakeNotificationRemoteDataSource();
      repository = NotificationRepositoryImpl(
        remoteDataSource: remoteDataSource,
        localDataSource: localDataSource,
      );
      remoteDataSource.serverItems.addAll(_buildScreenshotSeedList());
      bloc = NotificationBloc(
        getNotificationsUseCase: GetNotificationsUseCase(repository),
        markNotificationReadUseCase: MarkNotificationReadUseCase(repository),
        markAllNotificationsReadUseCase:
            MarkAllNotificationsReadUseCase(repository),
        getUnreadNotificationCountUseCase:
            GetUnreadNotificationCountUseCase(repository),
        watchNotificationsRealtimeUseCase:
            WatchNotificationsRealtimeUseCase(repository),
      );
    });

    tearDown(() async {
      await bloc.close();
      await remoteDataSource.dispose();
    });

    testWidgets(
      'renders header, filter pills, unread blue dots, Festive pill, and updates via filters + Mark all as read',
      (tester) async {
        bloc.add(const NotificationsStarted('user-1'));

        String? navigatedRoute;
        NotificationScrollTarget? navigatedSection;

        await tester.pumpWidget(
          MaterialApp(
            home: NotificationsPage(
              notificationBloc: bloc,
              onNavigate: (route, section) {
                navigatedRoute = route;
                navigatedSection = section;
              },
            ),
          ),
        );
        await _pumpBlocFrames(tester);

        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Mark all as read'), findsOneWidget);
        expect(find.byKey(const Key('notification_filter_all')), findsOneWidget);
        expect(
          find.byKey(const Key('notification_filter_unread')),
          findsOneWidget,
        );
        expect(find.text('Points & Rewards'), findsOneWidget);
        expect(find.text('Announcements'), findsOneWidget);

        expect(
          find.text('Points Credited at Metro Fresh Mart'),
          findsOneWidget,
        );
        expect(find.text('Daily Login Streak Day 4 Claimed'), findsOneWidget);
        expect(find.text('Milestone Reward Unlocked!'), findsOneWidget);
        // 3 unread notifications initially
        expect(find.byType(UnreadIndicator), findsWidgets);

        // Switch to Announcements tab -> verifies Festive badge & Campaign detail modal
        await tester.tap(
          find.byKey(const Key('notification_filter_announcements')),
        );
        await _pumpBlocFrames(tester);
        expect(find.text('Diwali Mahotsav 2X Bonus Live'), findsOneWidget);
        expect(find.text('Festive'), findsOneWidget);
        expect(
          find.text('Points Credited at Metro Fresh Mart'),
          findsNothing,
        );

        // Tap announcement -> opens campaign details modal sheet
        await tester.tap(find.byKey(const Key('notification_card_n-festive')));
        await _pumpBlocFrames(tester);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('View Rewards Dashboard'), findsOneWidget);
        await tester.tap(find.text('View Rewards Dashboard'));
        await _pumpBlocFrames(tester);
        expect(navigatedRoute, RoutesNames.home);
        expect(navigatedSection, NotificationScrollTarget.none);

        // Switch back to All and mark all read -> Unread becomes 0 and Unread filter shows All caught up!
        await tester.tap(find.byKey(const Key('notification_filter_all')));
        await _pumpBlocFrames(tester);

        await tester.tap(find.byKey(const Key('mark_all_as_read_button')));
        await _pumpBlocFrames(tester);
        expect(bloc.state.unreadCount, 0);

        await tester.tap(find.byKey(const Key('notification_filter_unread')));
        await _pumpBlocFrames(tester);
        expect(find.text('All caught up!'), findsOneWidget);
      },
    );

    testWidgets(
      'HomeHeaderBar bell badge reflects live unread count and updates via realtime inserts',
      (tester) async {
        bloc.add(const NotificationsStarted('user-1'));

        await tester.pumpWidget(
          BlocProvider<NotificationBloc>.value(
            value: bloc,
            child: MaterialApp(
              home: Scaffold(
                body: HomeHeaderBar(
                  fullName: 'Vishnu Kumar',
                  onNotificationTap: () {},
                  onProfileTap: () {},
                ),
              ),
            ),
          ),
        );
        await _pumpBlocFrames(tester);

        expect(
          find.byKey(const Key('notification_bell_badge')),
          findsOneWidget,
        );
        expect(find.text('3'), findsOneWidget);

        // Realtime new event increments bell badge live to 4
        remoteDataSource.realtimeController.add(
          NotificationRealtimeEvent(
            eventType: NotificationRealtimeEventType.insert,
            notification: _buildSampleNotification(
              id: 'bell-rt-1',
              title: 'New Reward',
            ),
          ),
        );
        await _pumpBlocFrames(tester);
        expect(find.text('4'), findsOneWidget);

        // Marking all read clears bell badge completely
        bloc.add(const NotificationsAllMarkedAsRead());
        await _pumpBlocFrames(tester);
        expect(find.byKey(const Key('notification_bell_badge')), findsNothing);
      },
    );

    testWidgets('shows loading skeleton while fetching and error retry on failure', (
      tester,
    ) async {
      remoteDataSource.serverItems.clear();
      remoteDataSource.nextFetchError = const AppAuthException(
        'Server temporarily unavailable',
        code: 'server_failure',
      );

      final failingBloc = NotificationBloc(
        getNotificationsUseCase: GetNotificationsUseCase(repository),
        markNotificationReadUseCase: MarkNotificationReadUseCase(repository),
        markAllNotificationsReadUseCase:
            MarkAllNotificationsReadUseCase(repository),
        getUnreadNotificationCountUseCase:
            GetUnreadNotificationCountUseCase(repository),
        watchNotificationsRealtimeUseCase:
            WatchNotificationsRealtimeUseCase(repository),
      );
      addTearDown(() => failingBloc.close());

      failingBloc.add(const NotificationsStarted('user-1'));

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationsPage(notificationBloc: failingBloc),
        ),
      );
      await _pumpBlocFrames(tester);

      expect(find.text('Unable to load notifications'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      // Clear error and verify Retry loads inbox
      remoteDataSource.nextFetchError = null;
      remoteDataSource.serverItems.addAll(_buildScreenshotSeedList());
      await tester.tap(find.text('Try Again'));
      await _pumpBlocFrames(tester);
      expect(find.text('Points Credited at Metro Fresh Mart'), findsOneWidget);
    });

    testWidgets(
      'auto-retries loading when Notifications sheet opens after a startup error and covers nested bottom nav bar',
      (tester) async {
        remoteDataSource.nextFetchError = const AppAuthException(
          'Startup error',
          code: 'server_failure',
        );

        final errorBloc = NotificationBloc(
          getNotificationsUseCase: GetNotificationsUseCase(repository),
          markNotificationReadUseCase: MarkNotificationReadUseCase(repository),
          markAllNotificationsReadUseCase:
              MarkAllNotificationsReadUseCase(repository),
          getUnreadNotificationCountUseCase:
              GetUnreadNotificationCountUseCase(repository),
          watchNotificationsRealtimeUseCase:
              WatchNotificationsRealtimeUseCase(repository),
        );
        addTearDown(() => errorBloc.close());

        errorBloc.add(const NotificationsStarted('user-1'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        expect(errorBloc.state.status, NotificationStatus.error);

        // Backend becomes reachable before customer taps the bell button
        remoteDataSource.nextFetchError = null;

        await tester.pumpWidget(
          BlocProvider<NotificationBloc>.value(
            value: errorBloc,
            child: MaterialApp(
              home: Scaffold(
                bottomNavigationBar: const SizedBox(
                  height: 64,
                  child: Center(child: Text('BottomNavShell')),
                ),
                body: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (innerContext) => Center(
                      child: ElevatedButton(
                        onPressed: () => showNotificationsBottomSheet(
                          innerContext,
                          notificationBloc: errorBloc,
                        ),
                        child: const Text('Open Bell'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await _pumpBlocFrames(tester);

        await tester.tap(find.text('Open Bell'));
        await _pumpBlocFrames(tester);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Points Credited at Metro Fresh Mart'), findsOneWidget);

        // Verify the bottom sheet is pushed on the root navigator above BottomNavShell
        final sheetTop = tester.getTopLeft(find.byType(NotificationsSheetContent)).dy;
        final navTop = tester.getTopLeft(find.text('BottomNavShell')).dy;
        expect(sheetTop, lessThan(navTop));
        final sheetBottom =
            tester.getBottomRight(find.byType(NotificationsSheetContent)).dy;
        expect(sheetBottom, greaterThan(navTop));
      },
    );

    testWidgets(
      'tapping bell button opens modal Notifications bottom sheet and closes cleanly',
      (tester) async {
        bloc.add(const NotificationsStarted('user-1'));

        await tester.pumpWidget(
          BlocProvider<NotificationBloc>.value(
            value: bloc,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => HomeHeaderBar(
                    fullName: 'Vishnu Kumar',
                    onNotificationTap: () => showNotificationsBottomSheet(
                      context,
                      notificationBloc: bloc,
                    ),
                    onProfileTap: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await _pumpBlocFrames(tester);

        await tester.tap(find.byKey(const Key('notification_bell_button')));
        await _pumpBlocFrames(tester);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Points Credited at Metro Fresh Mart'), findsOneWidget);

        await tester.tap(find.byKey(const Key('notifications_close_button')));
        await _pumpBlocFrames(tester);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Notifications'), findsNothing);
      },
    );

    testWidgets(
      'shows offline cache banner cleanly when network drops after caching and clears on Retry',
      (tester) async {
        bloc.add(const NotificationsStarted('user-1'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );

        // Simulate offline error on subsequent refresh
        remoteDataSource.nextFetchError = const SocketException('Offline');
        bloc.add(const NotificationsRefreshed());

        await tester.pumpWidget(
          MaterialApp(
            home: NotificationsPage(notificationBloc: bloc),
          ),
        );
        await _pumpBlocFrames(tester);

        expect(
          find.text('Offline mode • Showing cached notifications'),
          findsOneWidget,
        );
        expect(find.text('Points Credited at Metro Fresh Mart'), findsOneWidget);

        remoteDataSource.nextFetchError = null;
        await tester.tap(find.text('Retry'));
        await _pumpBlocFrames(tester);

        expect(
          find.text('Offline mode • Showing cached notifications'),
          findsNothing,
        );
      },
    );

    for (final viewport in [
      (name: 'Small 320x568', size: const Size(320, 568)),
      (name: 'Medium 375x812', size: const Size(375, 812)),
      (name: 'Large 430x932', size: const Size(430, 932)),
    ]) {
      testWidgets(
        'NotificationsPage renders cleanly without overflow on ${viewport.name}',
        (tester) async {
          await tester.binding.setSurfaceSize(viewport.size);
          addTearDown(() async => tester.binding.setSurfaceSize(null));

          bloc.add(const NotificationsStarted('user-1'));

          await tester.pumpWidget(
            MaterialApp(
              home: NotificationsPage(notificationBloc: bloc),
            ),
          );
          await _pumpBlocFrames(tester);

          expect(find.text('Notifications'), findsOneWidget);
          expect(find.text('Points Credited at Metro Fresh Mart'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
