import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/features/activity_history/data/models/activity_history_models.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_filter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ActivityHistoryRemoteDataSource {
  Future<ActivityHistoryPageModel> getActivityHistory({
    ActivityFilter filter = ActivityFilter.all,
    int limit = 20,
    int offset = 0,
    String? timezone,
  });

  Future<ActivityTransactionDetailsModel> getTransactionDetail({
    required String entryId,
  });

  Future<MonthlyStatementModel> getMonthlyStatement({
    required int year,
    required int month,
    String? timezone,
  });
}

class ActivityHistoryRemoteDataSourceImpl
    implements ActivityHistoryRemoteDataSource {
  final SupabaseClient _supabaseClient;

  const ActivityHistoryRemoteDataSourceImpl(this._supabaseClient);

  void _requireAuthenticatedUser() {
    if (_supabaseClient.auth.currentUser == null) {
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }
  }

  @override
  Future<ActivityHistoryPageModel> getActivityHistory({
    ActivityFilter filter = ActivityFilter.all,
    int limit = 20,
    int offset = 0,
    String? timezone,
  }) async {
    _requireAuthenticatedUser();
    try {
      final dynamic raw = await _supabaseClient.rpc(
        'get_customer_activity_history',
        params: {
          'p_filter': filter.rpcValue,
          'p_limit': limit,
          'p_offset': offset,
          if (timezone != null && timezone.trim().isNotEmpty)
            'p_timezone': timezone.trim(),
        },
      );
      final map = _unwrapJsonMap(raw);
      if (map == null) {
        throw const AppAuthException(
          'Unable to load activity history right now.',
          code: 'server_failure',
        );
      }
      return ActivityHistoryPageModel.fromJson(map);
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  @override
  Future<ActivityTransactionDetailsModel> getTransactionDetail({
    required String entryId,
  }) async {
    _requireAuthenticatedUser();
    try {
      final dynamic raw = await _supabaseClient.rpc(
        'get_customer_transaction_detail',
        params: {'p_entry_id': entryId},
      );
      final map = _unwrapJsonMap(raw);
      if (map == null) {
        throw const AppAuthException(
          'Unable to load transaction details right now.',
          code: 'server_failure',
        );
      }
      return ActivityTransactionDetailsModel.fromJson(map);
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  @override
  Future<MonthlyStatementModel> getMonthlyStatement({
    required int year,
    required int month,
    String? timezone,
  }) async {
    _requireAuthenticatedUser();
    try {
      final dynamic raw = await _supabaseClient.rpc(
        'get_customer_monthly_statement',
        params: {
          'p_year': year,
          'p_month': month,
          if (timezone != null && timezone.trim().isNotEmpty)
            'p_timezone': timezone.trim(),
        },
      );
      final map = _unwrapJsonMap(raw);
      if (map == null) {
        throw const AppAuthException(
          'Unable to generate monthly statement right now.',
          code: 'server_failure',
        );
      }
      return MonthlyStatementModel.fromJson(map);
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  Map<String, dynamic>? _unwrapJsonMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map<String, dynamic>) {
        return first;
      }
      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }
    return null;
  }

  AppAuthException _mapPostgrestError(PostgrestException error) {
    final msg = error.message;
    if (msg.contains('UNAUTHENTICATED') ||
        error.code == 'PGRST301' ||
        msg.toLowerCase().contains('jwt expired')) {
      return const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }
    if (msg.contains('ACCOUNT_NOT_APPROVED')) {
      return const AppAuthException(
        'Only approved customers can access reward activity history.',
        code: 'pending_approval',
      );
    }
    for (final prefix in [
      'INVALID_MONTH:',
      'INVALID_ENTRY:',
      'TRANSACTION_NOT_FOUND:',
    ]) {
      final idx = msg.indexOf(prefix);
      if (idx >= 0) {
        final detail = msg.substring(idx + prefix.length).trim();
        return AppAuthException(
          detail.isEmpty ? msg : detail,
          code: 'validation_failure',
        );
      }
    }

    return AppAuthException(
      msg.trim().isEmpty
          ? 'Unable to load reward activity right now. Please try again.'
          : msg.trim(),
      code: 'server_failure',
    );
  }
}
