import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/features/change_phone/domain/usecases/change_phone_usecase.dart';
import 'package:shiftex/features/change_phone/presentation/bloc/change_phone_event.dart';
import 'package:shiftex/features/change_phone/presentation/bloc/change_phone_state.dart';

/// Coordinates strict 10-digit phone number validation and direct Supabase
/// `public.profiles.mobile_number` updates on the existing customer UUID.
class ChangePhoneBloc extends Bloc<ChangePhoneEvent, ChangePhoneState> {
  final ChangePhoneUseCase _changePhoneUseCase;

  ChangePhoneBloc({required ChangePhoneUseCase changePhoneUseCase})
    : _changePhoneUseCase = changePhoneUseCase,
      super(const ChangePhoneInitial()) {
    on<InitializeChangePhone>(_onInitialize);
    on<NewPhoneNumberChanged>(_onNewPhoneNumberChanged);
    on<SubmitChangePhone>(_onSubmitChangePhone);
    on<ResetChangePhoneState>(_onResetState);
  }

  void _onInitialize(
    InitializeChangePhone event,
    Emitter<ChangePhoneState> emit,
  ) {
    final updated = state.form.copyWith(
      currentPhoneNumber: event.currentPhoneNumber,
    );
    final current = state;
    if (current is ChangePhoneFailure) {
      emit(
        ChangePhoneFailure(
          message: current.message,
          failure: current.failure,
          form: updated,
        ),
      );
      return;
    }
    if (current is ChangePhoneLoading) {
      emit(ChangePhoneLoading(form: updated));
      return;
    }
    emit(ChangePhoneValidationChanged(form: updated));
  }

  void _onNewPhoneNumberChanged(
    NewPhoneNumberChanged event,
    Emitter<ChangePhoneState> emit,
  ) {
    if (state is ChangePhoneLoading) return;
    final updated = state.form.copyWith(
      newPhoneNumber: event.value,
      newPhoneTouched: true,
    );
    emit(ChangePhoneValidationChanged(form: updated));
  }

  Future<void> _onSubmitChangePhone(
    SubmitChangePhone event,
    Emitter<ChangePhoneState> emit,
  ) async {
    if (state is ChangePhoneLoading) return;

    final validatedForm = state.form.copyWith(forceShowAllErrors: true);
    if (!validatedForm.isValid) {
      emit(ChangePhoneValidationChanged(form: validatedForm));
      return;
    }

    emit(ChangePhoneLoading(form: validatedForm));

    final result = await _changePhoneUseCase(
      ChangePhoneParams(
        newPhoneNumber: validatedForm.newPhoneNumber.trim(),
        currentPhoneNumber: validatedForm.currentPhoneNumber,
      ),
    );

    result.fold(
      (failure) {
        emit(
          ChangePhoneFailure(
            message: failure.message,
            failure: failure,
            form: state.form,
          ),
        );
      },
      (updateResult) {
        emit(
          ChangePhoneSuccess(
            result: updateResult,
            form: ChangePhoneFormData(
              currentPhoneNumber: updateResult.updatedPhoneNumber,
            ),
          ),
        );
      },
    );
  }

  void _onResetState(
    ResetChangePhoneState event,
    Emitter<ChangePhoneState> emit,
  ) {
    emit(
      ChangePhoneInitial(
        form: ChangePhoneFormData(
          currentPhoneNumber: state.form.currentPhoneNumber,
        ),
      ),
    );
  }
}
