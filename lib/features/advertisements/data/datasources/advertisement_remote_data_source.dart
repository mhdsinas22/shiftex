import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/features/advertisements/data/models/advertisement_model.dart';
import 'package:shiftex/features/advertisements/domain/entities/advertisement_event_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AdvertisementRemoteDataSource {
  Future<List<AdvertisementModel>> fetchActiveAdvertisements({
    required String userId,
    required String sessionId,
  });

  Future<void> trackEvent({
    required String advertisementId,
    required AdvertisementEventType eventType,
    required String sessionId,
    Map<String, dynamic> metadata = const {},
  });
}

class AdvertisementRemoteDataSourceImpl
    implements AdvertisementRemoteDataSource {
  final SupabaseClient _supabaseClient;

  const AdvertisementRemoteDataSourceImpl(this._supabaseClient);

  @override
  Future<List<AdvertisementModel>> fetchActiveAdvertisements({
    required String userId,
    required String sessionId,
  }) async {
    final currentUser = _supabaseClient.auth.currentUser;
    if (currentUser == null || currentUser.id != userId) {
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }

    final response = await _supabaseClient.rpc(
      'get_active_customer_advertisements',
      params: {
        'p_customer_id': userId,
        'p_session_id': sessionId,
      },
    );

    if (response is! List) {
      return const [];
    }

    return response
        .whereType<Map>()
        .map(
          (row) => AdvertisementModel.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  @override
  Future<void> trackEvent({
    required String advertisementId,
    required AdvertisementEventType eventType,
    required String sessionId,
    Map<String, dynamic> metadata = const {},
  }) async {
    final currentUser = _supabaseClient.auth.currentUser;
    if (currentUser == null) {
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }

    await _supabaseClient.rpc(
      'track_advertisement_event',
      params: {
        'p_advertisement_id': advertisementId,
        'p_event_type': eventType.rpcValue,
        'p_session_id': sessionId,
        'p_metadata': metadata,
      },
    );
  }
}
