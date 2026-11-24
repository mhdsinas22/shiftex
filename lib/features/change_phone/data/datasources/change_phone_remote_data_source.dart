import 'package:flutter/foundation.dart';
import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/core/extensions/string_extensions.dart';
import 'package:shiftex/core/services/secure_storage_service.dart';
import 'package:shiftex/core/utils/validators.dart';
import 'package:shiftex/features/change_phone/domain/entities/change_phone_result_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote contract backed by Supabase for directly updating the authenticated
/// customer's `public.profiles.mobile_number` on their existing user UUID.
abstract class ChangePhoneRemoteDataSource {
  Future<ChangePhoneResultEntity> changePhoneNumber({
    required String newPhoneNumber,
    String? currentPhoneNumber,
  });
}

/// Supabase implementation of [ChangePhoneRemoteDataSource].
///
/// Updates `public.profiles.mobile_number` in-place for the currently
/// authenticated user UUID without OTP, email confirmation, password
/// verification, or sign-out.
class ChangePhoneRemoteDataSourceImpl implements ChangePhoneRemoteDataSource {
  final SupabaseClient _supabaseClient;
  final SecureStorageService? _secureStorageService;

  const ChangePhoneRemoteDataSourceImpl(
    this._supabaseClient, {
    SecureStorageService? secureStorageService,
  }) : _secureStorageService = secureStorageService;

  void _logDebug(String step, Map<String, Object?> details) {
    if (!kDebugMode) return;
    final formatted = details.entries
        .map((e) => '${e.key}=${e.value}')
        .join(', ');
    debugPrint('[ChangePhoneRemoteDataSource] $step | $formatted');
  }

  @override
  Future<ChangePhoneResultEntity> changePhoneNumber({
    required String newPhoneNumber,
    String? currentPhoneNumber,
  }) async {
    final session = _supabaseClient.auth.currentSession;
    final user = _supabaseClient.auth.currentUser;

    if (session == null || user == null) {
      _logDebug('changePhoneNumber.noSession', {
        'hasSession': session != null,
        'hasUser': user != null,
      });
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }

    final originalUserId = user.id;
    final trimmedInput = newPhoneNumber.trim();

    final validationError = Validators.validateNewPhoneNumber(
      trimmedInput,
      currentPhoneNumber: currentPhoneNumber,
    );
    if (validationError != null) {
      throw AppAuthException(
        validationError,
        code: 'validation_failure',
      );
    }

    // Fetch current profile row if currentPhoneNumber was not provided
    String existingMobile = (currentPhoneNumber ?? '').trim();
    if (existingMobile.isEmpty) {
      final currentRow =
          await _supabaseClient
              .from('profiles')
              .select('id, mobile_number')
              .eq('id', originalUserId)
              .maybeSingle();

      if (currentRow == null) {
        throw const AppAuthException(
          'Unable to locate your customer profile. Please try again.',
          code: 'server_failure',
        );
      }

      final fetchedId = (currentRow['id'] as String?) ?? '';
      if (fetchedId != originalUserId) {
        throw const AppAuthException(
          'Account identity mismatch detected. Phone update aborted.',
          code: 'session_expired',
        );
      }

      existingMobile = (currentRow['mobile_number'] as String? ?? '').trim();
      final sameCheckError = Validators.validateNewPhoneNumber(
        trimmedInput,
        currentPhoneNumber: existingMobile,
      );
      if (sameCheckError != null) {
        throw AppAuthException(
          sameCheckError,
          code: 'validation_failure',
        );
      }
    }

    final normalizedNewMobile = trimmedInput.normalizeMobile();

    _logDebug('changePhoneNumber.updatingProfile', {
      'userId': originalUserId,
    });

    final updatedRow =
        await _supabaseClient
            .from('profiles')
            .update({'mobile_number': normalizedNewMobile})
            .eq('id', originalUserId)
            .select('id, mobile_number')
            .single();

    final updatedUserId = (updatedRow['id'] as String? ?? '').trim();
    if (updatedUserId != originalUserId) {
      throw const AppAuthException(
        'Account UUID mismatch detected. Phone update aborted to protect your data.',
        code: 'session_expired',
      );
    }

    final savedMobile =
        (updatedRow['mobile_number'] as String? ?? normalizedNewMobile).trim();

    await _syncRememberedPhoneIfNeeded(savedMobile);

    _logDebug('changePhoneNumber.success', {
      'userId': originalUserId,
    });

    return ChangePhoneResultEntity(
      userId: originalUserId,
      previousPhoneNumber: existingMobile,
      updatedPhoneNumber: savedMobile,
      displayPhoneNumber: trimmedInput,
      message:
          'Your registered phone number has been updated to $savedMobile.',
    );
  }

  Future<void> _syncRememberedPhoneIfNeeded(String updatedMobile) async {
    final storage = _secureStorageService;
    if (storage == null) return;

    final rememberMe = await storage.getRememberMe();
    final rememberedIdentifier = await storage.getRememberedIdentifier();
    if (rememberMe &&
        rememberedIdentifier != null &&
        rememberedIdentifier.trim().isNotEmpty &&
        !rememberedIdentifier.contains('@')) {
      await storage.saveRememberMe(
        rememberMe: true,
        identifier: updatedMobile,
      );
    }
  }
}
