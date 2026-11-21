import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/extensions/context_extensions.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_filter.dart';
import 'package:shiftex/features/activity_history/presentation/bloc/activity_history_bloc.dart';
import 'package:shiftex/features/activity_history/presentation/bloc/activity_history_event.dart';
import 'package:shiftex/features/activity_history/presentation/bloc/activity_history_state.dart';
import 'package:shiftex/features/activity_history/presentation/widgets/history_filter_bar.dart';
import 'package:shiftex/features/activity_history/presentation/widgets/monthly_statement_button.dart';
import 'package:shiftex/features/activity_history/presentation/widgets/statement_export_sheet.dart';
import 'package:shiftex/features/activity_history/presentation/widgets/transaction_date_group.dart';
import 'package:shiftex/features/activity_history/presentation/widgets/wallet_summary_card.dart';
import 'package:shiftex/injection_container.dart';

/// Complete Activity & History screen displaying verified wallet totals,
/// filtered & paginated ledger records grouped by date, expandable audit
/// details, locked point breakdowns, and monthly PDF/CSV statement export.
class ActivityHistoryPage extends StatefulWidget {
  final ActivityHistoryBloc? bloc;
  final DateTime Function()? clockProvider;

  const ActivityHistoryPage({super.key, this.bloc, this.clockProvider});

  @override
  State<ActivityHistoryPage> createState() => _ActivityHistoryPageState();
}

class _ActivityHistoryPageState extends State<ActivityHistoryPage> {
  late final ActivityHistoryBloc _bloc;
  late final bool _ownsBloc;
  late final ScrollController _scrollController;
  int _lastFeedbackSequence = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);

    if (widget.bloc != null) {
      _bloc = widget.bloc!;
      _ownsBloc = false;
    } else {
      ActivityHistoryBloc? parentBloc;
      try {
        parentBloc = context.read<ActivityHistoryBloc>();
      } catch (_) {
        parentBloc = null;
      }
      if (parentBloc != null) {
        _bloc = parentBloc;
        _ownsBloc = false;
      } else {
        _bloc = getIt<ActivityHistoryBloc>();
        _ownsBloc = true;
      }
    }

    if (_bloc.state.status == ActivityHistoryStatus.initial) {
      _bloc.add(const ActivityHistoryLoadRequested());
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _bloc.add(const ActivityLoadMoreRequested());
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    if (_ownsBloc) {
      _bloc.close();
    }
    super.dispose();
  }

  void _navigateToHome() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(RoutesNames.home);
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final hPad = responsive.sheetHorizontalPadding;

    return BlocProvider<ActivityHistoryBloc>.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        extendBody: true,

        body: SafeArea(
          bottom: false,
          child: BlocConsumer<ActivityHistoryBloc, ActivityHistoryState>(
            listenWhen: (previous, current) =>
                previous.feedbackSequence != current.feedbackSequence,
            listener: (context, state) {
              if (state.feedbackSequence == _lastFeedbackSequence) {
                return;
              }
              _lastFeedbackSequence = state.feedbackSequence;
              if (state.errorMessage != null && state.summary != null) {
                context.showFeedbackSnackBar(
                  state.errorMessage!,
                  isError: true,
                );
                _bloc.add(const ActivityFeedbackCleared());
              } else if (state.feedbackMessage != null) {
                context.showFeedbackSnackBar(
                  state.feedbackMessage!,
                  isError: false,
                );
                _bloc.add(const ActivityFeedbackCleared());
              }
            },
            builder: (context, state) {
              final isInitialLoading =
                  state.status == ActivityHistoryStatus.loading &&
                  state.summary == null;
              final isInitialError =
                  state.status == ActivityHistoryStatus.error &&
                  state.summary == null;
              final sections = TransactionDateGrouper.group(
                state.transactions,
                nowLocal: widget.clockProvider?.call(),
              );

              return RefreshIndicator(
                color: AppColors.primaryBlue,
                onRefresh: () async {
                  final completion = _bloc.stream
                      .firstWhere((s) => !s.isBusy)
                      .timeout(
                        const Duration(seconds: 15),
                        onTimeout: () => _bloc.state,
                      );
                  _bloc.add(const ActivityHistoryRefreshed());
                  try {
                    await completion;
                  } on StateError {
                    // Stream closed before refresh completed.
                  }
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 114),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: responsive.maxContentWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(state),
                          const SizedBox(height: 16),
                          if (isInitialLoading)
                            _buildLoadingSkeleton()
                          else if (isInitialError)
                            _buildErrorView(
                              message:
                                  state.errorMessage ??
                                  'Unable to load your transaction history.',
                            )
                          else ...[
                            if (state.summary != null) ...[
                              WalletSummaryCard(summary: state.summary!),
                              const SizedBox(height: 18),
                            ],
                            HistoryFilterBar(
                              selectedFilter: state.activeFilter,
                              onFilterChanged: (filter) =>
                                  _bloc.add(ActivityFilterChanged(filter)),
                            ),
                            const SizedBox(height: 16),
                            if (state.status == ActivityHistoryStatus.loading)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: LinearProgressIndicator(
                                  minHeight: 2.5,
                                  color: AppColors.primaryBlue,
                                  backgroundColor: AppColors.inputBackground,
                                ),
                              ),
                            if (sections.isEmpty &&
                                state.status != ActivityHistoryStatus.loading)
                              _buildEmptyFilterCard(state.activeFilter)
                            else
                              for (int i = 0; i < sections.length; i++) ...[
                                if (i > 0) const SizedBox(height: 18),
                                TransactionDateGroup(
                                  section: sections[i],
                                  expandedIds: state.expandedTransactionIds,
                                  loadingDetailIds: state.loadingDetailIds,
                                  onToggleExpand: (entryId) => _bloc.add(
                                    ActivityTransactionExpandedToggled(entryId),
                                  ),
                                ),
                              ],
                            if (state.status ==
                                ActivityHistoryStatus.loadingMore) ...[
                              const SizedBox(height: 16),
                              const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            MonthlyStatementButton(
                              isBusy:
                                  state.status ==
                                  ActivityHistoryStatus.exporting,
                              onPressed: () => StatementExportSheet.show(
                                context,
                                bloc: _bloc,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ActivityHistoryState state) {
    final code = state.summary?.customerCode;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Activity & History',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                code != null
                    ? 'Verified rewards ledger • $code'
                    : 'Verified rewards ledger',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: AppColors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _navigateToHome,
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return Column(
      children: [
        Container(
          height: 190,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < 3; i++) ...[
          Container(
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildErrorView({required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.errorBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: AppColors.errorRed,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _bloc.add(
              const ActivityHistoryLoadRequested(forceRefresh: true),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: AppColors.white,
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilterCard(ActivityFilter filter) {
    final emptyMsg = switch (filter) {
      ActivityFilter.all => 'No reward transactions recorded yet.',
      ActivityFilter.earned => 'No earned credits found for your account yet.',
      ActivityFilter.claims => 'No completed claim redemptions recorded yet.',
      ActivityFilter.dailyStreak =>
        'No daily streak reward activity recorded yet.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 34,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 10),
          Text(
            emptyMsg,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'New POS rewards, daily streak check-ins, and claim redemptions will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
