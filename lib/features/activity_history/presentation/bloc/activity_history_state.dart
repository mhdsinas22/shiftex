import 'package:equatable/equatable.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_filter.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_transaction_entity.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_wallet_summary_entity.dart';
import 'package:shiftex/features/activity_history/domain/entities/monthly_statement_entity.dart';

enum ActivityHistoryStatus {
  initial,
  loading,
  loaded,
  loadingMore,
  exporting,
  exportSuccess,
  error,
}

class ActivityHistoryState extends Equatable {
  final ActivityHistoryStatus status;
  final ActivityWalletSummaryEntity? summary;
  final ActivityFilter activeFilter;
  final List<ActivityTransactionEntity> transactions;
  final bool hasMore;
  final int currentOffset;
  final Set<String> expandedTransactionIds;
  final Set<String> loadingDetailIds;
  final ExportedStatementResultEntity? lastExportedStatement;
  final String? errorMessage;
  final String? feedbackMessage;
  final int feedbackSequence;

  const ActivityHistoryState({
    this.status = ActivityHistoryStatus.initial,
    this.summary,
    this.activeFilter = ActivityFilter.all,
    this.transactions = const [],
    this.hasMore = false,
    this.currentOffset = 0,
    this.expandedTransactionIds = const {},
    this.loadingDetailIds = const {},
    this.lastExportedStatement,
    this.errorMessage,
    this.feedbackMessage,
    this.feedbackSequence = 0,
  });

  bool get isBusy =>
      status == ActivityHistoryStatus.loading ||
      status == ActivityHistoryStatus.loadingMore ||
      status == ActivityHistoryStatus.exporting;

  ActivityHistoryState copyWith({
    ActivityHistoryStatus? status,
    ActivityWalletSummaryEntity? summary,
    ActivityFilter? activeFilter,
    List<ActivityTransactionEntity>? transactions,
    bool? hasMore,
    int? currentOffset,
    Set<String>? expandedTransactionIds,
    Set<String>? loadingDetailIds,
    ExportedStatementResultEntity? lastExportedStatement,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? feedbackMessage,
    bool clearFeedbackMessage = false,
    int? feedbackSequence,
  }) {
    return ActivityHistoryState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      activeFilter: activeFilter ?? this.activeFilter,
      transactions: transactions ?? this.transactions,
      hasMore: hasMore ?? this.hasMore,
      currentOffset: currentOffset ?? this.currentOffset,
      expandedTransactionIds:
          expandedTransactionIds ?? this.expandedTransactionIds,
      loadingDetailIds: loadingDetailIds ?? this.loadingDetailIds,
      lastExportedStatement:
          lastExportedStatement ?? this.lastExportedStatement,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      feedbackMessage:
          clearFeedbackMessage
              ? null
              : (feedbackMessage ?? this.feedbackMessage),
      feedbackSequence: feedbackSequence ?? this.feedbackSequence,
    );
  }

  @override
  List<Object?> get props => [
    status,
    summary,
    activeFilter,
    transactions,
    hasMore,
    currentOffset,
    expandedTransactionIds,
    loadingDetailIds,
    lastExportedStatement,
    errorMessage,
    feedbackMessage,
    feedbackSequence,
  ];
}
