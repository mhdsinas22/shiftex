import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const String _rememberMeKey = 'shiiftex_remember_me';
  static const String _rememberedIdentifierKey =
      'shiiftex_remembered_identifier';
  static const String _pendingVerificationEmailKey =
      'shiiftex_pending_verification_email';
  static const String _pendingFullNameKey = 'shiiftex_pending_full_name';
  static const String _pendingMobileKey = 'shiiftex_pending_mobile';

  final FlutterSecureStorage _storage;

  const SecureStorageService(this._storage);

  Future<void> saveRememberMe({
    required bool rememberMe,
    required String identifier,
  }) async {
    try {
      await _storage.write(
        key: _rememberMeKey,
        value: rememberMe ? 'true' : 'false',
      );
      if (rememberMe && identifier.trim().isNotEmpty) {
        await _storage.write(
          key: _rememberedIdentifierKey,
          value: identifier.trim(),
        );
      } else {
        await _storage.delete(key: _rememberedIdentifierKey);
      }
    } catch (_) {
      // Fail gracefully if platform keychain is unavailable in unit tests
    }
  }

  Future<bool> getRememberMe() async {
    try {
      final val = await _storage.read(key: _rememberMeKey);
      return val == null || val == 'true';
    } catch (_) {
      return true;
    }
  }

  Future<String?> getRememberedIdentifier() async {
    try {
      return await _storage.read(key: _rememberedIdentifierKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> savePendingRegistrationContext({
    required String email,
    required String fullName,
    required String mobileNumber,
  }) async {
    try {
      await _storage.write(
        key: _pendingVerificationEmailKey,
        value: email.trim().toLowerCase(),
      );
      await _storage.write(key: _pendingFullNameKey, value: fullName.trim());
      await _storage.write(
        key: _pendingMobileKey,
        value: mobileNumber.trim(),
      );
    } catch (_) {}
  }

  Future<Map<String, String?>> getPendingRegistrationContext() async {
    try {
      final email = await _storage.read(key: _pendingVerificationEmailKey);
      final fullName = await _storage.read(key: _pendingFullNameKey);
      final mobile = await _storage.read(key: _pendingMobileKey);
      return {
        'email': email,
        'fullName': fullName,
        'mobileNumber': mobile,
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> clearPendingRegistrationContext() async {
    try {
      await _storage.delete(key: _pendingVerificationEmailKey);
      await _storage.delete(key: _pendingFullNameKey);
      await _storage.delete(key: _pendingMobileKey);
    } catch (_) {}
  }
}
