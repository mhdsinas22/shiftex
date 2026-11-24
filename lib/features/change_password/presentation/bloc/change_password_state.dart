import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/validators.dart';

/// Immutable snapshot of form inputs, visibility toggles, and real-time validation flags.
class ChangePasswordFormData extends Equatable {
  final String currentPassword;
  final String newPassword;
  final String confirmPassword;
  final bool obscureCurrentPassword;
  final bool obscureNewPassword;
  final bool obscureConfirmPassword;
  final bool currentTouched;
  final bool newTouched;
  final bool confirmTouched;
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSpecialChar;
  final bool isDifferentFromCurrent;
  final bool passwordsMatch;
  final PasswordStrengthLevel strength;
  final String? currentPasswordError;
  final String? newPasswordError;
  final String? confirmPasswordError;
  final bool isValid;

  const ChangePasswordFormData({
    this.currentPassword = '',
    this.newPassword = '',
    this.confirmPassword = '',
    this.obscureCurrentPassword = true,
    this.obscureNewPassword = true,
    this.obscureConfirmPassword = true,
    this.currentTouched = false,
    this.newTouched = false,
    this.confirmTouched = false,
    this.hasMinLength = false,
    this.hasUppercase = false,
    this.hasLowercase = false,
    this.hasNumber = false,
    this.hasSpecialChar = false,
    this.isDifferentFromCurrent = true,
    this.passwordsMatch = false,
    this.strength = PasswordStrengthLevel.empty,
    this.currentPasswordError,
    this.newPasswordError,
    this.confirmPasswordError,
    this.isValid = false,
  });

  /// Recomputes validation flags cleanly from raw password values and touch flags.
  factory ChangePasswordFormData.evaluate({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
    required bool obscureCurrentPassword,
    required bool obscureNewPassword,
    required bool obscureConfirmPassword,
    required bool currentTouched,
    required bool newTouched,
    required bool confirmTouched,
    bool forceShowAllErrors = false,
  }) {
    final hasMinLen = Validators.hasPasswordMinLength(newPassword);
    final hasUpper = Validators.hasPasswordUppercase(newPassword);
    final hasLower = Validators.hasPasswordLowercase(newPassword);
    final hasNum = Validators.hasPasswordNumber(newPassword);
    final hasSpecial = Validators.hasPasswordSpecialChar(newPassword);
    final different =
        newPassword.isEmpty ||
        currentPassword.isEmpty ||
        newPassword != currentPassword;
    final match =
        confirmPassword.isNotEmpty && confirmPassword == newPassword;
    final strength = Validators.evaluatePasswordStrength(newPassword);

    final rawCurrentError = Validators.validateCurrentPassword(currentPassword);
    final rawNewError = Validators.validateStrongNewPassword(
      newPassword,
      currentPassword: currentPassword,
    );
    final rawConfirmError = Validators.validateConfirmNewPassword(
      confirmPassword,
      newPassword,
    );

    final showCurrentErr = forceShowAllErrors || currentTouched;
    final showNewErr = forceShowAllErrors || newTouched;
    final showConfirmErr =
        forceShowAllErrors || confirmTouched || confirmPassword.isNotEmpty;

    final isValid =
        rawCurrentError == null &&
        rawNewError == null &&
        rawConfirmError == null &&
        different;

    return ChangePasswordFormData(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
      obscureCurrentPassword: obscureCurrentPassword,
      obscureNewPassword: obscureNewPassword,
      obscureConfirmPassword: obscureConfirmPassword,
      currentTouched: currentTouched || forceShowAllErrors,
      newTouched: newTouched || forceShowAllErrors,
      confirmTouched: confirmTouched || forceShowAllErrors,
      hasMinLength: hasMinLen,
      hasUppercase: hasUpper,
      hasLowercase: hasLower,
      hasNumber: hasNum,
      hasSpecialChar: hasSpecial,
      isDifferentFromCurrent: different,
      passwordsMatch: match,
      strength: strength,
      currentPasswordError: showCurrentErr ? rawCurrentError : null,
      newPasswordError: showNewErr ? rawNewError : null,
      confirmPasswordError: showConfirmErr ? rawConfirmError : null,
      isValid: isValid,
    );
  }

  ChangePasswordFormData copyWith({
    String? currentPassword,
    String? newPassword,
    String? confirmPassword,
    bool? obscureCurrentPassword,
    bool? obscureNewPassword,
    bool? obscureConfirmPassword,
    bool? currentTouched,
    bool? newTouched,
    bool? confirmTouched,
    bool forceShowAllErrors = false,
  }) {
    return ChangePasswordFormData.evaluate(
      currentPassword: currentPassword ?? this.currentPassword,
      newPassword: newPassword ?? this.newPassword,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      obscureCurrentPassword:
          obscureCurrentPassword ?? this.obscureCurrentPassword,
      obscureNewPassword: obscureNewPassword ?? this.obscureNewPassword,
      obscureConfirmPassword:
          obscureConfirmPassword ?? this.obscureConfirmPassword,
      currentTouched: currentTouched ?? this.currentTouched,
      newTouched: newTouched ?? this.newTouched,
      confirmTouched: confirmTouched ?? this.confirmTouched,
      forceShowAllErrors: forceShowAllErrors,
    );
  }

  @override
  List<Object?> get props => [
    currentPassword,
    newPassword,
    confirmPassword,
    obscureCurrentPassword,
    obscureNewPassword,
    obscureConfirmPassword,
    currentTouched,
    newTouched,
    confirmTouched,
    hasMinLength,
    hasUppercase,
    hasLowercase,
    hasNumber,
    hasSpecialChar,
    isDifferentFromCurrent,
    passwordsMatch,
    strength,
    currentPasswordError,
    newPasswordError,
    confirmPasswordError,
    isValid,
  ];

  @override
  bool get stringify => false;

  @override
  String toString() =>
      'ChangePasswordFormData(strength: $strength, isValid: $isValid)';
}

/// Base state class for [ChangePasswordBloc].
abstract class ChangePasswordState extends Equatable {
  final ChangePasswordFormData form;

  const ChangePasswordState({this.form = const ChangePasswordFormData()});

  @override
  List<Object?> get props => [form];

  @override
  bool get stringify => false;
}

/// Initial clean state before the user starts typing.
class ChangePasswordInitial extends ChangePasswordState {
  const ChangePasswordInitial({super.form});
}

/// Emitted whenever password input, visibility, or live validation rules update.
class ChangePasswordValidationChanged extends ChangePasswordState {
  const ChangePasswordValidationChanged({required super.form});
}

/// Emitted while verifying current password and calling Supabase Auth `updateUser`.
class ChangePasswordLoading extends ChangePasswordState {
  const ChangePasswordLoading({required super.form});
}

/// Emitted only after Supabase confirms the password update succeeded.
class ChangePasswordSuccess extends ChangePasswordState {
  const ChangePasswordSuccess({
    super.form = const ChangePasswordFormData(),
  });
}

/// Emitted when current password verification, network, or Supabase update fails.
class ChangePasswordFailure extends ChangePasswordState {
  final String message;
  final Failure failure;

  const ChangePasswordFailure({
    required this.message,
    required this.failure,
    required super.form,
  });

  @override
  List<Object?> get props => [message, failure, form];

  @override
  String toString() => 'ChangePasswordFailure(code: ${failure.code})';
}
