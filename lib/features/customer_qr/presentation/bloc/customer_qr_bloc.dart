import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/customer_qr/domain/entities/customer_qr_entity.dart';
import 'package:shiftex/features/customer_qr/domain/usecases/get_customer_personal_qr_usecase.dart';
import 'package:shiftex/features/customer_qr/domain/usecases/revoke_customer_personal_qr_usecase.dart';
import 'package:shiftex/features/customer_qr/presentation/bloc/customer_qr_event.dart';
import 'package:shiftex/features/customer_qr/presentation/bloc/customer_qr_state.dart';

typedef ClipboardTextWriter = Future<void> Function(String text);
typedef ClockProvider = DateTime Function();

class CustomerQrBloc extends Bloc<CustomerQrEvent, CustomerQrState> {
  final GetCustomerPersonalQrUseCase _getCustomerPersonalQrUseCase;
  final RevokeCustomerPersonalQrUseCase _revokeCustomerPersonalQrUseCase;
  final ClipboardTextWriter _copyToClipboard;
  final ClockProvider _clockProvider;

  CustomerQrBloc({
    required GetCustomerPersonalQrUseCase getCustomerPersonalQrUseCase,
    required RevokeCustomerPersonalQrUseCase revokeCustomerPersonalQrUseCase,
    ClipboardTextWriter? copyToClipboard,
    ClockProvider? clockProvider,
  }) : _getCustomerPersonalQrUseCase = getCustomerPersonalQrUseCase,
       _revokeCustomerPersonalQrUseCase = revokeCustomerPersonalQrUseCase,
       _copyToClipboard = copyToClipboard ?? _defaultClipboardWriter,
       _clockProvider = clockProvider ?? _defaultClockProvider,
       super(const CustomerQrState()) {
    on<CustomerQrLoadRequested>(_onLoadRequested);
    on<CustomerQrRefreshRequested>(_onRefreshRequested);
    on<CustomerQrRevokeRequested>(_onRevokeRequested);
    on<CustomerQrExpiryChecked>(_onExpiryChecked);
    on<CustomerIdCopyRequested>(_onCopyIdRequested);
    on<CustomerQrFeedbackCleared>(_onFeedbackCleared);
  }

  static Future<void> _defaultClipboardWriter(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  static DateTime _defaultClockProvider() => DateTime.now().toUtc();

  Future<void> _onLoadRequested(
    CustomerQrLoadRequested event,
    Emitter<CustomerQrState> emit,
  ) async {
    if (state.status == CustomerQrStatus.loading) {
      return;
    }

    emit(
      state.copyWith(
        status:
            state.hasData
                ? CustomerQrStatus.refreshing
                : CustomerQrStatus.loading,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );

    final result = await _getCustomerPersonalQrUseCase(
      GetCustomerPersonalQrParams(forceRegenerate: event.forceRegenerate),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status:
              state.hasData ? CustomerQrStatus.loaded : CustomerQrStatus.error,
          errorMessage: failure.message,
          feedbackSequence: state.feedbackSequence + 1,
        ),
      ),
      (qr) => emit(
        state.copyWith(
          status: CustomerQrStatus.loaded,
          qrData: qr,
          isExpired: qr.isExpiredAt(_clockProvider()),
          clearErrorMessage: true,
        ),
      ),
    );
  }

  Future<void> _onRefreshRequested(
    CustomerQrRefreshRequested event,
    Emitter<CustomerQrState> emit,
  ) async {
    if (state.isBusy) {
      return;
    }

    emit(
      state.copyWith(
        status:
            state.hasData
                ? CustomerQrStatus.refreshing
                : CustomerQrStatus.loading,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );

    final result = await _getCustomerPersonalQrUseCase(
      const GetCustomerPersonalQrParams(forceRegenerate: true),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status:
              state.hasData ? CustomerQrStatus.loaded : CustomerQrStatus.error,
          errorMessage: failure.message,
          feedbackSequence: state.feedbackSequence + 1,
        ),
      ),
      (qr) => emit(
        state.copyWith(
          status: CustomerQrStatus.loaded,
          qrData: qr,
          isExpired: qr.isExpiredAt(_clockProvider()),
          clearErrorMessage: true,
          infoMessage: 'Personal QR pass refreshed.',
          feedbackSequence: state.feedbackSequence + 1,
        ),
      ),
    );
  }

  Future<void> _onRevokeRequested(
    CustomerQrRevokeRequested event,
    Emitter<CustomerQrState> emit,
  ) async {
    if (state.isBusy) {
      return;
    }

    emit(
      state.copyWith(
        status:
            state.hasData
                ? CustomerQrStatus.refreshing
                : CustomerQrStatus.loading,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );

    final result = await _revokeCustomerPersonalQrUseCase(const NoParams());

    result.fold(
      (failure) => emit(
        state.copyWith(
          status:
              state.hasData ? CustomerQrStatus.loaded : CustomerQrStatus.error,
          errorMessage: failure.message,
          feedbackSequence: state.feedbackSequence + 1,
        ),
      ),
      (_) {
        final current = state.qrData;
        final revokedEntity =
            current == null
                ? null
                : CustomerQrEntity(
                  customerId: current.customerId,
                  fullName: current.fullName,
                  membershipId: current.membershipId,
                  membershipTier: current.membershipTier,
                  tokenId: current.tokenId,
                  tokenCode: current.tokenCode,
                  qrPayload: current.qrPayload,
                  tokenPurpose: current.tokenPurpose,
                  allowDeduction: current.allowDeduction,
                  status: 'revoked',
                  expiresAt: current.expiresAt,
                  createdAt: current.createdAt,
                );
        emit(
          state.copyWith(
            status:
                revokedEntity != null
                    ? CustomerQrStatus.loaded
                    : CustomerQrStatus.initial,
            qrData: revokedEntity,
            isExpired: true,
            infoMessage:
                'Current QR code revoked. Refresh to generate a new pass.',
            feedbackSequence: state.feedbackSequence + 1,
          ),
        );
      },
    );
  }

  Future<void> _onExpiryChecked(
    CustomerQrExpiryChecked event,
    Emitter<CustomerQrState> emit,
  ) async {
    final current = state.qrData;
    if (current == null || state.isBusy) {
      return;
    }

    final checkTime = event.now ?? _clockProvider();
    if (!current.isExpiredAt(checkTime)) {
      if (state.isExpired) {
        emit(state.copyWith(isExpired: false));
      }
      return;
    }

    // Automatically rotate an expired active token rather than leaving a dead code.
    if (current.status == 'revoked') {
      if (!state.isExpired) {
        emit(state.copyWith(isExpired: true));
      }
      return;
    }

    emit(
      state.copyWith(
        status: CustomerQrStatus.refreshing,
        isExpired: true,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );

    final result = await _getCustomerPersonalQrUseCase(
      const GetCustomerPersonalQrParams(forceRegenerate: true),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CustomerQrStatus.loaded,
          isExpired: true,
          errorMessage: failure.message,
          feedbackSequence: state.feedbackSequence + 1,
        ),
      ),
      (qr) => emit(
        state.copyWith(
          status: CustomerQrStatus.loaded,
          qrData: qr,
          isExpired: qr.isExpiredAt(checkTime),
          clearErrorMessage: true,
          infoMessage: 'Expired QR refreshed automatically.',
          feedbackSequence: state.feedbackSequence + 1,
        ),
      ),
    );
  }

  Future<void> _onCopyIdRequested(
    CustomerIdCopyRequested event,
    Emitter<CustomerQrState> emit,
  ) async {
    final membershipId = state.qrData?.membershipId.trim() ?? '';
    if (membershipId.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: 'Membership ID is not available yet.',
          feedbackSequence: state.feedbackSequence + 1,
        ),
      );
      return;
    }

    try {
      await _copyToClipboard(membershipId);
      emit(
        state.copyWith(
          clearErrorMessage: true,
          infoMessage: 'Customer ID $membershipId copied to clipboard.',
          feedbackSequence: state.feedbackSequence + 1,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          clearInfoMessage: true,
          errorMessage:
              'Unable to copy customer ID right now. Please try again.',
          feedbackSequence: state.feedbackSequence + 1,
        ),
      );
    }
  }

  void _onFeedbackCleared(
    CustomerQrFeedbackCleared event,
    Emitter<CustomerQrState> emit,
  ) {
    emit(state.copyWith(clearErrorMessage: true, clearInfoMessage: true));
  }
}
