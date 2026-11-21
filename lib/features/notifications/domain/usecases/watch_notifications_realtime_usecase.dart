import 'package:shiftex/features/notifications/domain/entities/notification_category.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_entity.dart';
import 'package:shiftex/features/notifications/domain/repositories/notification_repository.dart';

class WatchNotificationsRealtimeUseCase {
  final NotificationRepository _repository;

  const WatchNotificationsRealtimeUseCase(this._repository);

  Stream<NotificationRealtimeEvent> call({required String userId}) {
    return _repository.watchNotifications(userId: userId);
  }

  Stream<NotificationRealtimeConnectionState> get connectionStateStream =>
      _repository.realtimeConnectionState;

  Future<void> stop({String? userId}) {
    return _repository.stopRealtimeAndClearCache(userId: userId);
  }
}
