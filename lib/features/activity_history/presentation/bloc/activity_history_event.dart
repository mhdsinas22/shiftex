import 'package:equatable/equatable.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_filter.dart';
import 'package:shiftex/features/activity_history/domain/entities/monthly_statement_entity.dart';

abstract class ActivityHistoryEvent extends Equatable {
  const ActivityHistoryEvent();

  @override
  List<Object?> get props => [];
}

class ActivityHistoryLoadRequested extends ActivityHistoryEvent {
  final bool forceRefresh;

  const ActivityHistoryLoadRequested({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class ActivityHistoryRefreshed extends ActivityHistoryEvent {
  const ActivityHistoryRefreshed();
}

class ActivityFilterChanged extends ActivityHistoryEvent {
  final ActivityFilter filter;

  const ActivityFilterChanged(this.filter);

  @override
  List<Object?> get props => [filter];
}

class ActivityLoadMoreRequested extends ActivityHistoryEvent {
  const ActivityLoadMoreRequested();
}

class ActivityTransactionExpandedToggled extends ActivityHistoryEvent {
  final String entryId;

  const ActivityTransactionExpandedToggled(this.entryId);

  @override
  List<Object?> get props => [entryId];
}

class ActivityMonthlyStatementExportRequested extends ActivityHistoryEvent {
  final int year;
  final int month;
  final StatementExportFormat format;

  const ActivityMonthlyStatementExportRequested({
    required this.year,
    required this.month,
    required this.format,
  });

  @override
  List<Object?> get props => [year, month, format];
}

class ActivityFeedbackCleared extends ActivityHistoryEvent {
  const ActivityFeedbackCleared();
}
