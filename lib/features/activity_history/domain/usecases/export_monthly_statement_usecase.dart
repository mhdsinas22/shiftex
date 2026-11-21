import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/activity_history/domain/entities/monthly_statement_entity.dart';
import 'package:shiftex/features/activity_history/domain/repositories/activity_history_repository.dart';

class ExportMonthlyStatementParams extends Equatable {
  final int year;
  final int month;
  final StatementExportFormat format;
  final String? timezone;

  const ExportMonthlyStatementParams({
    required this.year,
    required this.month,
    required this.format,
    this.timezone,
  });

  @override
  List<Object?> get props => [year, month, format, timezone];
}

class ExportMonthlyStatementUseCase
    implements
        UseCase<ExportedStatementResultEntity, ExportMonthlyStatementParams> {
  final ActivityHistoryRepository _repository;

  const ExportMonthlyStatementUseCase(this._repository);

  @override
  Future<Either<Failure, ExportedStatementResultEntity>> call(
    ExportMonthlyStatementParams params,
  ) {
    if (params.month < 1 || params.month > 12 || params.year < 2020) {
      return Future.value(
        const Left(ValidationFailure('Select a valid month and year.')),
      );
    }
    return _repository.exportMonthlyStatement(
      year: params.year,
      month: params.month,
      format: params.format,
      timezone: params.timezone,
    );
  }
}
