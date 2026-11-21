import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_filter.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_history_page_entity.dart';
import 'package:shiftex/features/activity_history/domain/repositories/activity_history_repository.dart';

class GetActivityHistoryParams extends Equatable {
  final ActivityFilter filter;
  final int limit;
  final int offset;
  final String? timezone;

  const GetActivityHistoryParams({
    this.filter = ActivityFilter.all,
    this.limit = 20,
    this.offset = 0,
    this.timezone,
  });

  @override
  List<Object?> get props => [filter, limit, offset, timezone];
}

class GetActivityHistoryUseCase
    implements UseCase<ActivityHistoryPageEntity, GetActivityHistoryParams> {
  final ActivityHistoryRepository _repository;

  const GetActivityHistoryUseCase(this._repository);

  @override
  Future<Either<Failure, ActivityHistoryPageEntity>> call(
    GetActivityHistoryParams params,
  ) {
    return _repository.getActivityHistory(
      filter: params.filter,
      limit: params.limit,
      offset: params.offset,
      timezone: params.timezone,
    );
  }
}
