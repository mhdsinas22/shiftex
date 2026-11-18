import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/home/domain/entities/home_dashboard_entity.dart';
import 'package:shiftex/features/home/domain/repositories/home_repository.dart';

class GetHomeDashboardParams extends Equatable {
  final bool performDailyCheckIn;
  final String? sessionId;

  const GetHomeDashboardParams({
    this.performDailyCheckIn = true,
    this.sessionId,
  });

  @override
  List<Object?> get props => [performDailyCheckIn, sessionId];
}

class GetHomeDashboardUseCase
    implements UseCase<HomeDashboardEntity, GetHomeDashboardParams> {
  final HomeRepository _repository;

  const GetHomeDashboardUseCase(this._repository);

  @override
  Future<Either<Failure, HomeDashboardEntity>> call(
    GetHomeDashboardParams params,
  ) {
    return _repository.getHomeDashboard(
      performDailyCheckIn: params.performDailyCheckIn,
      sessionId: params.sessionId,
    );
  }
}
