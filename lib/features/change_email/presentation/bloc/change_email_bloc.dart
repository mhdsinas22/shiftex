import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/features/change_email/domain/entities/change_email_result_entity.dart';
import 'package:shiftex/features/change_email/domain/usecases/change_email_usecase.dart';
import 'package:shiftex/features/change_email/presentation/bloc/change_email_event.dart';
import 'package:shiftex/features/change_email/presentation/bloc/change_email_state.dart';

/// Coordinates real-time email validation, current password re-authentication,
/// pending email verification (6-digit OTP & confirmation link status checks,
/// including Secure Email Change double confirmation), and in-place Supabase
/// Auth email updates on the existing user UUID.
class ChangeEmailBloc extends Bloc<ChangeEmailEvent, ChangeEmailState> {
  final ChangeEmailUseCase _changeEmailUseCase;
  final VerifyEmailChangeOtpUseCase _verifyEmailChangeOtpUseCase;
  final ResendEmailChangeUseCase _resendEmailChangeUseCase;
  final CheckEmailChangeStatusUseCase _checkEmailChangeStatusUseCase;

  ChangeEmailBloc({
    required ChangeEmailUseCase changeEmailUseCase,
    required VerifyEmailChangeOtpUseCase verifyEmailChangeOtpUseCase,
    required ResendEmailChangeUseCase resendEmailChangeUseCase,
    required CheckEmailChangeStatusUseCase checkEmailChangeStatusUseCase,
  }) : _changeEmailUseCase = changeEmailUseCase,
       _verifyEmailChangeOtpUseCase = verifyEmailChangeOtpUseCase,
       _resendEmailChangeUseCase = resendEmailChangeUseCase,
       _checkEmailChangeStatusUseCase = checkEmailChangeStatusUseCase,
       super(const ChangeEmailInitial()) {
    on<InitializeChangeEmail>(_onInitialize);
    on<NewEmailChanged>(_onNewEmailChanged);
    on<ConfirmNewEmailChanged>(_onConfirmNewEmailChanged);
    on<CurrentPasswordForEmailChanged>(_onCurrentPasswordChanged);
    on<ToggleChangeEmailPasswordVisibility>(_onTogglePasswordVisibility);
    on<SubmitChangeEmail>(_onSubmitChangeEmail);
    on<EmailChangeOtpChanged>(_onOtpChanged);
    on<SelectEmailChangeOtpTarget>(_onSelectOtpTarget);
    on<ResumePendingEmailChange>(_onResumePendingEmailChange);
    on<VerifyChangeEmailOtpRequested>(_onVerifyOtpRequested);
    on<ResendChangeEmailVerificationRequested>(_onResendRequested);
    on<CheckChangeEmailStatusRequested>(_onCheckStatusRequested);
    on<EditPendingNewEmailRequested>(_onEditPendingEmail);
    on<MarkChangeEmailConfirmedExternally>(_onConfirmedExternally);
    on<ResetChangeEmailState>(_onResetState);
  }

  void _logBloc(String event, String detail) {
    if (!kDebugMode) return;
    debugPrint('[ChangeEmailBloc] $event | $detail');
  }

  void _onInitialize(
    InitializeChangeEmail event,
    Emitter<ChangeEmailState> emit,
  ) {
    final updated = state.form.copyWith(currentEmail: event.currentEmail);
    _emitWithPreservedStatus(updated, emit);
  }

  void _onNewEmailChanged(
    NewEmailChanged event,
    Emitter<ChangeEmailState> emit,
  ) {
    if (state is ChangeEmailLoading) return;
    final updated = state.form.copyWith(
      newEmail: event.value,
      newEmailTouched: true,
    );
    emit(ChangeEmailValidationChanged(form: updated));
  }

  void _onConfirmNewEmailChanged(
    ConfirmNewEmailChanged event,
    Emitter<ChangeEmailState> emit,
  ) {
    if (state is ChangeEmailLoading) return;
    final updated = state.form.copyWith(
      confirmEmail: event.value,
      confirmEmailTouched: true,
    );
    emit(ChangeEmailValidationChanged(form: updated));
  }

  void _onCurrentPasswordChanged(
    CurrentPasswordForEmailChanged event,
    Emitter<ChangeEmailState> emit,
  ) {
    if (state is ChangeEmailLoading) return;
    final updated = state.form.copyWith(
      currentPassword: event.value,
      passwordTouched: true,
    );
    emit(ChangeEmailValidationChanged(form: updated));
  }

  void _onTogglePasswordVisibility(
    ToggleChangeEmailPasswordVisibility event,
    Emitter<ChangeEmailState> emit,
  ) {
    final updated = state.form.copyWith(
      obscureCurrentPassword: !state.form.obscureCurrentPassword,
    );
    _emitWithPreservedStatus(updated, emit);
  }

  void _emitWithPreservedStatus(
    ChangeEmailFormData updated,
    Emitter<ChangeEmailState> emit,
  ) {
    final current = state;
    if (current is ChangeEmailFailure) {
      emit(
        ChangeEmailFailure(
          message: current.message,
          failure: current.failure,
          form: updated,
        ),
      );
      return;
    }
    if (current is ChangeEmailLoading) {
      emit(ChangeEmailLoading(form: updated));
      return;
    }
    if (current is ChangeEmailPendingVerification) {
      emit(current.copyWith(form: updated));
      return;
    }
    emit(ChangeEmailValidationChanged(form: updated));
  }

  Future<void> _onSubmitChangeEmail(
    SubmitChangeEmail event,
    Emitter<ChangeEmailState> emit,
  ) async {
    if (state is ChangeEmailLoading) return;

    final validatedForm = state.form.copyWith(forceShowAllErrors: true);
    if (!validatedForm.isValid) {
      _logBloc('SubmitChangeEmail.validationFailed', 'form.isValid=false');
      emit(ChangeEmailValidationChanged(form: validatedForm));
      return;
    }

    _logBloc('SubmitChangeEmail.start', 'submitting requestEmailChange');
    emit(ChangeEmailLoading(form: validatedForm));

    final result = await _changeEmailUseCase(
      ChangeEmailParams(
        currentPassword: validatedForm.currentPassword,
        newEmail: validatedForm.newEmail.trim().toLowerCase(),
      ),
    );

    result.fold(
      (failure) {
        _logBloc(
          'SubmitChangeEmail.failure',
          'code=${failure.code}, message=${failure.message}',
        );
        emit(
          ChangeEmailFailure(
            message: failure.message,
            failure: failure,
            form: state.form,
          ),
        );
      },
      (changeResult) {
        final sanitizedForm = state.form.copyWith(
          currentPassword: '',
          passwordTouched: false,
          otpCode: '',
          otpTouched: false,
          pendingTargetEmail: changeResult.targetEmail,
        );
        if (changeResult.isCompleted) {
          _logBloc(
            'SubmitChangeEmail.completedImmediately',
            'userId=${changeResult.userId}',
          );
          emit(
            ChangeEmailSuccess(
              userId: changeResult.userId,
              confirmedEmail: changeResult.targetEmail,
              message: changeResult.message,
              form: sanitizedForm.copyWith(
                currentEmail: changeResult.targetEmail,
                newEmail: '',
                confirmEmail: '',
                newEmailTouched: false,
                confirmEmailTouched: false,
                clearPendingTargetEmail: true,
              ),
            ),
          );
          return;
        }
        _logBloc(
          'SubmitChangeEmail.pendingVerification',
          'userId=${changeResult.userId}, sentAt=${changeResult.emailChangeSentAt}',
        );
        emit(
          ChangeEmailPendingVerification(
            result: changeResult,
            infoMessage: changeResult.message,
            form: sanitizedForm,
            verifyCurrentEmail: changeResult.shouldVerifyCurrentEmailNext,
            notificationSequence: 1,
          ),
        );
      },
    );
  }

  void _onResumePendingEmailChange(
    ResumePendingEmailChange event,
    Emitter<ChangeEmailState> emit,
  ) {
    final normalizedTarget = event.targetEmail.trim().toLowerCase();
    final normalizedCurrent = event.currentEmail.trim().toLowerCase();
    if (normalizedTarget.isEmpty) return;

    final pendingResult = ChangeEmailResultEntity(
      userId: event.userId,
      currentEmail: normalizedCurrent,
      targetEmail: normalizedTarget,
      status: ChangeEmailStatus.pendingVerification,
      emailChangeSentAt: event.emailChangeSentAt,
      message:
          'Enter the 6-digit verification code sent to $normalizedTarget (and to $normalizedCurrent if Secure Email Change is enabled) to finish updating your email.',
    );

    final updatedForm = state.form.copyWith(
      currentEmail: normalizedCurrent,
      newEmail: normalizedTarget,
      confirmEmail: normalizedTarget,
      currentPassword: '',
      passwordTouched: false,
      otpCode: '',
      otpTouched: false,
      pendingTargetEmail: normalizedTarget,
    );

    _logBloc('ResumePendingEmailChange', 'userId=${event.userId}');
    emit(
      ChangeEmailPendingVerification(
        result: pendingResult,
        infoMessage: pendingResult.message,
        form: updatedForm,
        verifyCurrentEmail: false,
        notificationSequence: 1,
      ),
    );
  }

  void _onOtpChanged(
    EmailChangeOtpChanged event,
    Emitter<ChangeEmailState> emit,
  ) {
    final current = state;
    final updatedForm = state.form.copyWith(
      otpCode: event.value,
      otpTouched: true,
    );
    if (current is ChangeEmailPendingVerification) {
      emit(current.copyWith(form: updatedForm, clearError: true));
      return;
    }
    emit(ChangeEmailValidationChanged(form: updatedForm));
  }

  void _onSelectOtpTarget(
    SelectEmailChangeOtpTarget event,
    Emitter<ChangeEmailState> emit,
  ) {
    final current = state;
    if (current is! ChangeEmailPendingVerification) return;
    if (current.isVerifyingOtp || current.isCheckingStatus) return;

    final clearedForm = current.form.copyWith(
      otpCode: '',
      otpTouched: false,
    );
    emit(
      current.copyWith(
        form: clearedForm,
        verifyCurrentEmail: event.verifyCurrentEmail,
        clearError: true,
      ),
    );
  }

  Future<void> _onVerifyOtpRequested(
    VerifyChangeEmailOtpRequested event,
    Emitter<ChangeEmailState> emit,
  ) async {
    final current = state;
    if (current is! ChangeEmailPendingVerification) return;
    if (current.isVerifyingOtp || current.isCheckingStatus) return;

    final validatedForm = current.form.copyWith(forceShowOtpError: true);
    if (!validatedForm.isOtpValid) {
      emit(
        current.copyWith(
          form: validatedForm,
          errorMessage: validatedForm.otpError,
        ),
      );
      return;
    }

    _logBloc(
      'VerifyChangeEmailOtpRequested.start',
      'verifyCurrentEmail=${current.verifyCurrentEmail}',
    );
    emit(
      current.copyWith(
        form: validatedForm,
        isVerifyingOtp: true,
        clearError: true,
      ),
    );

    final result = await _verifyEmailChangeOtpUseCase(
      VerifyEmailChangeOtpParams(
        newEmail: current.result.targetEmail,
        otpCode: validatedForm.otpCode.trim(),
        currentEmail: current.result.currentEmail,
        verifyCurrentEmail: current.verifyCurrentEmail,
        newEmailAlreadyVerified: current.result.newEmailVerified,
        currentEmailAlreadyVerified: current.result.currentEmailVerified,
      ),
    );

    result.fold(
      (failure) {
        _logBloc(
          'VerifyChangeEmailOtpRequested.failure',
          'code=${failure.code}, message=${failure.message}',
        );
        emit(
          current.copyWith(
            isVerifyingOtp: false,
            errorMessage: failure.message,
            failure: failure,
          ),
        );
      },
      (verifyResult) {
        if (verifyResult.isCompleted) {
          _logBloc(
            'VerifyChangeEmailOtpRequested.completed',
            'userId=${verifyResult.userId}',
          );
          emit(
            ChangeEmailSuccess(
              userId: verifyResult.userId,
              confirmedEmail: verifyResult.targetEmail,
              message: verifyResult.message,
              form: ChangeEmailFormData(
                currentEmail: verifyResult.targetEmail,
              ),
            ),
          );
          return;
        }
        _logBloc(
          'VerifyChangeEmailOtpRequested.step1Completed',
          'newVerified=${verifyResult.newEmailVerified}, currentVerified=${verifyResult.currentEmailVerified}',
        );
        final clearedOtpForm = current.form.copyWith(
          otpCode: '',
          otpTouched: false,
        );
        emit(
          current.copyWith(
            result: verifyResult,
            infoMessage: verifyResult.message,
            form: clearedOtpForm,
            isVerifyingOtp: false,
            verifyCurrentEmail: verifyResult.shouldVerifyCurrentEmailNext,
            notificationSequence: current.notificationSequence + 1,
            clearError: true,
          ),
        );
      },
    );
  }

  Future<void> _onResendRequested(
    ResendChangeEmailVerificationRequested event,
    Emitter<ChangeEmailState> emit,
  ) async {
    final current = state;
    if (current is! ChangeEmailPendingVerification) return;
    if (current.isResending || current.isVerifyingOtp) return;

    _logBloc('ResendChangeEmailVerificationRequested.start', 'resending OTP');
    emit(current.copyWith(isResending: true, clearError: true));

    final result = await _resendEmailChangeUseCase(
      ResendEmailChangeParams(newEmail: current.result.targetEmail),
    );

    result.fold(
      (failure) {
        _logBloc(
          'ResendChangeEmailVerificationRequested.failure',
          'code=${failure.code}, message=${failure.message}',
        );
        emit(
          current.copyWith(
            isResending: false,
            errorMessage: failure.message,
            failure: failure,
          ),
        );
      },
      (_) {
        _logBloc('ResendChangeEmailVerificationRequested.success', 'resent');
        final resetResult = current.result.copyWith(
          newEmailVerified: false,
          currentEmailVerified: false,
        );
        final clearedOtpForm = current.form.copyWith(
          otpCode: '',
          otpTouched: false,
        );
        emit(
          current.copyWith(
            result: resetResult,
            form: clearedOtpForm,
            isResending: false,
            verifyCurrentEmail: false,
            notificationSequence: current.notificationSequence + 1,
            infoMessage:
                'A fresh 6-digit verification code has been sent to ${current.result.targetEmail} (and to ${current.result.currentEmail} if Secure Email Change is enabled).',
            clearError: true,
          ),
        );
      },
    );
  }

  Future<void> _onCheckStatusRequested(
    CheckChangeEmailStatusRequested event,
    Emitter<ChangeEmailState> emit,
  ) async {
    final current = state;
    if (current is! ChangeEmailPendingVerification) return;
    if (current.isCheckingStatus || current.isVerifyingOtp) return;

    _logBloc('CheckChangeEmailStatusRequested.start', 'checking status');
    emit(current.copyWith(isCheckingStatus: true, clearError: true));

    final result = await _checkEmailChangeStatusUseCase(
      CheckEmailChangeStatusParams(targetEmail: current.result.targetEmail),
    );

    result.fold(
      (failure) {
        _logBloc(
          'CheckChangeEmailStatusRequested.failure',
          'code=${failure.code}, message=${failure.message}',
        );
        emit(
          current.copyWith(
            isCheckingStatus: false,
            errorMessage: failure.message,
            failure: failure,
          ),
        );
      },
      (statusResult) {
        if (statusResult.isCompleted) {
          _logBloc(
            'CheckChangeEmailStatusRequested.completed',
            'userId=${statusResult.userId}',
          );
          emit(
            ChangeEmailSuccess(
              userId: statusResult.userId,
              confirmedEmail: statusResult.targetEmail,
              message: statusResult.message,
              form: ChangeEmailFormData(
                currentEmail: statusResult.targetEmail,
              ),
            ),
          );
          return;
        }
        emit(
          current.copyWith(
            result: statusResult,
            infoMessage: statusResult.message,
            isCheckingStatus: false,
            notificationSequence: current.notificationSequence + 1,
            clearError: true,
          ),
        );
      },
    );
  }

  void _onEditPendingEmail(
    EditPendingNewEmailRequested event,
    Emitter<ChangeEmailState> emit,
  ) {
    final updated = state.form.copyWith(
      otpCode: '',
      otpTouched: false,
      currentPassword: '',
      passwordTouched: false,
      clearPendingTargetEmail: true,
    );
    emit(ChangeEmailValidationChanged(form: updated));
  }

  void _onConfirmedExternally(
    MarkChangeEmailConfirmedExternally event,
    Emitter<ChangeEmailState> emit,
  ) {
    emit(
      ChangeEmailSuccess(
        userId: event.userId,
        confirmedEmail: event.confirmedEmail,
        message:
            'Your email address has been verified and updated to ${event.confirmedEmail}.',
        form: ChangeEmailFormData(currentEmail: event.confirmedEmail),
      ),
    );
  }

  void _onResetState(
    ResetChangeEmailState event,
    Emitter<ChangeEmailState> emit,
  ) {
    emit(
      ChangeEmailInitial(
        form: ChangeEmailFormData(currentEmail: state.form.currentEmail),
      ),
    );
  }
}
