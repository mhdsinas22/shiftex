import 'package:equatable/equatable.dart';

/// Base event class for [ChangePhoneBloc].
abstract class ChangePhoneEvent extends Equatable {
  const ChangePhoneEvent();

  @override
  List<Object?> get props => [];
}

/// Initializes or updates the read-only current registered phone number.
class InitializeChangePhone extends ChangePhoneEvent {
  final String currentPhoneNumber;

  const InitializeChangePhone(this.currentPhoneNumber);

  @override
  List<Object?> get props => [currentPhoneNumber];
}

/// Fired whenever the New Phone Number input field changes.
class NewPhoneNumberChanged extends ChangePhoneEvent {
  final String value;

  const NewPhoneNumberChanged(this.value);

  @override
  List<Object?> get props => [value];
}

/// Submits the validated 10-digit phone number to update `public.profiles`.
class SubmitChangePhone extends ChangePhoneEvent {
  const SubmitChangePhone();
}

/// Resets transient form and state data back to initial defaults.
class ResetChangePhoneState extends ChangePhoneEvent {
  const ResetChangePhoneState();
}
