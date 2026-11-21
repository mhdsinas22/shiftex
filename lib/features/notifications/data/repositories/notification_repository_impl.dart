import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/error_mapper.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/notifications/data/datasources/notification_local_data_source.dart';
import 'package:shiftex/features/notifications/data/datasources/notification_remote_data_source.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_category.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_entity.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_filter.dart';
import 'package:shiftex/features/notifications/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource _remoteDataSource;
  final NotificationLocalDataSource _localDataSource;

  const NotificationRepositoryImpl({
    required NotificationRemoteDataSource remoteDataSource,
    required NotificationLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  @override
  Future<Either<Failure, NotificationPageEntity>> getNotifications({
    required NotificationFilter filter,
    int limit = 20,
    int offset = 0,
    bool syncCampaigns = false,
  }) async {
    final uid = _remoteDataSource.currentUserId;
    try {
      final page = await _remoteDataSource.getNotifications(
        filter: filter,
        limit: limit,
        offset: offset,
        syncCampaigns: syncCampaigns,
      );

      if (uid != null &&
          filter == NotificationFilter.all &&
          offset == 0) {
        await _localDataSource.cachePage(userId: uid, page: page);
      }
      return Right(page);
    } catch (error) {
      final failure = ErrorMapper.mapExceptionToFailure(error);
      // Preserve offline usability on network drops by serving cached items for this exact user.
      if (failure is NetworkFailure && uid != null && offset == 0) {
        final cached = await _localDataSource.getCachedPage(userId: uid);
        if (cached != null) {
          final filteredItems = _applyLocalFilter(
            cached.notifications,
            filter,
          );
          return Right(
            NotificationPageEntity(
              filter: filter,
              limit: limit,
              offset: 0,
              hasMore: false,
              counts: cached.counts,
              notifications: filteredItems,
              isFromCache: true,
            ),
          );
        }
      }
      return Left(failure);
    }
  }

  List<NotificationEntity> _applyLocalFilter(
    List<NotificationEntity> source,
    NotificationFilter filter,
  ) {
    switch (filter) {
      case NotificationFilter.all:
        return source;
      case NotificationFilter.unread:
        return source.where((n) => n.isUnread).toList();
      case NotificationFilter.pointsRewards:
        return source
            .where((n) => n.category == NotificationCategory.pointsRewards)
            .toList();
      case NotificationFilter.announcements:
        return source
            .where((n) => n.category == NotificationCategory.announcements)
            .toList();
    }
  }

  @override
  Future<Either<Failure, MarkNotificationReadResultEntity>>
      markNotificationAsRead(String notificationId) async {
    final uid = _remoteDataSource.currentUserId;
    try {
      final result = await _remoteDataSource.markNotificationAsRead(
        notificationId,
      );
      if (uid != null) {
        await _localDataSource.markNotificationReadLocally(
          userId: uid,
          notificationId: notificationId,
          readAt: result.readAt,
        );
      }
      return Right(result);
    } catch (error) {
      return Left(ErrorMapper.mapExceptionToFailure(error));
    }
  }

  @override
  Future<Either<Failure, MarkAllNotificationsReadResultEntity>>
      markAllAsRead() async {
    final uid = _remoteDataSource.currentUserId;
    try {
      final result = await _remoteDataSource.markAllAsRead();
      if (uid != null) {
        await _localDataSource.markAllReadLocally(
          userId: uid,
          readAt: result.readAt,
        );
      }
      return Right(result);
    } catch (error) {
      return Left(ErrorMapper.mapExceptionToFailure(error));
    }
  }

  @override
  Future<Either<Failure, int>> getUnreadCount() async {
    try {
      final count = await _remoteDataSource.getUnreadCount();
      return Right(count);
    } catch (error) {
      final failure = ErrorMapper.mapExceptionToFailure(error);
      final uid = _remoteDataSource.currentUserId;
      if (failure is NetworkFailure && uid != null) {
        final cached = await _localDataSource.getCachedPage(userId: uid);
        if (cached != null) {
          return Right(cached.counts.unread);
        }
      }
      return Left(failure);
    }
  }

  @override
  Stream<NotificationRealtimeEvent> watchNotifications({
    required String userId,
  }) {
    return _remoteDataSource.watchNotifications(userId: userId);
  }

  @override
  Stream<NotificationRealtimeConnectionState> get realtimeConnectionState =>
      _remoteDataSource.realtimeConnectionState;

  @override
  Future<void> stopRealtimeAndClearCache({String? userId}) async {
    await _remoteDataSource.stopRealtime();
    await _localDataSource.clearCache(userId: userId);
  }
}
