import 'package:equatable/equatable.dart';

/// Base event class for [ChangeEmailBloc].
abstract class ChangeEmailEvent extends Equatable {
  const ChangeEmailEvent();

  @override
  List<Object?> get props => [];

  @override
  bool get stringify => false;
}

/// Initializes or updates the read-only current registered email address.
class InitializeChangeEmail extends ChangeEmailEvent {
  final String currentEmail;

  const InitializeChangeEmail(this.currentEmail);

  @override
  List<Object?> get props => [currentEmail];
}

/// Fired whenever the New Email input field changes.
class NewEmailChanged extends ChangeEmailEvent {
  final String value;

  const NewEmailChanged(this.value);

  @override
  List<Object?> get props => [value];
}

/// Fired whenever the Confirm New Email input field changes.
class ConfirmNewEmailChanged extends ChangeEmailEvent {
  final String value;

  const ConfirmNewEmailChanged(this.value);

  @override
  List<Object?> get props => [value];
}

/// Fired whenever the Current Password input field changes.
class CurrentPasswordForEmailChanged extends ChangeEmailEvent {
  final String value;

  const CurrentPasswordForEmailChanged(this.value);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => 'CurrentPasswordForEmailChanged(redacted)';
}

/// Toggles password masking on the Current Password input field.
class ToggleChangeEmailPasswordVisibility extends ChangeEmailEvent {
  const ToggleChangeEmailPasswordVisibility();
}

/// Submits the validated Change Email form to Supabase Auth.
class SubmitChangeEmail extends ChangeEmailEvent {
  const SubmitChangeEmail();
}

/// Fired whenever the 6-digit verification code input changes in pending state.
class EmailChangeOtpChanged extends ChangeEmailEvent {
  final String value;

  const EmailChangeOtpChanged(this.value);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => 'EmailChangeOtpChanged(length: ${value.length})';
}

/// Switches which email inbox's 6-digit code is being entered when Secure
/// Email Change (double confirmation) is enabled.
class SelectEmailChangeOtpTarget extends ChangeEmailEvent {
  final bool verifyCurrentEmail;

  const SelectEmailChangeOtpTarget({required this.verifyCurrentEmail});

  @override
  List<Object?> get props => [verifyCurrentEmail];
}

/// Resumes an already-pending Supabase Auth email change request so the user
/// can enter their 6-digit OTP code without re-submitting the form.
class ResumePendingEmailChange extends ChangeEmailEvent {
  final String userId;
  final String currentEmail;
  final String targetEmail;
  final String? emailChangeSentAt;

  const ResumePendingEmailChange({
    required this.userId,
    required this.currentEmail,
    required this.targetEmail,
    this.emailChangeSentAt,
  });

  @override
  List<Object?> get props => [
    userId,
    currentEmail,
    targetEmail,
    emailChangeSentAt,
  ];
}

/// Verifies the 6-digit email change OTP code with Supabase Auth.
class VerifyChangeEmailOtpRequested extends ChangeEmailEvent {
  const VerifyChangeEmailOtpRequested();
}

/// Resends the email change confirmation email / OTP code.
class ResendChangeEmailVerificationRequested extends ChangeEmailEvent {
  const ResendChangeEmailVerificationRequested();
}

/// Refreshes the Supabase session/user to check if the confirmation link was clicked.
class CheckChangeEmailStatusRequested extends ChangeEmailEvent {
  const CheckChangeEmailStatusRequested();
}

/// Returns from the pending verification view back to the form so the user can
/// edit the target email address.
class EditPendingNewEmailRequested extends ChangeEmailEvent {
  const EditPendingNewEmailRequested();
}

/// Triggered when an external deep link or auth state listener confirms the
/// target email while the Change Email screen is open.
class MarkChangeEmailConfirmedExternally extends ChangeEmailEvent {
  final String confirmedEmail;
  final String userId;

  const MarkChangeEmailConfirmedExternally({
    required this.confirmedEmail,
    required this.userId,
  });

  @override
  List<Object?> get props => [confirmedEmail, userId];
}

/// Resets transient form and state data back to initial defaults.
class ResetChangeEmailState extends ChangeEmailEvent {
  const ResetChangeEmailState();
}
