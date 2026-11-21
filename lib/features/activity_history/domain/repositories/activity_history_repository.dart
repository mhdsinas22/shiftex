import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_filter.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_history_page_entity.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_transaction_entity.dart';
import 'package:shiftex/features/activity_history/domain/entities/monthly_statement_entity.dart';

abstract class ActivityHistoryRepository {
  Future<Either<Failure, ActivityHistoryPageEntity>> getActivityHistory({
    ActivityFilter filter = ActivityFilter.all,
    int limit = 20,
    int offset = 0,
    String? timezone,
  });

  Future<Either<Failure, ActivityTransactionDetailsEntity>>
  getTransactionDetail({required String entryId});

  Future<Either<Failure, MonthlyStatementEntity>> getMonthlyStatement({
    required int year,
    required int month,
    String? timezone,
  });

  Future<Either<Failure, ExportedStatementResultEntity>>
  exportMonthlyStatement({
    required int year,
    required int month,
    required StatementExportFormat format,
    String? timezone,
  });
}
