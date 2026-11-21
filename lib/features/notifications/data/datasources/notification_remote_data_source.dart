import 'dart:async';

import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/features/notifications/data/models/notification_model.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_category.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_entity.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_filter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class NotificationRemoteDataSource {
  String? get currentUserId;

  Future<NotificationPageModel> getNotifications({
    required NotificationFilter filter,
    int limit = 20,
    int offset = 0,
    bool syncCampaigns = false,
  });

  Future<MarkNotificationReadResultModel> markNotificationAsRead(
    String notificationId,
  );

  Future<MarkAllNotificationsReadResultModel> markAllAsRead();

  Future<int> getUnreadCount();

  Stream<NotificationRealtimeEvent> watchNotifications({
    required String userId,
  });

  Stream<NotificationRealtimeConnectionState> get realtimeConnectionState;

  Future<void> stopRealtime();
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final SupabaseClient _supabaseClient;

  RealtimeChannel? _activeChannel;
  String? _activeUserId;
  StreamController<NotificationRealtimeEvent>? _eventsController;
  final StreamController<NotificationRealtimeConnectionState>
      _connectionController =
      StreamController<NotificationRealtimeConnectionState>.broadcast();

  NotificationRemoteDataSourceImpl(this._supabaseClient);

  @override
  String? get currentUserId => _supabaseClient.auth.currentUser?.id;

  String _requireUserId() {
    final uid = _supabaseClient.auth.currentUser?.id;
    if (uid == null || uid.trim().isEmpty) {
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }
    return uid;
  }

  @override
  Stream<NotificationRealtimeConnectionState> get realtimeConnectionState =>
      _connectionController.stream;

  Future<dynamic> _invokeRpc(
    String fn, {
    Map<String, dynamic>? params,
  }) async {
    try {
      return await _supabaseClient.rpc(fn, params: params);
    } on PostgrestException catch (error) {
      final msg = error.message.toLowerCase();
      if (error.code == 'PGRST301' ||
          msg.contains('jwt expired') ||
          msg.contains('unauthenticated')) {
        throw const AppAuthException(
          'Your session has expired. Please sign in again.',
          code: 'session_expired',
        );
      }
      if (error.code == 'PGRST202' ||
          error.code == '42P01' ||
          error.code == '42883') {
        throw const AppAuthException(
          'Notifications database schema is not deployed yet. Apply migration 20261119181500_create_customer_notifications_center.sql in Supabase and tap Try Again.',
          code: 'server_failure',
        );
      }
      throw const AppAuthException(
        'Unable to load notifications right now. Please try again.',
        code: 'server_failure',
      );
    }
  }

  @override
  Future<NotificationPageModel> getNotifications({
    required NotificationFilter filter,
    int limit = 20,
    int offset = 0,
    bool syncCampaigns = false,
  }) async {
    _requireUserId();

    if (syncCampaigns) {
      try {
        await _supabaseClient.rpc('sync_active_campaign_notifications');
      } catch (_) {
        // Non-fatal: active notification feed should still load cleanly.
      }
    }

    final response = await _invokeRpc(
      'get_customer_notifications',
      params: {
        'p_filter': filter.apiValue,
        'p_limit': limit,
        'p_offset': offset,
      },
    );

    if (response is! Map) {
      throw const AppAuthException(
        'Unable to load notifications right now.',
        code: 'server_failure',
      );
    }

    return NotificationPageModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  @override
  Future<MarkNotificationReadResultModel> markNotificationAsRead(
    String notificationId,
  ) async {
    _requireUserId();
    final response = await _invokeRpc(
      'mark_notification_as_read',
      params: {'p_notification_id': notificationId},
    );

    if (response is! Map) {
      throw const AppAuthException(
        'Unable to update notification status right now.',
        code: 'server_failure',
      );
    }

    return MarkNotificationReadResultModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  @override
  Future<MarkAllNotificationsReadResultModel> markAllAsRead() async {
    _requireUserId();
    final response = await _invokeRpc('mark_all_notifications_as_read');

    if (response is! Map) {
      throw const AppAuthException(
        'Unable to mark notifications as read right now.',
        code: 'server_failure',
      );
    }

    return MarkAllNotificationsReadResultModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  @override
  Future<int> getUnreadCount() async {
    _requireUserId();
    final response = await _invokeRpc('get_unread_notification_count');
    if (response is num) {
      return response.toInt();
    }
    return 0;
  }

  @override
  Stream<NotificationRealtimeEvent> watchNotifications({
    required String userId,
  }) {
    final authenticatedId = _requireUserId();
    if (userId != authenticatedId) {
      throw const AppAuthException(
        'Session user mismatch. Please sign in again.',
        code: 'session_expired',
      );
    }

    if (_activeUserId == authenticatedId &&
        _eventsController != null &&
        !_eventsController!.isClosed) {
      return _eventsController!.stream;
    }

    unawaited(_teardownChannelOnly());

    final controller =
        StreamController<NotificationRealtimeEvent>.broadcast();
    _eventsController = controller;
    _activeUserId = authenticatedId;
    _emitConnectionState(NotificationRealtimeConnectionState.connecting);

    final channel = _supabaseClient
        .channel('customer-notifications-$authenticatedId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: authenticatedId,
          ),
          callback: (payload) {
            if (controller.isClosed) return;
            final record = payload.newRecord;
            if (record.isEmpty) return;
            final model = NotificationModel.fromJson(
              Map<String, dynamic>.from(record),
            );
            if (model.userId == authenticatedId) {
              controller.add(
                NotificationRealtimeEvent(
                  eventType: NotificationRealtimeEventType.insert,
                  notification: model,
                ),
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: authenticatedId,
          ),
          callback: (payload) {
            if (controller.isClosed) return;
            final record = payload.newRecord;
            if (record.isEmpty) return;
            final model = NotificationModel.fromJson(
              Map<String, dynamic>.from(record),
            );
            if (model.userId == authenticatedId) {
              controller.add(
                NotificationRealtimeEvent(
                  eventType: NotificationRealtimeEventType.update,
                  notification: model,
                ),
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: authenticatedId,
          ),
          callback: (payload) {
            if (controller.isClosed) return;
            final oldId = (payload.oldRecord['id'] ?? '').toString();
            if (oldId.isNotEmpty) {
              controller.add(
                NotificationRealtimeEvent(
                  eventType: NotificationRealtimeEventType.delete,
                  deletedId: oldId,
                ),
              );
            }
          },
        );

    _activeChannel = channel;

    channel.subscribe((status, [error]) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          _emitConnectionState(NotificationRealtimeConnectionState.subscribed);
          break;
        case RealtimeSubscribeStatus.timedOut:
          _emitConnectionState(
            NotificationRealtimeConnectionState.reconnecting,
          );
          break;
        case RealtimeSubscribeStatus.channelError:
          _emitConnectionState(NotificationRealtimeConnectionState.error);
          break;
        case RealtimeSubscribeStatus.closed:
          _emitConnectionState(
            NotificationRealtimeConnectionState.disconnected,
          );
          break;
      }
    });

    return controller.stream;
  }

  @override
  Future<void> stopRealtime() async {
    _activeUserId = null;
    await _teardownChannelOnly();
    final controller = _eventsController;
    _eventsController = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
    _emitConnectionState(NotificationRealtimeConnectionState.disconnected);
  }

  Future<void> _teardownChannelOnly() async {
    final channel = _activeChannel;
    _activeChannel = null;
    if (channel != null) {
      try {
        await _supabaseClient.removeChannel(channel);
      } catch (_) {}
    }
  }

  void _emitConnectionState(NotificationRealtimeConnectionState state) {
    if (!_connectionController.isClosed) {
      _connectionController.add(state);
    }
  }
}
