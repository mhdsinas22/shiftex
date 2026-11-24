import 'package:shiftex/core/errors/exceptions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote contract backed by Supabase Auth for re-authenticating and updating
/// the current customer's password.
abstract class ChangePasswordRemoteDataSource {
  /// Re-authenticates the active session user with [currentPassword] and updates
  /// their password to [newPassword] via Supabase Auth.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}

/// Supabase Auth implementation of [ChangePasswordRemoteDataSource].
class ChangePasswordRemoteDataSourceImpl
    implements ChangePasswordRemoteDataSource {
  final SupabaseClient _supabaseClient;

  const ChangePasswordRemoteDataSourceImpl(this._supabaseClient);

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final session = _supabaseClient.auth.currentSession;
    final user = _supabaseClient.auth.currentUser;

    if (session == null || user == null) {
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }

    if (session.isExpired) {
      await _refreshActiveSession();
    }

    final email = (user.email ?? '').trim();
    if (email.isEmpty) {
      throw const AppAuthException(
        'Unable to verify your account email for password change.',
        code: 'validation_failure',
      );
    }

    if (currentPassword.isEmpty) {
      throw const AppAuthException(
        'Current password is required.',
        code: 'validation_failure',
      );
    }

    if (newPassword == currentPassword) {
      throw const AppAuthException(
        'New password must be different from your current password.',
        code: 'validation_failure',
      );
    }

    await _verifyCurrentPassword(
      email: email,
      currentPassword: currentPassword,
    );

    await _updateUserPassword(newPassword);
  }

  Future<void> _refreshActiveSession() async {
    try {
      final refreshed = await _supabaseClient.auth.refreshSession();
      if (refreshed.session == null || refreshed.user == null) {
        throw const AppAuthException(
          'Your session has expired. Please sign in again.',
          code: 'session_expired',
        );
      }
    } on AppAuthException {
      rethrow;
    } on AuthException {
      throw const AppAuthException(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    }
  }

  Future<void> _verifyCurrentPassword({
    required String email,
    required String currentPassword,
  }) async {
    try {
      final response = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      if (response.user == null || response.session == null) {
        throw const AppAuthException(
          'Current password is incorrect. Please check and try again.',
          code: 'invalid_credentials',
        );
      }
    } on AuthException catch (error) {
      final code = (error.code ?? '').toLowerCase();
      final msg = error.message.toLowerCase();
      if (code == 'invalid_credentials' ||
          msg.contains('invalid login credentials') ||
          msg.contains('invalid email or password')) {
        throw const AppAuthException(
          'Current password is incorrect. Please check and try again.',
          code: 'invalid_credentials',
        );
      }
      rethrow;
    }
  }

  Future<void> _updateUserPassword(String newPassword) async {
    try {
      final response = await _supabaseClient.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      if (response.user == null) {
        throw const AppAuthException(
          'Unable to update your password right now. Please try again.',
          code: 'server_failure',
        );
      }
    } on AuthException catch (error) {
      final code = (error.code ?? '').toLowerCase();
      final msg = error.message.toLowerCase();
      if (code == 'same_password' ||
          msg.contains('new password should be different')) {
        throw const AppAuthException(
          'New password must be different from your current password.',
          code: 'validation_failure',
        );
      }
      if (code == 'weak_password' || msg.contains('weak_password')) {
        throw const AppAuthException(
          'Password does not meet security requirements. Use uppercase, lowercase, a number, and a special character.',
          code: 'validation_failure',
        );
      }
      rethrow;
    }
  }
}
