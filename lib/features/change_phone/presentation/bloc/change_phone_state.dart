import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/validators.dart';
import 'package:shiftex/features/change_phone/domain/entities/change_phone_result_entity.dart';

/// Immutable snapshot of Change Phone Number form inputs and real-time
/// validation flags.
class ChangePhoneFormData extends Equatable {
  final String currentPhoneNumber;
  final String newPhoneNumber;
  final bool newPhoneTouched;
  final bool isDifferentFromCurrent;
  final String? newPhoneError;
  final bool isValid;

  const ChangePhoneFormData({
    this.currentPhoneNumber = '',
    this.newPhoneNumber = '',
    this.newPhoneTouched = false,
    this.isDifferentFromCurrent = true,
    this.newPhoneError,
    this.isValid = false,
  });

  /// Returns the normalized 10-digit representation of [currentPhoneNumber]
  /// (e.g. `+919876543210` -> `9876543210`).
  String get currentTenDigitPhone =>
      Validators.extractTenDigitPhone(currentPhoneNumber);

  factory ChangePhoneFormData.evaluate({
    required String currentPhoneNumber,
    required String newPhoneNumber,
    required bool newPhoneTouched,
    bool forceShowAllErrors = false,
  }) {
    final cleanCurrent = currentPhoneNumber.trim();
    final cleanNew = newPhoneNumber.trim();
    final currentTen = Validators.extractTenDigitPhone(cleanCurrent);

    final different =
        cleanNew.isEmpty || currentTen.isEmpty || cleanNew != currentTen;

    final rawError = Validators.validateNewPhoneNumber(
      cleanNew,
      currentPhoneNumber: cleanCurrent,
    );

    final showError =
        forceShowAllErrors || newPhoneTouched || cleanNew.isNotEmpty;
    final isValid = rawError == null && different;

    return ChangePhoneFormData(
      currentPhoneNumber: cleanCurrent,
      newPhoneNumber: newPhoneNumber,
      newPhoneTouched: newPhoneTouched || forceShowAllErrors,
      isDifferentFromCurrent: different,
      newPhoneError: showError ? rawError : null,
      isValid: isValid,
    );
  }

  ChangePhoneFormData copyWith({
    String? currentPhoneNumber,
    String? newPhoneNumber,
    bool? newPhoneTouched,
    bool forceShowAllErrors = false,
  }) {
    return ChangePhoneFormData.evaluate(
      currentPhoneNumber: currentPhoneNumber ?? this.currentPhoneNumber,
      newPhoneNumber: newPhoneNumber ?? this.newPhoneNumber,
      newPhoneTouched: newPhoneTouched ?? this.newPhoneTouched,
      forceShowAllErrors: forceShowAllErrors,
    );
  }

  @override
  List<Object?> get props => [
    currentPhoneNumber,
    newPhoneNumber,
    newPhoneTouched,
    isDifferentFromCurrent,
    newPhoneError,
    isValid,
  ];
}

/// Base state class for [ChangePhoneBloc].
abstract class ChangePhoneState extends Equatable {
  final ChangePhoneFormData form;

  const ChangePhoneState({this.form = const ChangePhoneFormData()});

  @override
  List<Object?> get props => [form];
}

/// Initial state before user edits the Change Phone Number form.
class ChangePhoneInitial extends ChangePhoneState {
  const ChangePhoneInitial({super.form});
}

/// Emitted as the user types in the Change Phone Number form.
class ChangePhoneValidationChanged extends ChangePhoneState {
  const ChangePhoneValidationChanged({required super.form});
}

/// Emitted while a phone number update request is in flight to Supabase.
class ChangePhoneLoading extends ChangePhoneState {
  const ChangePhoneLoading({required super.form});
}

/// Emitted when phone number submission fails validation, duplicate check, or
/// network transport.
class ChangePhoneFailure extends ChangePhoneState {
  final String message;
  final Failure failure;

  const ChangePhoneFailure({
    required this.message,
    required this.failure,
    required super.form,
  });

  @override
  List<Object?> get props => [message, failure, form];
}

/// Emitted once the new phone number has been saved directly on the existing
/// customer profile record.
class ChangePhoneSuccess extends ChangePhoneState {
  final ChangePhoneResultEntity result;

  const ChangePhoneSuccess({
    required this.result,
    super.form = const ChangePhoneFormData(),
  });

  @override
  List<Object?> get props => [result, form];
}
