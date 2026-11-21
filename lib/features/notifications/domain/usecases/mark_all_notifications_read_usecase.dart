import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_entity.dart';
import 'package:shiftex/features/notifications/domain/repositories/notification_repository.dart';

class MarkAllNotificationsReadUseCase {
  final NotificationRepository _repository;

  const MarkAllNotificationsReadUseCase(this._repository);

  Future<Either<Failure, MarkAllNotificationsReadResultEntity>> call() {
    return _repository.markAllAsRead();
  }
}
