import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/account_approval/domain/entities/approval_status.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';
import 'package:shiftex/features/account_approval/domain/usecases/get_approval_status_usecase.dart';
import 'package:shiftex/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:shiftex/features/authentication/domain/usecases/forgot_password_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/get_current_session_profile_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/login_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/logout_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/register_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/resend_email_otp_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/reset_password_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/verify_email_otp_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/verify_password_reset_otp_usecase.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';

class AuthenticationBloc
    extends Bloc<AuthenticationEvent, AuthenticationState> {
  final RegisterUseCase _registerUseCase;
  final VerifyEmailOtpUseCase _verifyEmailOtpUseCase;
  final ResendEmailOtpUseCase _resendEmailOtpUseCase;
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final ForgotPasswordUseCase _forgotPasswordUseCase;
  final VerifyPasswordResetOtpUseCase _verifyPasswordResetOtpUseCase;
  final ResetPasswordUseCase _resetPasswordUseCase;
  final GetCurrentSessionProfileUseCase _getCurrentSessionProfileUseCase;
  final GetApprovalStatusUseCase _getApprovalStatusUseCase;
  final AuthenticationRepository _authRepository;

  StreamSubscription<String>? _authSessionSubscription;
  bool _isProcessingPasswordRecovery = false;

  AuthenticationBloc({
    required RegisterUseCase registerUseCase,
    required VerifyEmailOtpUseCase verifyEmailOtpUseCase,
    required ResendEmailOtpUseCase resendEmailOtpUseCase,
    required LoginUseCase loginUseCase,
    required LogoutUseCase logoutUseCase,
    required ForgotPasswordUseCase forgotPasswordUseCase,
    required VerifyPasswordResetOtpUseCase verifyPasswordResetOtpUseCase,
    required ResetPasswordUseCase resetPasswordUseCase,
    required GetCurrentSessionProfileUseCase getCurrentSessionProfileUseCase,
    required GetApprovalStatusUseCase getApprovalStatusUseCase,
    required AuthenticationRepository authRepository,
  }) : _registerUseCase = registerUseCase,
       _verifyEmailOtpUseCase = verifyEmailOtpUseCase,
       _resendEmailOtpUseCase = resendEmailOtpUseCase,
       _loginUseCase = loginUseCase,
       _logoutUseCase = logoutUseCase,
       _forgotPasswordUseCase = forgotPasswordUseCase,
       _verifyPasswordResetOtpUseCase = verifyPasswordResetOtpUseCase,
       _resetPasswordUseCase = resetPasswordUseCase,
       _getCurrentSessionProfileUseCase = getCurrentSessionProfileUseCase,
       _getApprovalStatusUseCase = getApprovalStatusUseCase,
       _authRepository = authRepository,
       super(const AuthenticationInitial()) {
    on<RegisterRequested>(_onRegisterRequested);
    on<VerifyEmailOtpRequested>(_onVerifyEmailOtpRequested);
    on<ResendEmailOtpRequested>(_onResendEmailOtpRequested);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<ForgotPasswordRequested>(_onForgotPasswordRequested);
    on<VerifyPasswordResetOtpRequested>(_onVerifyPasswordResetOtpRequested);
    on<ResetPasswordRequested>(_onResetPasswordRequested);
    on<AuthSessionChanged>(_onAuthSessionChanged);
    on<CheckApprovalStatusRequested>(_onCheckApprovalStatusRequested);

    _authSessionSubscription = _authRepository.authSessionEvents.listen((
      eventName,
    ) {
      if (eventName == 'signedOut') {
        if (!_isProcessingPasswordRecovery && state is! PasswordResetSuccess) {
          add(AuthSessionChanged(sessionEvent: eventName));
        }
      } else if (eventName == 'passwordRecovery') {
        add(AuthSessionChanged(sessionEvent: eventName));
      }
    });
  }

  CustomerProfileEntity? get _currentProfile {
    final s = state;
    if (s is AuthenticationSuccess) return s.profile;
    if (s is PendingApproval) return s.profile;
    if (s is AccountRejected) return s.profile;
    if (s is AccountSuspended) return s.profile;
    if (s is AuthenticationLoading) return s.currentProfile;
    if (s is AuthenticationFailure) return s.previousProfile;
    return null;
  }

  String? get _activeEmail {
    final s = state;
    if (s is OtpVerificationRequired) return s.email;
    if (s is RegistrationSuccess) return s.email;
    if (s is PasswordResetEmailSent) return s.email;
    if (s is PasswordResetVerified) return s.email;
    if (s is AuthenticationLoading) return s.activeEmail;
    if (s is AuthenticationFailure) return s.email;
    return _currentProfile?.email;
  }

  AuthenticationState _mapProfileToState(
    CustomerProfileEntity profile, {
    String? statusMessage,
  }) {
    switch (profile.approvalStatus) {
      case AccountApprovalStatus.approved:
        return AuthenticationSuccess(profile);
      case AccountApprovalStatus.pending:
        return PendingApproval(profile, statusMessage: statusMessage);
      case AccountApprovalStatus.rejected:
        return AccountRejected(
          profile: profile,
          reason: profile.rejectionReason,
        );
      case AccountApprovalStatus.suspended:
        return AccountSuspended(profile);
    }
  }

  Future<void> _onRegisterRequested(
    RegisterRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    if (state is AuthenticationLoading) return;
    final email = event.email.trim().toLowerCase();
    final fullName = '${event.firstName.trim()} ${event.lastName.trim()}'.trim();

    emit(AuthenticationLoading(activeEmail: email));

    final result = await _registerUseCase(
      RegisterParams(
        firstName: event.firstName,
        lastName: event.lastName,
        mobileNumber: event.mobileNumber,
        email: email,
        password: event.password,
      ),
    );

    result.fold(
      (failure) => emit(AuthenticationFailure(failure, email: email)),
      (registeredEmail) {
        emit(
          RegistrationSuccess(
            email: registeredEmail,
            fullName: fullName,
            mobileNumber: event.mobileNumber,
          ),
        );
        emit(
          OtpVerificationRequired(
            email: registeredEmail,
            fullName: fullName,
            mobileNumber: event.mobileNumber,
          ),
        );
      },
    );
  }

  Future<void> _onVerifyEmailOtpRequested(
    VerifyEmailOtpRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    // Prevent repeated verification requests while one is in progress
    if (state is AuthenticationLoading) return;
    final email = event.email.trim().toLowerCase();

    emit(AuthenticationLoading(activeEmail: email));

    final result = await _verifyEmailOtpUseCase(
      VerifyEmailOtpParams(
        email: email,
        otpCode: event.otpCode,
        fullName: event.fullName,
        mobileNumber: event.mobileNumber,
      ),
    );

    result.fold(
      (failure) => emit(AuthenticationFailure(failure, email: email)),
      (profile) => emit(_mapProfileToState(profile)),
    );
  }

  Future<void> _onResendEmailOtpRequested(
    ResendEmailOtpRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    if (state is AuthenticationLoading) return;
    final email = event.email.trim().toLowerCase();
    emit(AuthenticationLoading(activeEmail: email));

    final result = await _resendEmailOtpUseCase(
      ResendEmailOtpParams(email: email),
    );

    result.fold(
      (failure) => emit(AuthenticationFailure(failure, email: email)),
      (_) => emit(
        OtpVerificationRequired(
          email: email,
          otpResent: true,
          infoMessage: 'A new 6-digit verification code has been sent.',
        ),
      ),
    );
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    if (state is AuthenticationLoading) return;
    emit(const AuthenticationLoading());

    final result = await _loginUseCase(
      LoginParams(
        identifier: event.identifier,
        password: event.password,
        rememberMe: event.rememberMe,
      ),
    );

    result.fold(
      (failure) {
        if (failure is EmailNotVerifiedFailure && failure.email.isNotEmpty) {
          emit(
            OtpVerificationRequired(
              email: failure.email,
              infoMessage: failure.message,
            ),
          );
        } else {
          emit(AuthenticationFailure(failure));
        }
      },
      (profile) => emit(_mapProfileToState(profile)),
    );
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    _isProcessingPasswordRecovery = false;
    emit(const AuthenticationLoading());
    await _logoutUseCase(const NoParams());
    emit(const Unauthenticated());
  }

  Future<void> _onForgotPasswordRequested(
    ForgotPasswordRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    if (state is AuthenticationLoading) return;
    final email = event.email.trim().toLowerCase();
    emit(AuthenticationLoading(activeEmail: email));

    final result = await _forgotPasswordUseCase(
      ForgotPasswordParams(email: email),
    );

    result.fold(
      (failure) {
        // Only surface rate limit, network, or validation failures.
        // Do not reveal whether a specific email account exists.
        if (failure is NetworkFailure ||
            failure is RateLimitFailure ||
            failure is ValidationFailure) {
          emit(AuthenticationFailure(failure, email: email));
        } else {
          emit(
            PasswordResetEmailSent(
              email: email,
              isResend: event.isResend,
            ),
          );
        }
      },
      (_) => emit(
        PasswordResetEmailSent(
          email: email,
          isResend: event.isResend,
        ),
      ),
    );
  }

  Future<void> _onVerifyPasswordResetOtpRequested(
    VerifyPasswordResetOtpRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    if (state is AuthenticationLoading) return;
    final email = event.email.trim().toLowerCase();
    _isProcessingPasswordRecovery = true;
    emit(AuthenticationLoading(activeEmail: email));

    final result = await _verifyPasswordResetOtpUseCase(
      VerifyPasswordResetOtpParams(
        email: email,
        otpCode: event.otpCode,
      ),
    );

    result.fold(
      (failure) {
        _isProcessingPasswordRecovery = false;
        emit(AuthenticationFailure(failure, email: email));
      },
      (_) => emit(PasswordResetVerified(email: email)),
    );
  }

  Future<void> _onResetPasswordRequested(
    ResetPasswordRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    if (state is AuthenticationLoading) return;
    final email = _activeEmail;
    emit(AuthenticationLoading(activeEmail: email));

    final result = await _resetPasswordUseCase(
      ResetPasswordParams(newPassword: event.newPassword),
    );

    _isProcessingPasswordRecovery = false;

    result.fold(
      (failure) => emit(AuthenticationFailure(failure, email: email)),
      (_) => emit(const PasswordResetSuccess()),
    );
  }

  Future<void> _onAuthSessionChanged(
    AuthSessionChanged event,
    Emitter<AuthenticationState> emit,
  ) async {
    if (event.sessionEvent == 'passwordRecovery') {
      _isProcessingPasswordRecovery = true;
      emit(PasswordResetVerified(email: _activeEmail ?? ''));
      return;
    }

    if (event.sessionEvent == 'signedOut') {
      if (state is! PasswordResetSuccess) {
        emit(const Unauthenticated());
      }
      return;
    }

    if (_isProcessingPasswordRecovery) {
      return;
    }

    final result = await _getCurrentSessionProfileUseCase(const NoParams());
    result.fold(
      (failure) {
        if (failure is EmailNotVerifiedFailure && failure.email.isNotEmpty) {
          emit(
            OtpVerificationRequired(
              email: failure.email,
              infoMessage: failure.message,
            ),
          );
        } else {
          emit(const Unauthenticated());
        }
      },
      (profile) {
        if (profile == null) {
          emit(const Unauthenticated());
        } else {
          emit(_mapProfileToState(profile));
        }
      },
    );
  }

  Future<void> _onCheckApprovalStatusRequested(
    CheckApprovalStatusRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    if (state is AuthenticationLoading) return;
    final previous = _currentProfile;
    emit(AuthenticationLoading(currentProfile: previous));

    final result = await _getApprovalStatusUseCase(const NoParams());
    result.fold(
      (failure) {
        if (failure is SessionExpiredFailure) {
          emit(const Unauthenticated());
        } else {
          emit(
            AuthenticationFailure(
              failure,
              previousProfile: previous,
            ),
          );
        }
      },
      (profile) {
        final msg =
            profile.isPending
                ? 'Your account is still awaiting administrator review.'
                : null;
        emit(_mapProfileToState(profile, statusMessage: msg));
      },
    );
  }

  @override
  Future<void> close() {
    _authSessionSubscription?.cancel();
    return super.close();
  }
}
