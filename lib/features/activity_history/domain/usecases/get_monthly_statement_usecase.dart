import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/activity_history/domain/entities/monthly_statement_entity.dart';
import 'package:shiftex/features/activity_history/domain/repositories/activity_history_repository.dart';

class GetMonthlyStatementParams extends Equatable {
  final int year;
  final int month;
  final String? timezone;

  const GetMonthlyStatementParams({
    required this.year,
    required this.month,
    this.timezone,
  });

  @override
  List<Object?> get props => [year, month, timezone];
}

class GetMonthlyStatementUseCase
    implements UseCase<MonthlyStatementEntity, GetMonthlyStatementParams> {
  final ActivityHistoryRepository _repository;

  const GetMonthlyStatementUseCase(this._repository);

  @override
  Future<Either<Failure, MonthlyStatementEntity>> call(
    GetMonthlyStatementParams params,
  ) {
    return _repository.getMonthlyStatement(
      year: params.year,
      month: params.month,
      timezone: params.timezone,
    );
  }
}
