import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/features/change_password/domain/usecases/change_password_usecase.dart';
import 'package:shiftex/features/change_password/presentation/bloc/change_password_event.dart';
import 'package:shiftex/features/change_password/presentation/bloc/change_password_state.dart';

/// Manages real-time password validation, strength indicators, visibility toggles,
/// and guarded Supabase password updates.
class ChangePasswordBloc
    extends Bloc<ChangePasswordEvent, ChangePasswordState> {
  final ChangePasswordUseCase _changePasswordUseCase;

  ChangePasswordBloc({required ChangePasswordUseCase changePasswordUseCase})
    : _changePasswordUseCase = changePasswordUseCase,
      super(const ChangePasswordInitial()) {
    on<CurrentPasswordChanged>(_onCurrentPasswordChanged);
    on<NewPasswordChanged>(_onNewPasswordChanged);
    on<ConfirmPasswordChanged>(_onConfirmPasswordChanged);
    on<ToggleCurrentPasswordVisibility>(_onToggleCurrentVisibility);
    on<ToggleNewPasswordVisibility>(_onToggleNewVisibility);
    on<ToggleConfirmPasswordVisibility>(_onToggleConfirmVisibility);
    on<SubmitChangePassword>(_onSubmitChangePassword);
    on<ResetChangePasswordState>(_onResetState);
  }

  void _onCurrentPasswordChanged(
    CurrentPasswordChanged event,
    Emitter<ChangePasswordState> emit,
  ) {
    if (state is ChangePasswordLoading) return;
    final updated = state.form.copyWith(
      currentPassword: event.value,
      currentTouched: true,
    );
    emit(ChangePasswordValidationChanged(form: updated));
  }

  void _onNewPasswordChanged(
    NewPasswordChanged event,
    Emitter<ChangePasswordState> emit,
  ) {
    if (state is ChangePasswordLoading) return;
    final updated = state.form.copyWith(
      newPassword: event.value,
      newTouched: true,
    );
    emit(ChangePasswordValidationChanged(form: updated));
  }

  void _onConfirmPasswordChanged(
    ConfirmPasswordChanged event,
    Emitter<ChangePasswordState> emit,
  ) {
    if (state is ChangePasswordLoading) return;
    final updated = state.form.copyWith(
      confirmPassword: event.value,
      confirmTouched: true,
    );
    emit(ChangePasswordValidationChanged(form: updated));
  }

  void _onToggleCurrentVisibility(
    ToggleCurrentPasswordVisibility event,
    Emitter<ChangePasswordState> emit,
  ) {
    final updated = state.form.copyWith(
      obscureCurrentPassword: !state.form.obscureCurrentPassword,
    );
    _emitWithPreservedStatus(updated, emit);
  }

  void _onToggleNewVisibility(
    ToggleNewPasswordVisibility event,
    Emitter<ChangePasswordState> emit,
  ) {
    final updated = state.form.copyWith(
      obscureNewPassword: !state.form.obscureNewPassword,
    );
    _emitWithPreservedStatus(updated, emit);
  }

  void _onToggleConfirmVisibility(
    ToggleConfirmPasswordVisibility event,
    Emitter<ChangePasswordState> emit,
  ) {
    final updated = state.form.copyWith(
      obscureConfirmPassword: !state.form.obscureConfirmPassword,
    );
    _emitWithPreservedStatus(updated, emit);
  }

  void _emitWithPreservedStatus(
    ChangePasswordFormData updated,
    Emitter<ChangePasswordState> emit,
  ) {
    final current = state;
    if (current is ChangePasswordFailure) {
      emit(
        ChangePasswordFailure(
          message: current.message,
          failure: current.failure,
          form: updated,
        ),
      );
      return;
    }
    if (current is ChangePasswordLoading) {
      emit(ChangePasswordLoading(form: updated));
      return;
    }
    emit(ChangePasswordValidationChanged(form: updated));
  }

  Future<void> _onSubmitChangePassword(
    SubmitChangePassword event,
    Emitter<ChangePasswordState> emit,
  ) async {
    if (state is ChangePasswordLoading) {
      return;
    }

    final validatedForm = state.form.copyWith(forceShowAllErrors: true);
    if (!validatedForm.isValid) {
      emit(ChangePasswordValidationChanged(form: validatedForm));
      return;
    }

    emit(ChangePasswordLoading(form: validatedForm));

    final result = await _changePasswordUseCase(
      ChangePasswordParams(
        currentPassword: validatedForm.currentPassword,
        newPassword: validatedForm.newPassword,
      ),
    );

    result.fold(
      (failure) {
        emit(
          ChangePasswordFailure(
            message: failure.message,
            failure: failure,
            form: state.form,
          ),
        );
      },
      (_) {
        emit(const ChangePasswordSuccess());
      },
    );
  }

  void _onResetState(
    ResetChangePasswordState event,
    Emitter<ChangePasswordState> emit,
  ) {
    emit(const ChangePasswordInitial());
  }
}
