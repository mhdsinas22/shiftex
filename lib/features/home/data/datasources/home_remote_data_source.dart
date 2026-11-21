import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/features/home/data/models/home_dashboard_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class HomeRemoteDataSource {
  Future<HomeDashboardModel> getHomeDashboard({
    bool performDailyCheckIn = true,
    String? sessionId,
  });

  Future<CustomerQrTokenModel> generateClaimQrToken();

  Future<void> trackAdvertisementEvent({
    required String advertisementId,
    required String eventType,
    String? sessionId,
  });
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final SupabaseClient _supabaseClient;

  const HomeRemoteDataSourceImpl(this._supabaseClient);

  @override
  Future<HomeDashboardModel> getHomeDashboard({
    bool performDailyCheckIn = true,
    String? sessionId,
  }) async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) {
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }

    final dashboardResponse = await _supabaseClient.rpc(
      'get_customer_home_dashboard',
      params: {
        'p_auto_checkin': performDailyCheckIn,
      },
    );

    if (dashboardResponse is! Map) {
      throw const AppAuthException(
        'Unable to load dashboard data right now.',
        code: 'server_failure',
      );
    }

    final dashboardJson = Map<String, dynamic>.from(dashboardResponse);

    return HomeDashboardModel.fromJson(dashboardJson);
  }

  @override
  Future<CustomerQrTokenModel> generateClaimQrToken() async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) {
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }

    final response = await _supabaseClient.rpc('generate_customer_claim_qr');
    if (response is Map) {
      return CustomerQrTokenModel.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    if (response is List && response.isNotEmpty && response.first is Map) {
      return CustomerQrTokenModel.fromJson(
        Map<String, dynamic>.from(response.first as Map),
      );
    }

    throw const AppAuthException(
      'Unable to generate claim QR code right now.',
      code: 'server_failure',
    );
  }

  @override
  Future<void> trackAdvertisementEvent({
    required String advertisementId,
    required String eventType,
    String? sessionId,
  }) async {
    await _supabaseClient.rpc(
      'track_advertisement_event',
      params: {
        'p_advertisement_id': advertisementId,
        'p_event_type': eventType,
        'p_session_id': sessionId,
      },
    );
  }
}
