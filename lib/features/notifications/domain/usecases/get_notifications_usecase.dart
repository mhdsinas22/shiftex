import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_entity.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_filter.dart';
import 'package:shiftex/features/notifications/domain/repositories/notification_repository.dart';

class GetNotificationsParams extends Equatable {
  final NotificationFilter filter;
  final int limit;
  final int offset;
  final bool syncCampaigns;

  const GetNotificationsParams({
    this.filter = NotificationFilter.all,
    this.limit = 20,
    this.offset = 0,
    this.syncCampaigns = false,
  });

  @override
  List<Object?> get props => [filter, limit, offset, syncCampaigns];
}

class GetNotificationsUseCase {
  final NotificationRepository _repository;

  const GetNotificationsUseCase(this._repository);

  Future<Either<Failure, NotificationPageEntity>> call(
    GetNotificationsParams params,
  ) {
    return _repository.getNotifications(
      filter: params.filter,
      limit: params.limit,
      offset: params.offset,
      syncCampaigns: params.syncCampaigns,
    );
  }
}
