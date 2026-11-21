import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_category.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_entity.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_filter.dart';

abstract class NotificationRepository {
  Future<Either<Failure, NotificationPageEntity>> getNotifications({
    required NotificationFilter filter,
    int limit = 20,
    int offset = 0,
    bool syncCampaigns = false,
  });

  Future<Either<Failure, MarkNotificationReadResultEntity>>
      markNotificationAsRead(String notificationId);

  Future<Either<Failure, MarkAllNotificationsReadResultEntity>> markAllAsRead();

  Future<Either<Failure, int>> getUnreadCount();

  Stream<NotificationRealtimeEvent> watchNotifications({
    required String userId,
  });

  Stream<NotificationRealtimeConnectionState> get realtimeConnectionState;

  Future<void> stopRealtimeAndClearCache({String? userId});
}
