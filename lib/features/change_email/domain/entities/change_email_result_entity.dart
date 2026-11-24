import 'package:equatable/equatable.dart';

/// Lifecycle status of a Supabase Auth email change request.
enum ChangeEmailStatus {
  /// Confirmation link or 6-digit OTP has been sent; the current email remains
  /// active until verification is completed.
  pendingVerification,

  /// The new email address has been verified and synchronized on the existing
  /// user account UUID.
  completed,
}

/// Immutable result of an email change or verification check on the existing
/// authenticated Supabase user.
class ChangeEmailResultEntity extends Equatable {
  final String userId;
  final String currentEmail;
  final String targetEmail;
  final ChangeEmailStatus status;
  final String message;
  final String? emailChangeSentAt;
  final bool newEmailVerified;
  final bool currentEmailVerified;
  final bool requiresCurrentEmailVerification;

  const ChangeEmailResultEntity({
    required this.userId,
    required this.currentEmail,
    required this.targetEmail,
    required this.status,
    required this.message,
    this.emailChangeSentAt,
    this.newEmailVerified = false,
    this.currentEmailVerified = false,
    this.requiresCurrentEmailVerification = false,
  });

  bool get isCompleted => status == ChangeEmailStatus.completed;

  bool get isPendingVerification =>
      status == ChangeEmailStatus.pendingVerification;

  /// Returns which email address should be verified next when Secure Email
  /// Change (double confirmation) is active.
  String get nextEmailToVerify {
    if (newEmailVerified && !currentEmailVerified && currentEmail.isNotEmpty) {
      return currentEmail;
    }
    return targetEmail;
  }

  /// True when the next 6-digit OTP to verify belongs to [currentEmail]
  /// (step 2 of Secure Email Change after [targetEmail] was already verified).
  bool get shouldVerifyCurrentEmailNext =>
      newEmailVerified && !currentEmailVerified && currentEmail.isNotEmpty;

  ChangeEmailResultEntity copyWith({
    String? userId,
    String? currentEmail,
    String? targetEmail,
    ChangeEmailStatus? status,
    String? message,
    String? emailChangeSentAt,
    bool? newEmailVerified,
    bool? currentEmailVerified,
    bool? requiresCurrentEmailVerification,
  }) {
    return ChangeEmailResultEntity(
      userId: userId ?? this.userId,
      currentEmail: currentEmail ?? this.currentEmail,
      targetEmail: targetEmail ?? this.targetEmail,
      status: status ?? this.status,
      message: message ?? this.message,
      emailChangeSentAt: emailChangeSentAt ?? this.emailChangeSentAt,
      newEmailVerified: newEmailVerified ?? this.newEmailVerified,
      currentEmailVerified: currentEmailVerified ?? this.currentEmailVerified,
      requiresCurrentEmailVerification:
          requiresCurrentEmailVerification ??
          this.requiresCurrentEmailVerification,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    currentEmail,
    targetEmail,
    status,
    message,
    emailChangeSentAt,
    newEmailVerified,
    currentEmailVerified,
    requiresCurrentEmailVerification,
  ];
}
