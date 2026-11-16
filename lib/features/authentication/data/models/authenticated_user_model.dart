import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';
import 'package:shiftex/features/authentication/domain/entities/authenticated_user_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthenticatedUserModel extends AuthenticatedUserEntity {
  const AuthenticatedUserModel({
    required super.id,
    required super.email,
    required super.fullName,
    required super.mobileNumber,
    required super.isEmailVerified,
    super.profile,
  });

  factory AuthenticatedUserModel.fromSupabaseUser(
    User user, {
    CustomerProfileEntity? profile,
  }) {
    final meta = user.userMetadata ?? const <String, dynamic>{};
    final firstName = (meta['first_name'] as String?)?.trim() ?? '';
    final lastName = (meta['last_name'] as String?)?.trim() ?? '';
    final fullName =
        profile?.fullName ??
        (meta['full_name'] as String?)?.trim() ??
        '$firstName $lastName'.trim();
    final mobile =
        profile?.mobileNumber ??
        (meta['mobile_number'] as String?)?.trim() ??
        user.phone ??
        '';

    return AuthenticatedUserModel(
      id: user.id,
      email: (user.email ?? profile?.email ?? '').toLowerCase(),
      fullName: fullName,
      mobileNumber: mobile,
      isEmailVerified: user.emailConfirmedAt != null,
      profile: profile,
    );
  }
}
