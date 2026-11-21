import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_entity.dart';
import 'package:shiftex/features/notifications/domain/repositories/notification_repository.dart';

class MarkNotificationReadUseCase {
  final NotificationRepository _repository;

  const MarkNotificationReadUseCase(this._repository);

  Future<Either<Failure, MarkNotificationReadResultEntity>> call(
    String notificationId,
  ) {
    return _repository.markNotificationAsRead(notificationId);
  }
}
