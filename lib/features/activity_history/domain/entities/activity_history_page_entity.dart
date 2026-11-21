import 'package:equatable/equatable.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_filter.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_transaction_entity.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_wallet_summary_entity.dart';

class ActivityHistoryPageEntity extends Equatable {
  final ActivityWalletSummaryEntity summary;
  final ActivityFilter filter;
  final int limit;
  final int offset;
  final bool hasMore;
  final List<ActivityTransactionEntity> transactions;

  const ActivityHistoryPageEntity({
    required this.summary,
    required this.filter,
    required this.limit,
    required this.offset,
    required this.hasMore,
    required this.transactions,
  });

  @override
  List<Object?> get props => [
    summary,
    filter,
    limit,
    offset,
    hasMore,
    transactions,
  ];
}
