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

    // Fetch active, published, date-valid, customer-eligible advertisements
    List<AdvertisementCampaignModel> activeAds = const [];
    try {
      final adsResponse = await _supabaseClient.rpc(
        'get_active_customer_advertisements',
        params: {
          'p_customer_id': user.id,
          'p_session_id': sessionId,
        },
      );

      if (adsResponse is List) {
        final now = DateTime.now().toUtc();
        activeAds =
            adsResponse
                .whereType<Map>()
                .map(
                  (item) => AdvertisementCampaignModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where(
                  (ad) =>
                      !ad.startAt.isAfter(now) && !ad.endAt.isBefore(now),
                )
                .toList();
      }
    } catch (_) {
      // Non-fatal if advertisements table is empty or unreachable
      activeAds = const [];
    }

    return HomeDashboardModel.fromJson(
      dashboardJson,
      advertisements: activeAds,
    );
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
