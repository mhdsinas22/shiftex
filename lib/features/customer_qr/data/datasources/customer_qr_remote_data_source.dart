import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/features/customer_qr/data/models/customer_qr_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class CustomerQrRemoteDataSource {
  Future<CustomerQrModel> getCustomerPersonalQr({
    bool forceRegenerate = false,
  });

  Future<bool> revokePersonalQr();
}

class CustomerQrRemoteDataSourceImpl implements CustomerQrRemoteDataSource {
  final SupabaseClient _supabaseClient;

  const CustomerQrRemoteDataSourceImpl(this._supabaseClient);

  @override
  Future<CustomerQrModel> getCustomerPersonalQr({
    bool forceRegenerate = false,
  }) async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) {
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }

    final dynamic raw = await _supabaseClient.rpc(
      'get_customer_personal_qr',
      params: {'p_force_regenerate': forceRegenerate},
    );

    final map = _unwrapJsonMap(raw);
    if (map == null) {
      throw const AppAuthException(
        'Unable to load your personal QR pass right now.',
        code: 'invalid_qr_response',
      );
    }

    final model = CustomerQrModel.fromJson(map);
    if (model.qrPayload.isEmpty ||
        model.membershipId.isEmpty ||
        !model.isAccrualOnly) {
      throw const AppAuthException(
        'Received an invalid accrual QR pass from the server.',
        code: 'invalid_accrual_qr',
      );
    }

    return model;
  }

  @override
  Future<bool> revokePersonalQr() async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) {
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }

    final dynamic raw = await _supabaseClient.rpc('revoke_customer_personal_qr');
    final map = _unwrapJsonMap(raw);
    return map?['revoked'] as bool? ?? true;
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
}
