import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/notifications/domain/repositories/notification_repository.dart';

class GetUnreadNotificationCountUseCase {
  final NotificationRepository _repository;

  const GetUnreadNotificationCountUseCase(this._repository);

  Future<Either<Failure, int>> call() {
    return _repository.getUnreadCount();
  }
}
