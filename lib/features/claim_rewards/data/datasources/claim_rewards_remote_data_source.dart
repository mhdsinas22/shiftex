import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/features/claim_rewards/data/models/claim_rewards_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ClaimRewardsRemoteDataSource {
  Future<ClaimWalletContextModel> getClaimRewardsContext();

  Future<ClaimOperationResultModel> createRewardClaim({
    required int points,
    String? idempotencyKey,
  });

  Future<ClaimOperationResultModel> getCustomerClaimStatus({
    required String claimId,
  });

  Future<ClaimOperationResultModel> cancelRewardClaim({
    required String claimId,
  });
}

class ClaimRewardsRemoteDataSourceImpl implements ClaimRewardsRemoteDataSource {
  final SupabaseClient _supabaseClient;

  const ClaimRewardsRemoteDataSourceImpl(this._supabaseClient);

  void _requireAuthenticatedUser() {
    if (_supabaseClient.auth.currentUser == null) {
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }
  }

  @override
  Future<ClaimWalletContextModel> getClaimRewardsContext() async {
    _requireAuthenticatedUser();
    try {
      final dynamic raw = await _supabaseClient.rpc('get_claim_rewards_context');
      final map = _unwrapJsonMap(raw);
      if (map == null) {
        throw const AppAuthException(
          'Unable to load claim balance details right now.',
          code: 'server_failure',
        );
      }
      return ClaimWalletContextModel.fromJson(map);
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  @override
  Future<ClaimOperationResultModel> createRewardClaim({
    required int points,
    String? idempotencyKey,
  }) async {
    _requireAuthenticatedUser();
    try {
      final dynamic raw = await _supabaseClient.rpc(
        'create_customer_reward_claim',
        params: {
          'p_points': points,
          if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty)
            'p_idempotency_key': idempotencyKey.trim(),
        },
      );
      final map = _unwrapJsonMap(raw);
      if (map == null) {
        throw const AppAuthException(
          'Unable to generate your Claim QR right now.',
          code: 'server_failure',
        );
      }
      final result = ClaimOperationResultModel.fromJson(map);
      if (result.claim.claimReference.isEmpty || !result.claim.hasSecurePayload) {
        throw const AppAuthException(
          'Received an invalid claim token format from the server.',
          code: 'server_failure',
        );
      }
      return result;
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  @override
  Future<ClaimOperationResultModel> getCustomerClaimStatus({
    required String claimId,
  }) async {
    _requireAuthenticatedUser();
    try {
      final dynamic raw = await _supabaseClient.rpc(
        'get_customer_claim_status',
        params: {'p_claim_id': claimId},
      );
      final map = _unwrapJsonMap(raw);
      if (map == null) {
        throw const AppAuthException(
          'Unable to refresh claim status right now.',
          code: 'server_failure',
        );
      }
      return ClaimOperationResultModel.fromJson(map);
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  @override
  Future<ClaimOperationResultModel> cancelRewardClaim({
    required String claimId,
  }) async {
    _requireAuthenticatedUser();
    try {
      final dynamic raw = await _supabaseClient.rpc(
        'cancel_customer_reward_claim',
        params: {'p_claim_id': claimId},
      );
      final map = _unwrapJsonMap(raw);
      if (map == null) {
        throw const AppAuthException(
          'Unable to cancel the pending claim right now.',
          code: 'server_failure',
        );
      }
      return ClaimOperationResultModel.fromJson(map);
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
        'Only approved customers can claim rewards.',
        code: 'pending_approval',
      );
    }

    for (final prefix in [
      'INSUFFICIENT_BALANCE:',
      'INVALID_AMOUNT:',
      'INVALID_RATE:',
      'INVALID_CLAIM:',
      'CLAIM_NOT_FOUND:',
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
          ? 'Unable to process claim request right now. Please try again.'
          : msg.trim(),
      code: 'server_failure',
    );
  }
}
