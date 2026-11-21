import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_transaction_entity.dart';
import 'package:shiftex/features/activity_history/domain/entities/monthly_statement_entity.dart';
import 'package:shiftex/features/activity_history/domain/usecases/export_monthly_statement_usecase.dart';
import 'package:shiftex/features/activity_history/domain/usecases/get_activity_history_usecase.dart';
import 'package:shiftex/features/activity_history/domain/usecases/get_transaction_detail_usecase.dart';
import 'package:shiftex/features/activity_history/presentation/bloc/activity_history_event.dart';
import 'package:shiftex/features/activity_history/presentation/bloc/activity_history_state.dart';

class ActivityHistoryBloc
    extends Bloc<ActivityHistoryEvent, ActivityHistoryState> {
  static const int pageSize = 20;

  final GetActivityHistoryUseCase _getActivityHistoryUseCase;
  final GetTransactionDetailUseCase _getTransactionDetailUseCase;
  final ExportMonthlyStatementUseCase _exportMonthlyStatementUseCase;

  int _activeRequestToken = 0;

  ActivityHistoryBloc({
    required GetActivityHistoryUseCase getActivityHistoryUseCase,
    required GetTransactionDetailUseCase getTransactionDetailUseCase,
    required ExportMonthlyStatementUseCase exportMonthlyStatementUseCase,
  }) : _getActivityHistoryUseCase = getActivityHistoryUseCase,
       _getTransactionDetailUseCase = getTransactionDetailUseCase,
       _exportMonthlyStatementUseCase = exportMonthlyStatementUseCase,
       super(const ActivityHistoryState()) {
    on<ActivityHistoryLoadRequested>(_onLoadRequested);
    on<ActivityHistoryRefreshed>(_onRefreshed);
    on<ActivityFilterChanged>(_onFilterChanged);
    on<ActivityLoadMoreRequested>(_onLoadMoreRequested);
    on<ActivityTransactionExpandedToggled>(_onExpandedToggled);
    on<ActivityMonthlyStatementExportRequested>(_onExportRequested);
    on<ActivityFeedbackCleared>(_onFeedbackCleared);
  }

  Future<void> _onLoadRequested(
    ActivityHistoryLoadRequested event,
    Emitter<ActivityHistoryState> emit,
  ) async {
    if (state.status == ActivityHistoryStatus.loading && !event.forceRefresh) {
      return;
    }

    final token = ++_activeRequestToken;
    emit(
      state.copyWith(
        status: ActivityHistoryStatus.loading,
        clearErrorMessage: true,
        clearFeedbackMessage: true,
      ),
    );

    final result = await _getActivityHistoryUseCase(
      GetActivityHistoryParams(
        filter: state.activeFilter,
        limit: pageSize,
        offset: 0,
      ),
    );

    if (token != _activeRequestToken) return;

    result.fold(
      (failure) => emit(
        state.copyWith(
          status:
              state.summary != null
                  ? ActivityHistoryStatus.loaded
                  : ActivityHistoryStatus.error,
          errorMessage: failure.message,
          feedbackSequence: state.feedbackSequence + 1,
        ),
      ),
      (page) => emit(
        state.copyWith(
          status: ActivityHistoryStatus.loaded,
          summary: page.summary,
          activeFilter: page.filter,
          transactions: page.transactions,
          hasMore: page.hasMore,
          currentOffset: page.transactions.length,
          clearErrorMessage: true,
        ),
      ),
    );
  }

  Future<void> _onRefreshed(
    ActivityHistoryRefreshed event,
    Emitter<ActivityHistoryState> emit,
  ) async {
    final token = ++_activeRequestToken;
    final result = await _getActivityHistoryUseCase(
      GetActivityHistoryParams(
        filter: state.activeFilter,
        limit: pageSize,
        offset: 0,
      ),
    );

    if (token != _activeRequestToken) return;

    result.fold(
      (failure) => emit(
        state.copyWith(
          status:
              state.summary != null
                  ? ActivityHistoryStatus.loaded
                  : ActivityHistoryStatus.error,
          errorMessage: failure.message,
          feedbackSequence: state.feedbackSequence + 1,
        ),
      ),
      (page) => emit(
        state.copyWith(
          status: ActivityHistoryStatus.loaded,
          summary: page.summary,
          activeFilter: page.filter,
          transactions: page.transactions,
          hasMore: page.hasMore,
          currentOffset: page.transactions.length,
          clearErrorMessage: true,
        ),
      ),
    );
  }

  Future<void> _onFilterChanged(
    ActivityFilterChanged event,
    Emitter<ActivityHistoryState> emit,
  ) async {
    if (event.filter == state.activeFilter &&
        state.status == ActivityHistoryStatus.loaded) {
      return;
    }

    final token = ++_activeRequestToken;
    emit(
      state.copyWith(
        status: ActivityHistoryStatus.loading,
        activeFilter: event.filter,
        expandedTransactionIds: const {},
        clearErrorMessage: true,
      ),
    );

    final result = await _getActivityHistoryUseCase(
      GetActivityHistoryParams(
        filter: event.filter,
        limit: pageSize,
        offset: 0,
      ),
    );

    if (token != _activeRequestToken) return;

    result.fold(
      (failure) => emit(
        state.copyWith(
          status:
              state.summary != null
                  ? ActivityHistoryStatus.loaded
                  : ActivityHistoryStatus.error,
          errorMessage: failure.message,
          feedbackSequence: state.feedbackSequence + 1,
        ),
      ),
      (page) => emit(
        state.copyWith(
          status: ActivityHistoryStatus.loaded,
          summary: page.summary,
          activeFilter: page.filter,
          transactions: page.transactions,
          hasMore: page.hasMore,
          currentOffset: page.transactions.length,
          clearErrorMessage: true,
        ),
      ),
    );
  }

  Future<void> _onLoadMoreRequested(
    ActivityLoadMoreRequested event,
    Emitter<ActivityHistoryState> emit,
  ) async {
    if (!state.hasMore || state.isBusy) {
      return;
    }

    final token = ++_activeRequestToken;
    emit(state.copyWith(status: ActivityHistoryStatus.loadingMore));

    final result = await _getActivityHistoryUseCase(
      GetActivityHistoryParams(
        filter: state.activeFilter,
        limit: pageSize,
        offset: state.currentOffset,
      ),
    );

    if (token != _activeRequestToken) return;

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ActivityHistoryStatus.loaded,
          errorMessage: failure.message,
          feedbackSequence: state.feedbackSequence + 1,
        ),
      ),
      (page) {
        final seenIds = state.transactions.map((t) => t.id).toSet();
        final merged = List<ActivityTransactionEntity>.from(state.transactions);
        for (final tx in page.transactions) {
          if (seenIds.add(tx.id)) {
            merged.add(tx);
          }
        }
        emit(
          state.copyWith(
            status: ActivityHistoryStatus.loaded,
            summary: page.summary,
            transactions: merged,
            hasMore: page.hasMore,
            currentOffset: merged.length,
            clearErrorMessage: true,
          ),
        );
      },
    );
  }

  Future<void> _onExpandedToggled(
    ActivityTransactionExpandedToggled event,
    Emitter<ActivityHistoryState> emit,
  ) async {
    final nextExpanded = Set<String>.from(state.expandedTransactionIds);
    if (nextExpanded.contains(event.entryId)) {
      nextExpanded.remove(event.entryId);
      emit(state.copyWith(expandedTransactionIds: nextExpanded));
      return;
    }

    nextExpanded.add(event.entryId);
    final idx = state.transactions.indexWhere((t) => t.id == event.entryId);
    if (idx < 0) {
      emit(state.copyWith(expandedTransactionIds: nextExpanded));
      return;
    }

    final target = state.transactions[idx];
    if (!target.isExpandable || target.hasLoadedDetailedAudit) {
      emit(state.copyWith(expandedTransactionIds: nextExpanded));
      return;
    }

    final nextLoadingDetails = Set<String>.from(state.loadingDetailIds)
      ..add(event.entryId);
    emit(
      state.copyWith(
        expandedTransactionIds: nextExpanded,
        loadingDetailIds: nextLoadingDetails,
      ),
    );

    final result = await _getTransactionDetailUseCase(
      GetTransactionDetailParams(entryId: event.entryId),
    );

    final finishedLoadingDetails = Set<String>.from(state.loadingDetailIds)
      ..remove(event.entryId);

    result.fold(
      (failure) => emit(
        state.copyWith(
          loadingDetailIds: finishedLoadingDetails,
          errorMessage: failure.message,
          feedbackSequence: state.feedbackSequence + 1,
        ),
      ),
      (detail) {
        final updatedList = List<ActivityTransactionEntity>.from(
          state.transactions,
        );
        final currentIdx = updatedList.indexWhere((t) => t.id == event.entryId);
        if (currentIdx >= 0) {
          updatedList[currentIdx] = updatedList[currentIdx].copyWith(
            details: detail,
            hasLoadedDetailedAudit: true,
          );
        }
        emit(
          state.copyWith(
            transactions: updatedList,
            loadingDetailIds: finishedLoadingDetails,
            clearErrorMessage: true,
          ),
        );
      },
    );
  }

  Future<void> _onExportRequested(
    ActivityMonthlyStatementExportRequested event,
    Emitter<ActivityHistoryState> emit,
  ) async {
    if (state.status == ActivityHistoryStatus.exporting) {
      return;
    }

    emit(
      state.copyWith(
        status: ActivityHistoryStatus.exporting,
        clearErrorMessage: true,
        clearFeedbackMessage: true,
      ),
    );

    final result = await _exportMonthlyStatementUseCase(
      ExportMonthlyStatementParams(
        year: event.year,
        month: event.month,
        format: event.format,
        timezone: state.summary?.timezone,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status:
              state.summary != null
                  ? ActivityHistoryStatus.loaded
                  : ActivityHistoryStatus.error,
          errorMessage: failure.message,
          feedbackSequence: state.feedbackSequence + 1,
        ),
      ),
      (exported) => emit(
        state.copyWith(
          status: ActivityHistoryStatus.exportSuccess,
          lastExportedStatement: exported,
          feedbackMessage:
              '${exported.format == StatementExportFormat.pdf ? 'PDF' : 'CSV'} statement generated (${exported.fileName}).',
          feedbackSequence: state.feedbackSequence + 1,
          clearErrorMessage: true,
        ),
      ),
    );
  }

  void _onFeedbackCleared(
    ActivityFeedbackCleared event,
    Emitter<ActivityHistoryState> emit,
  ) {
    emit(state.copyWith(clearErrorMessage: true, clearFeedbackMessage: true));
  }
}
