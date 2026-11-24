import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/validators.dart';
import 'package:shiftex/features/change_email/domain/entities/change_email_result_entity.dart';

/// Immutable snapshot of Change Email form inputs, visibility toggles, and
/// real-time validation flags.
class ChangeEmailFormData extends Equatable {
  final String currentEmail;
  final String newEmail;
  final String confirmEmail;
  final String currentPassword;
  final String otpCode;
  final String? pendingTargetEmail;
  final bool obscureCurrentPassword;
  final bool newEmailTouched;
  final bool confirmEmailTouched;
  final bool passwordTouched;
  final bool otpTouched;
  final bool isDifferentFromCurrent;
  final bool emailsMatch;
  final String? newEmailError;
  final String? confirmEmailError;
  final String? currentPasswordError;
  final String? otpError;
  final bool isValid;
  final bool isOtpValid;

  const ChangeEmailFormData({
    this.currentEmail = '',
    this.newEmail = '',
    this.confirmEmail = '',
    this.currentPassword = '',
    this.otpCode = '',
    this.pendingTargetEmail,
    this.obscureCurrentPassword = true,
    this.newEmailTouched = false,
    this.confirmEmailTouched = false,
    this.passwordTouched = false,
    this.otpTouched = false,
    this.isDifferentFromCurrent = true,
    this.emailsMatch = false,
    this.newEmailError,
    this.confirmEmailError,
    this.currentPasswordError,
    this.otpError,
    this.isValid = false,
    this.isOtpValid = false,
  });

  factory ChangeEmailFormData.evaluate({
    required String currentEmail,
    required String newEmail,
    required String confirmEmail,
    required String currentPassword,
    required String otpCode,
    required String? pendingTargetEmail,
    required bool obscureCurrentPassword,
    required bool newEmailTouched,
    required bool confirmEmailTouched,
    required bool passwordTouched,
    required bool otpTouched,
    bool forceShowAllErrors = false,
    bool forceShowOtpError = false,
  }) {
    final cleanCurrent = currentEmail.trim();
    final cleanNew = newEmail.trim();
    final cleanConfirm = confirmEmail.trim();

    final different =
        cleanNew.isEmpty ||
        cleanCurrent.isEmpty ||
        cleanNew.toLowerCase() != cleanCurrent.toLowerCase();

    final rawNewError = Validators.validateNewEmail(
      cleanNew,
      currentEmail: cleanCurrent,
    );
    final rawConfirmError = Validators.validateConfirmNewEmail(
      cleanConfirm,
      cleanNew,
    );
    final rawPasswordError = Validators.validateCurrentPassword(
      currentPassword,
    );
    final rawOtpError = Validators.validateOtp(otpCode);

    final match =
        cleanConfirm.isNotEmpty &&
        cleanNew.isNotEmpty &&
        rawNewError == null &&
        cleanConfirm.toLowerCase() == cleanNew.toLowerCase();

    final showNewErr = forceShowAllErrors || newEmailTouched;
    final showConfirmErr =
        forceShowAllErrors || confirmEmailTouched || cleanConfirm.isNotEmpty;
    final showPasswordErr = forceShowAllErrors || passwordTouched;
    final showOtpErr = forceShowOtpError || otpTouched;

    final isValid =
        rawNewError == null &&
        rawConfirmError == null &&
        rawPasswordError == null &&
        different;

    return ChangeEmailFormData(
      currentEmail: cleanCurrent,
      newEmail: newEmail,
      confirmEmail: confirmEmail,
      currentPassword: currentPassword,
      otpCode: otpCode,
      pendingTargetEmail: pendingTargetEmail,
      obscureCurrentPassword: obscureCurrentPassword,
      newEmailTouched: newEmailTouched || forceShowAllErrors,
      confirmEmailTouched: confirmEmailTouched || forceShowAllErrors,
      passwordTouched: passwordTouched || forceShowAllErrors,
      otpTouched: otpTouched || forceShowOtpError,
      isDifferentFromCurrent: different,
      emailsMatch: match,
      newEmailError: showNewErr ? rawNewError : null,
      confirmEmailError: showConfirmErr ? rawConfirmError : null,
      currentPasswordError: showPasswordErr ? rawPasswordError : null,
      otpError: showOtpErr ? rawOtpError : null,
      isValid: isValid,
      isOtpValid: rawOtpError == null,
    );
  }

  ChangeEmailFormData copyWith({
    String? currentEmail,
    String? newEmail,
    String? confirmEmail,
    String? currentPassword,
    String? otpCode,
    String? pendingTargetEmail,
    bool clearPendingTargetEmail = false,
    bool? obscureCurrentPassword,
    bool? newEmailTouched,
    bool? confirmEmailTouched,
    bool? passwordTouched,
    bool? otpTouched,
    bool forceShowAllErrors = false,
    bool forceShowOtpError = false,
  }) {
    return ChangeEmailFormData.evaluate(
      currentEmail: currentEmail ?? this.currentEmail,
      newEmail: newEmail ?? this.newEmail,
      confirmEmail: confirmEmail ?? this.confirmEmail,
      currentPassword: currentPassword ?? this.currentPassword,
      otpCode: otpCode ?? this.otpCode,
      pendingTargetEmail:
          clearPendingTargetEmail
              ? null
              : (pendingTargetEmail ?? this.pendingTargetEmail),
      obscureCurrentPassword:
          obscureCurrentPassword ?? this.obscureCurrentPassword,
      newEmailTouched: newEmailTouched ?? this.newEmailTouched,
      confirmEmailTouched: confirmEmailTouched ?? this.confirmEmailTouched,
      passwordTouched: passwordTouched ?? this.passwordTouched,
      otpTouched: otpTouched ?? this.otpTouched,
      forceShowAllErrors: forceShowAllErrors,
      forceShowOtpError: forceShowOtpError,
    );
  }

  @override
  List<Object?> get props => [
    currentEmail,
    newEmail,
    confirmEmail,
    currentPassword,
    otpCode,
    pendingTargetEmail,
    obscureCurrentPassword,
    newEmailTouched,
    confirmEmailTouched,
    passwordTouched,
    otpTouched,
    isDifferentFromCurrent,
    emailsMatch,
    newEmailError,
    confirmEmailError,
    currentPasswordError,
    otpError,
    isValid,
    isOtpValid,
  ];

  @override
  bool get stringify => false;

  @override
  String toString() =>
      'ChangeEmailFormData(isValid: $isValid, emailsMatch: $emailsMatch, isDifferentFromCurrent: $isDifferentFromCurrent)';
}

/// Base state class for [ChangeEmailBloc].
abstract class ChangeEmailState extends Equatable {
  final ChangeEmailFormData form;

  const ChangeEmailState({this.form = const ChangeEmailFormData()});

  @override
  List<Object?> get props => [form];
}

/// Initial state before user edits the Change Email form.
class ChangeEmailInitial extends ChangeEmailState {
  const ChangeEmailInitial({super.form});
}

/// Emitted as the user types or toggles visibility in the Change Email form.
class ChangeEmailValidationChanged extends ChangeEmailState {
  const ChangeEmailValidationChanged({required super.form});
}

/// Emitted while an email change request is in flight to Supabase Auth.
class ChangeEmailLoading extends ChangeEmailState {
  const ChangeEmailLoading({required super.form});
}

/// Emitted when Supabase Auth sends a confirmation link / 6-digit OTP to the
/// target email address (and current email if Secure Email Change is enabled)
/// and awaits user verification before finalizing the email change.
class ChangeEmailPendingVerification extends ChangeEmailState {
  final ChangeEmailResultEntity result;
  final String infoMessage;
  final String? errorMessage;
  final Failure? failure;
  final bool isVerifyingOtp;
  final bool isCheckingStatus;
  final bool isResending;
  final bool verifyCurrentEmail;
  final int notificationSequence;

  const ChangeEmailPendingVerification({
    required this.result,
    required this.infoMessage,
    required super.form,
    this.errorMessage,
    this.failure,
    this.isVerifyingOtp = false,
    this.isCheckingStatus = false,
    this.isResending = false,
    this.verifyCurrentEmail = false,
    this.notificationSequence = 1,
  });

  /// The email address whose 6-digit OTP code is currently selected for input.
  String get activeOtpTargetEmail =>
      verifyCurrentEmail && result.currentEmail.isNotEmpty
          ? result.currentEmail
          : result.targetEmail;

  ChangeEmailPendingVerification copyWith({
    ChangeEmailResultEntity? result,
    String? infoMessage,
    ChangeEmailFormData? form,
    String? errorMessage,
    Failure? failure,
    bool clearError = false,
    bool? isVerifyingOtp,
    bool? isCheckingStatus,
    bool? isResending,
    bool? verifyCurrentEmail,
    int? notificationSequence,
  }) {
    return ChangeEmailPendingVerification(
      result: result ?? this.result,
      infoMessage: infoMessage ?? this.infoMessage,
      form: form ?? this.form,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      failure: clearError ? null : (failure ?? this.failure),
      isVerifyingOtp: isVerifyingOtp ?? this.isVerifyingOtp,
      isCheckingStatus: isCheckingStatus ?? this.isCheckingStatus,
      isResending: isResending ?? this.isResending,
      verifyCurrentEmail: verifyCurrentEmail ?? this.verifyCurrentEmail,
      notificationSequence: notificationSequence ?? this.notificationSequence,
    );
  }

  @override
  List<Object?> get props => [
    result,
    infoMessage,
    form,
    errorMessage,
    failure,
    isVerifyingOtp,
    isCheckingStatus,
    isResending,
    verifyCurrentEmail,
    notificationSequence,
  ];
}

/// Emitted when email change submission fails validation, re-authentication,
/// duplicate email check, or network transport.
class ChangeEmailFailure extends ChangeEmailState {
  final String message;
  final Failure failure;

  const ChangeEmailFailure({
    required this.message,
    required this.failure,
    required super.form,
  });

  @override
  List<Object?> get props => [message, failure, form];
}

/// Emitted once the new email address has been verified and synchronized on the
/// existing Supabase Auth user UUID.
class ChangeEmailSuccess extends ChangeEmailState {
  final String userId;
  final String confirmedEmail;
  final String message;

  const ChangeEmailSuccess({
    required this.userId,
    required this.confirmedEmail,
    this.message = 'Your email address has been updated.',
    super.form = const ChangeEmailFormData(),
  });

  @override
  List<Object?> get props => [userId, confirmedEmail, message, form];
}
