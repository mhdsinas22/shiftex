import 'package:equatable/equatable.dart';

/// Base event class for the Change Password BLoC.
abstract class ChangePasswordEvent extends Equatable {
  const ChangePasswordEvent();

  @override
  List<Object?> get props => [];

  @override
  bool get stringify => false;
}

/// Fired whenever the Current Password text input changes.
class CurrentPasswordChanged extends ChangePasswordEvent {
  final String value;

  const CurrentPasswordChanged(this.value);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => 'CurrentPasswordChanged(redacted)';
}

/// Fired whenever the New Password text input changes.
class NewPasswordChanged extends ChangePasswordEvent {
  final String value;

  const NewPasswordChanged(this.value);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => 'NewPasswordChanged(redacted)';
}

/// Fired whenever the Confirm New Password text input changes.
class ConfirmPasswordChanged extends ChangePasswordEvent {
  final String value;

  const ConfirmPasswordChanged(this.value);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => 'ConfirmPasswordChanged(redacted)';
}

/// Toggles masking on the Current Password input field.
class ToggleCurrentPasswordVisibility extends ChangePasswordEvent {
  const ToggleCurrentPasswordVisibility();
}

/// Toggles masking on the New Password input field.
class ToggleNewPasswordVisibility extends ChangePasswordEvent {
  const ToggleNewPasswordVisibility();
}

/// Toggles masking on the Confirm New Password input field.
class ToggleConfirmPasswordVisibility extends ChangePasswordEvent {
  const ToggleConfirmPasswordVisibility();
}

/// Submits the validated Change Password form to Supabase Auth.
class SubmitChangePassword extends ChangePasswordEvent {
  const SubmitChangePassword();
}

/// Resets transient form and state data back to initial defaults.
class ResetChangePasswordState extends ChangePasswordEvent {
  const ResetChangePasswordState();
}
