import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/error_mapper.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/activity_history/data/datasources/activity_history_remote_data_source.dart';
import 'package:shiftex/features/activity_history/data/datasources/statement_exporter_service.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_filter.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_history_page_entity.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_transaction_entity.dart';
import 'package:shiftex/features/activity_history/domain/entities/monthly_statement_entity.dart';
import 'package:shiftex/features/activity_history/domain/repositories/activity_history_repository.dart';

class ActivityHistoryRepositoryImpl implements ActivityHistoryRepository {
  final ActivityHistoryRemoteDataSource _remoteDataSource;
  final StatementExporterService _statementExporterService;

  const ActivityHistoryRepositoryImpl({
    required ActivityHistoryRemoteDataSource remoteDataSource,
    required StatementExporterService statementExporterService,
  }) : _remoteDataSource = remoteDataSource,
       _statementExporterService = statementExporterService;

  @override
  Future<Either<Failure, ActivityHistoryPageEntity>> getActivityHistory({
    ActivityFilter filter = ActivityFilter.all,
    int limit = 20,
    int offset = 0,
    String? timezone,
  }) async {
    try {
      final page = await _remoteDataSource.getActivityHistory(
        filter: filter,
        limit: limit,
        offset: offset,
        timezone: timezone,
      );
      return Right(page);
    } catch (e) {
      return Left(ErrorMapper.mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, ActivityTransactionDetailsEntity>>
  getTransactionDetail({required String entryId}) async {
    try {
      final detail = await _remoteDataSource.getTransactionDetail(
        entryId: entryId,
      );
      return Right(detail);
    } catch (e) {
      return Left(ErrorMapper.mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, MonthlyStatementEntity>> getMonthlyStatement({
    required int year,
    required int month,
    String? timezone,
  }) async {
    try {
      final statement = await _remoteDataSource.getMonthlyStatement(
        year: year,
        month: month,
        timezone: timezone,
      );
      return Right(statement);
    } catch (e) {
      return Left(ErrorMapper.mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, ExportedStatementResultEntity>>
  exportMonthlyStatement({
    required int year,
    required int month,
    required StatementExportFormat format,
    String? timezone,
  }) async {
    try {
      final statement = await _remoteDataSource.getMonthlyStatement(
        year: year,
        month: month,
        timezone: timezone,
      );
      final result = await _statementExporterService.generateAndShare(
        statement: statement,
        format: format,
      );
      return Right(result);
    } catch (e) {
      return Left(ErrorMapper.mapExceptionToFailure(e));
    }
  }
}
