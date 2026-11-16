import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/features/account_approval/data/models/customer_profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AccountApprovalRemoteDataSource {
  Future<CustomerProfileModel> ensureCustomerProfile({
    String? fullName,
    String? mobileNumber,
  });

  Future<CustomerProfileModel> fetchCurrentCustomerProfile();
}

class AccountApprovalRemoteDataSourceImpl
    implements AccountApprovalRemoteDataSource {
  final SupabaseClient _supabaseClient;

  const AccountApprovalRemoteDataSourceImpl(this._supabaseClient);

  @override
  Future<CustomerProfileModel> ensureCustomerProfile({
    String? fullName,
    String? mobileNumber,
  }) async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) {
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }

    final response = await _supabaseClient.rpc(
      'ensure_customer_profile',
      params: {
        'p_full_name': fullName,
        'p_mobile_number': mobileNumber,
      },
    );

    if (response is Map<String, dynamic>) {
      return CustomerProfileModel.fromJson(response);
    }

    if (response is List && response.isNotEmpty) {
      return CustomerProfileModel.fromJson(
        Map<String, dynamic>.from(response.first as Map),
      );
    }

    return fetchCurrentCustomerProfile();
  }

  @override
  Future<CustomerProfileModel> fetchCurrentCustomerProfile() async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) {
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }

    final row =
        await _supabaseClient
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

    if (row != null) {
      return CustomerProfileModel.fromJson(row);
    }

    // If profile row does not yet exist for a confirmed user, create idempotently
    return ensureCustomerProfile(
      fullName: user.userMetadata?['full_name'] as String?,
      mobileNumber: user.userMetadata?['mobile_number'] as String?,
    );
  }
}
