import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/claim_wallet_context_entity.dart';
import 'package:shiftex/features/claim_rewards/domain/usecases/cancel_reward_claim_usecase.dart';
import 'package:shiftex/features/claim_rewards/domain/usecases/create_reward_claim_usecase.dart';
import 'package:shiftex/features/claim_rewards/domain/usecases/get_claim_rewards_context_usecase.dart';
import 'package:shiftex/features/claim_rewards/domain/usecases/get_customer_claim_status_usecase.dart';
import 'package:shiftex/features/claim_rewards/presentation/bloc/claim_rewards_event.dart';
import 'package:shiftex/features/claim_rewards/presentation/bloc/claim_rewards_state.dart';

typedef ClaimClockProvider = DateTime Function();

class ClaimRewardsBloc extends Bloc<ClaimRewardsEvent, ClaimRewardsState> {
  static const List<int> quickPresets = [100, 250, 500, 1000];

  final GetClaimRewardsContextUseCase _getContextUseCase;
  final CreateRewardClaimUseCase _createClaimUseCase;
  final GetCustomerClaimStatusUseCase _getClaimStatusUseCase;
  final CancelRewardClaimUseCase _cancelClaimUseCase;
  final ClaimClockProvider _clockProvider;

  int _idempotencyCounter = 0;

  ClaimRewardsBloc({
    required GetClaimRewardsContextUseCase getClaimRewardsContextUseCase,
    required CreateRewardClaimUseCase createRewardClaimUseCase,
    required GetCustomerClaimStatusUseCase getCustomerClaimStatusUseCase,
    required CancelRewardClaimUseCase cancelRewardClaimUseCase,
    ClaimClockProvider? clockProvider,
  }) : _getContextUseCase = getClaimRewardsContextUseCase,
       _createClaimUseCase = createRewardClaimUseCase,
       _getClaimStatusUseCase = getCustomerClaimStatusUseCase,
       _cancelClaimUseCase = cancelRewardClaimUseCase,
       _clockProvider = clockProvider ?? _defaultClockProvider,
       super(const ClaimRewardsState()) {
    on<ClaimRewardsStarted>(_onStarted);
    on<ClaimRewardsContextRefreshed>(_onContextRefreshed);
    on<ClaimPresetSelected>(_onPresetSelected);
    on<ClaimFullRequested>(_onClaimFullRequested);
    on<ClaimCustomAmountChanged>(_onCustomAmountChanged);
    on<ClaimGenerateRequested>(_onGenerateRequested);
    on<ClaimPendingResumed>(_onPendingResumed);
    on<ClaimStatusCheckRequested>(_onStatusCheckRequested);
    on<ClaimCountdownTicked>(_onCountdownTicked);
    on<ClaimCancelRequested>(_onCancelRequested);
    on<ClaimPrepareNewRequested>(_onPrepareNewRequested);
    on<ClaimFeedbackCleared>(_onFeedbackCleared);
  }

  static DateTime _defaultClockProvider() => DateTime.now().toUtc();

  int _pickDefaultSelection(int availablePoints) {
    if (availablePoints >= 250) return 250;
    if (availablePoints >= 100) return 100;
    if (availablePoints > 0) return availablePoints;
    return 0;
  }

  String? _validatePointSelection(int points, int availablePoints) {
    if (availablePoints <= 0) {
      return 'No instant available points to claim.';
    }
    if (points <= 0) {
      return 'Enter at least 1 instant point to claim.';
    }
    if (points > availablePoints) {
      return 'Exceeds your $availablePoints instant available points.';
    }
    return null;
  }

  Future<void> _onStarted(
    ClaimRewardsStarted event,
    Emitter<ClaimRewardsState> emit,
  ) async {
    ClaimWalletContextEntity? optimisticContext;
    int initialSelected = state.selectedPoints;
    String initialInput = state.customAmountInput;

    if (event.fallbackAvailablePoints != null) {
      final avail = event.fallbackAvailablePoints!;
      optimisticContext = ClaimWalletContextEntity(
        customerCode: 'SHFT-0000',
        membershipTier: 'Pebble Black Member',
        availablePoints: avail,
        reservedPoints: 0,
        lockedPoints: event.fallbackLockedPoints ?? 0,
        pointsToInrRate: event.fallbackPointsToInrRate ?? 0.10,
      );
      initialSelected = _pickDefaultSelection(avail);
      initialInput = initialSelected > 0 ? '$initialSelected' : '';
    }

    emit(
      state.copyWith(
        status: ClaimRewardsStatus.loading,
        walletContext: optimisticContext ?? state.walletContext,
        selectedPoints: initialSelected,
        customAmountInput: initialInput,
        clearInputValidationError: true,
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );

    await _fetchContext(emit);
  }

  Future<void> _onContextRefreshed(
    ClaimRewardsContextRefreshed event,
    Emitter<ClaimRewardsState> emit,
  ) async {
    if (state.status == ClaimRewardsStatus.loading ||
        state.status == ClaimRewardsStatus.generatingClaim) {
      return;
    }

    emit(
      state.copyWith(
        status: ClaimRewardsStatus.loading,
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );

    await _fetchContext(emit);
  }

  Future<void> _fetchContext(Emitter<ClaimRewardsState> emit) async {
    final result = await _getContextUseCase(const NoParams());
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ClaimRewardsStatus.error,
          errorMessage: failure.message,
          feedbackSequence: state.feedbackSequence + 1,
        ),
      ),
      (context) {
        final previousSelected = state.selectedPoints;
        final nextSelected =
            previousSelected > 0 && previousSelected <= context.availablePoints
                ? previousSelected
                : _pickDefaultSelection(context.availablePoints);
        emit(
          state.copyWith(
            status: ClaimRewardsStatus.loaded,
            walletContext: context,
            selectedPoints: nextSelected,
            customAmountInput: nextSelected > 0 ? '$nextSelected' : '',
            inputValidationError:
                context.availablePoints <= 0
                    ? 'No instant available points to claim.'
                    : null,
            clearInputValidationError: context.availablePoints > 0,
            clearErrorMessage: true,
          ),
        );
      },
    );
  }

  void _onPresetSelected(
    ClaimPresetSelected event,
    Emitter<ClaimRewardsState> emit,
  ) {
    final available = state.availablePoints;
    if (event.points > available) {
      emit(
        state.copyWith(
          inputValidationError:
              '${event.points} pts exceeds your $available instant available points.',
        ),
      );
      return;
    }
    if (event.points <= 0) {
      emit(
        state.copyWith(
          inputValidationError: 'Select a positive point amount.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        selectedPoints: event.points,
        customAmountInput: '${event.points}',
        clearInputValidationError: true,
        clearErrorMessage: true,
      ),
    );
  }

  void _onClaimFullRequested(
    ClaimFullRequested event,
    Emitter<ClaimRewardsState> emit,
  ) {
    final available = state.availablePoints;
    if (available <= 0) {
      emit(
        state.copyWith(
          selectedPoints: 0,
          customAmountInput: '',
          inputValidationError: 'No instant available points to claim.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        selectedPoints: available,
        customAmountInput: '$available',
        clearInputValidationError: true,
        clearErrorMessage: true,
      ),
    );
  }

  void _onCustomAmountChanged(
    ClaimCustomAmountChanged event,
    Emitter<ClaimRewardsState> emit,
  ) {
    final trimmed = event.rawInput.trim();
    if (trimmed.isEmpty) {
      emit(
        state.copyWith(
          selectedPoints: 0,
          customAmountInput: '',
          inputValidationError:
              state.availablePoints <= 0
                  ? 'No instant available points to claim.'
                  : 'Enter a point amount to claim.',
          clearErrorMessage: true,
        ),
      );
      return;
    }

    final parsed = int.tryParse(trimmed);
    if (parsed == null || !RegExp(r'^[0-9]+$').hasMatch(trimmed)) {
      emit(
        state.copyWith(
          selectedPoints: 0,
          customAmountInput: event.rawInput,
          inputValidationError: 'Enter a positive whole number of points.',
          clearErrorMessage: true,
        ),
      );
      return;
    }

    final validationError = _validatePointSelection(
      parsed,
      state.availablePoints,
    );
    emit(
      state.copyWith(
        selectedPoints: parsed,
        customAmountInput: trimmed,
        inputValidationError: validationError,
        clearInputValidationError: validationError == null,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> _onGenerateRequested(
    ClaimGenerateRequested event,
    Emitter<ClaimRewardsState> emit,
  ) async {
    if (state.status == ClaimRewardsStatus.generatingClaim ||
        state.status == ClaimRewardsStatus.loading) {
      return;
    }

    final validationError = _validatePointSelection(
      state.selectedPoints,
      state.availablePoints,
    );
    if (validationError != null || state.discountAmount <= 0) {
      emit(
        state.copyWith(
          inputValidationError:
              validationError ?? 'Select a valid discount amount.',
          errorMessage: validationError ?? 'Select a valid discount amount.',
          feedbackSequence: state.feedbackSequence + 1,
        ),
      );
      return;
    }

    final key =
        event.idempotencyKey ??
        'clm_${_clockProvider().microsecondsSinceEpoch}_${++_idempotencyCounter}';

    emit(
      state.copyWith(
        status: ClaimRewardsStatus.generatingClaim,
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );

    final result = await _createClaimUseCase(
      CreateRewardClaimParams(
        points: state.selectedPoints,
        idempotencyKey: key,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ClaimRewardsStatus.loaded,
          errorMessage: failure.message,
          feedbackSequence: state.feedbackSequence + 1,
        ),
      ),
      (operation) {
        final remaining = operation.claim.remainingSecondsAt(_clockProvider());
        emit(
          state.copyWith(
            status: ClaimRewardsStatus.claimGenerated,
            walletContext: operation.wallet,
            currentClaim: operation.claim,
            remainingSeconds: remaining,
            selectedPoints: operation.claim.points,
            customAmountInput: '${operation.claim.points}',
            clearInputValidationError: true,
            clearErrorMessage: true,
          ),
        );
      },
    );
  }

  void _onPendingResumed(
    ClaimPendingResumed event,
    Emitter<ClaimRewardsState> emit,
  ) {
    final now = _clockProvider();
    final remaining = event.claim.remainingSecondsAt(now);
    final isExpired = event.claim.isExpiredAt(now);
    emit(
      state.copyWith(
        status:
            isExpired
                ? ClaimRewardsStatus.expired
                : ClaimRewardsStatus.claimGenerated,
        currentClaim: event.claim,
        remainingSeconds: remaining,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> _onCountdownTicked(
    ClaimCountdownTicked event,
    Emitter<ClaimRewardsState> emit,
  ) async {
    final claim = state.currentClaim;
    if (claim == null || !claim.isPending) return;

    final now = event.now ?? _clockProvider();
    final remaining = claim.remainingSecondsAt(now);

    if (remaining > 0) {
      if (remaining != state.remainingSeconds) {
        emit(state.copyWith(remainingSeconds: remaining));
      }
      return;
    }

    // Timer expired: confirm with backend so reservation releases atomically
    emit(state.copyWith(remainingSeconds: 0));
    await _syncClaimStatus(emit, claim.id);
  }

  Future<void> _onStatusCheckRequested(
    ClaimStatusCheckRequested event,
    Emitter<ClaimRewardsState> emit,
  ) async {
    final claim = state.currentClaim;
    if (claim == null ||
        state.status == ClaimRewardsStatus.checkingStatus ||
        state.status == ClaimRewardsStatus.generatingClaim) {
      return;
    }

    emit(
      state.copyWith(
        status: ClaimRewardsStatus.checkingStatus,
        clearErrorMessage: true,
      ),
    );
    await _syncClaimStatus(emit, claim.id);
  }

  Future<void> _syncClaimStatus(
    Emitter<ClaimRewardsState> emit,
    String claimId,
  ) async {
    final result = await _getClaimStatusUseCase(
      GetCustomerClaimStatusParams(claimId: claimId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status:
              state.remainingSeconds <= 0
                  ? ClaimRewardsStatus.expired
                  : ClaimRewardsStatus.claimGenerated,
          errorMessage: failure.message,
          feedbackSequence: state.feedbackSequence + 1,
        ),
      ),
      (operation) {
        final claim = operation.claim;
        final now = _clockProvider();
        final remaining = claim.remainingSecondsAt(now);

        if (claim.isRedeemed) {
          emit(
            state.copyWith(
              status: ClaimRewardsStatus.redeemed,
              walletContext: operation.wallet,
              currentClaim: claim,
              remainingSeconds: 0,
              successMessage:
                  'Redeemed ${claim.points} pts for bill discount!',
              feedbackSequence: state.feedbackSequence + 1,
              clearErrorMessage: true,
            ),
          );
          return;
        }

        if (claim.isExpired || claim.isCancelled || remaining <= 0) {
          emit(
            state.copyWith(
              status: ClaimRewardsStatus.expired,
              walletContext: operation.wallet,
              currentClaim: claim,
              remainingSeconds: 0,
              clearErrorMessage: true,
            ),
          );
          return;
        }

        emit(
          state.copyWith(
            status: ClaimRewardsStatus.claimGenerated,
            walletContext: operation.wallet,
            currentClaim: claim,
            remainingSeconds: remaining,
            clearErrorMessage: true,
          ),
        );
      },
    );
  }

  Future<void> _onCancelRequested(
    ClaimCancelRequested event,
    Emitter<ClaimRewardsState> emit,
  ) async {
    if (state.status == ClaimRewardsStatus.loading ||
        state.status == ClaimRewardsStatus.generatingClaim) {
      return;
    }

    emit(
      state.copyWith(
        status: ClaimRewardsStatus.loading,
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );

    final result = await _cancelClaimUseCase(
      CancelRewardClaimParams(claimId: event.claimId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ClaimRewardsStatus.loaded,
          errorMessage: failure.message,
          feedbackSequence: state.feedbackSequence + 1,
        ),
      ),
      (operation) {
        final nextSelected = _pickDefaultSelection(
          operation.wallet.availablePoints,
        );
        emit(
          state.copyWith(
            status: ClaimRewardsStatus.loaded,
            walletContext: operation.wallet,
            clearCurrentClaim: true,
            remainingSeconds: 0,
            selectedPoints: nextSelected,
            customAmountInput: nextSelected > 0 ? '$nextSelected' : '',
            clearInputValidationError: true,
            successMessage:
                'Pending claim cancelled and ${operation.claim.points} pts restored.',
            feedbackSequence: state.feedbackSequence + 1,
          ),
        );
      },
    );
  }

  Future<void> _onPrepareNewRequested(
    ClaimPrepareNewRequested event,
    Emitter<ClaimRewardsState> emit,
  ) async {
    emit(
      state.copyWith(
        status: ClaimRewardsStatus.loading,
        clearCurrentClaim: true,
        remainingSeconds: 0,
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );
    await _fetchContext(emit);
  }

  void _onFeedbackCleared(
    ClaimFeedbackCleared event,
    Emitter<ClaimRewardsState> emit,
  ) {
    emit(state.copyWith(clearErrorMessage: true, clearSuccessMessage: true));
  }
}
