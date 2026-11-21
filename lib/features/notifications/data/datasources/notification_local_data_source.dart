import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shiftex/features/notifications/data/models/notification_model.dart';

abstract class NotificationKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureNotificationKeyValueStore implements NotificationKeyValueStore {
  final FlutterSecureStorage _storage;
  final Map<String, String> _memoryFallback = <String, String>{};

  SecureNotificationKeyValueStore(this._storage);

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key) ?? _memoryFallback[key];
    } catch (_) {
      return _memoryFallback[key];
    }
  }

  @override
  Future<void> write(String key, String value) async {
    _memoryFallback[key] = value;
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // Fallback safely in headless test environments.
    }
  }

  @override
  Future<void> delete(String key) async {
    _memoryFallback.remove(key);
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}

abstract class NotificationLocalDataSource {
  Future<void> cachePage({
    required String userId,
    required NotificationPageModel page,
  });

  Future<NotificationPageModel?> getCachedPage({required String userId});

  Future<void> markNotificationReadLocally({
    required String userId,
    required String notificationId,
    required DateTime readAt,
  });

  Future<void> markAllReadLocally({
    required String userId,
    required DateTime readAt,
  });

  Future<void> clearCache({String? userId});
}

class NotificationLocalDataSourceImpl implements NotificationLocalDataSource {
  static const String _cachePrefix = 'notifications_center_v1_';
  final NotificationKeyValueStore _store;

  NotificationLocalDataSourceImpl(this._store);

  String _keyForUser(String userId) => '$_cachePrefix$userId';

  @override
  Future<void> cachePage({
    required String userId,
    required NotificationPageModel page,
  }) async {
    if (userId.trim().isEmpty) return;
    await _store.write(_keyForUser(userId), jsonEncode(page.toJson()));
  }

  @override
  Future<NotificationPageModel?> getCachedPage({required String userId}) async {
    if (userId.trim().isEmpty) return null;
    final raw = await _store.read(_keyForUser(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return NotificationPageModel.fromJson(
        Map<String, dynamic>.from(decoded),
        isFromCache: true,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> markNotificationReadLocally({
    required String userId,
    required String notificationId,
    required DateTime readAt,
  }) async {
    final cached = await getCachedPage(userId: userId);
    if (cached == null) return;

    var decremented = false;
    final updatedList = cached.notifications.map((item) {
      if (item.id == notificationId && item.isUnread) {
        decremented = true;
        return item.copyWith(readAt: readAt);
      }
      return item;
    }).toList();

    final newUnread = decremented
        ? (cached.counts.unread > 0 ? cached.counts.unread - 1 : 0)
        : cached.counts.unread;

    await cachePage(
      userId: userId,
      page: NotificationPageModel(
        filter: cached.filter,
        limit: cached.limit,
        offset: cached.offset,
        hasMore: cached.hasMore,
        counts: cached.counts.copyWith(unread: newUnread),
        notifications: updatedList,
        isFromCache: true,
      ),
    );
  }

  @override
  Future<void> markAllReadLocally({
    required String userId,
    required DateTime readAt,
  }) async {
    final cached = await getCachedPage(userId: userId);
    if (cached == null) return;

    final updatedList = cached.notifications
        .map((item) => item.isUnread ? item.copyWith(readAt: readAt) : item)
        .toList();

    await cachePage(
      userId: userId,
      page: NotificationPageModel(
        filter: cached.filter,
        limit: cached.limit,
        offset: cached.offset,
        hasMore: cached.hasMore,
        counts: cached.counts.copyWith(unread: 0),
        notifications: updatedList,
        isFromCache: true,
      ),
    );
  }

  @override
  Future<void> clearCache({String? userId}) async {
    if (userId != null && userId.trim().isNotEmpty) {
      await _store.delete(_keyForUser(userId));
    }
  }
}
