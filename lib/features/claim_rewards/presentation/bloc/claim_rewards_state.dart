import 'package:equatable/equatable.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/claim_wallet_context_entity.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/reward_claim_entity.dart';

enum ClaimRewardsStatus {
  initial,
  loading,
  loaded,
  generatingClaim,
  claimGenerated,
  checkingStatus,
  redeemed,
  expired,
  error,
}

class ClaimRewardsState extends Equatable {
  final ClaimRewardsStatus status;
  final ClaimWalletContextEntity? walletContext;
  final int selectedPoints;
  final String customAmountInput;
  final RewardClaimEntity? currentClaim;
  final int remainingSeconds;
  final String? inputValidationError;
  final String? errorMessage;
  final String? successMessage;
  final int feedbackSequence;

  const ClaimRewardsState({
    this.status = ClaimRewardsStatus.initial,
    this.walletContext,
    this.selectedPoints = 0,
    this.customAmountInput = '',
    this.currentClaim,
    this.remainingSeconds = 0,
    this.inputValidationError,
    this.errorMessage,
    this.successMessage,
    this.feedbackSequence = 0,
  });

  int get availablePoints => walletContext?.availablePoints ?? 0;
  int get reservedPoints => walletContext?.reservedPoints ?? 0;
  int get lockedPoints => walletContext?.lockedPoints ?? 0;
  double get pointsToInrRate => walletContext?.pointsToInrRate ?? 0.10;
  int get pointsPerOneInr => walletContext?.pointsPerOneInr ?? 10;
  RewardClaimEntity? get activePendingClaim =>
      walletContext?.activePendingClaim;

  double get discountAmount =>
      walletContext?.discountForPoints(selectedPoints) ?? 0.0;

  int get remainingBalance =>
      walletContext?.remainingPointsAfter(selectedPoints) ?? 0;

  double get remainingBalanceInr =>
      walletContext?.remainingInrAfter(selectedPoints) ?? 0.0;

  bool get canGenerateClaim =>
      status != ClaimRewardsStatus.loading &&
      status != ClaimRewardsStatus.generatingClaim &&
      walletContext != null &&
      selectedPoints > 0 &&
      selectedPoints <= availablePoints &&
      discountAmount > 0 &&
      inputValidationError == null;

  ClaimRewardsState copyWith({
    ClaimRewardsStatus? status,
    ClaimWalletContextEntity? walletContext,
    int? selectedPoints,
    String? customAmountInput,
    RewardClaimEntity? currentClaim,
    bool clearCurrentClaim = false,
    int? remainingSeconds,
    String? inputValidationError,
    bool clearInputValidationError = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? successMessage,
    bool clearSuccessMessage = false,
    int? feedbackSequence,
  }) {
    return ClaimRewardsState(
      status: status ?? this.status,
      walletContext: walletContext ?? this.walletContext,
      selectedPoints: selectedPoints ?? this.selectedPoints,
      customAmountInput: customAmountInput ?? this.customAmountInput,
      currentClaim:
          clearCurrentClaim ? null : (currentClaim ?? this.currentClaim),
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      inputValidationError:
          clearInputValidationError
              ? null
              : (inputValidationError ?? this.inputValidationError),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccessMessage ? null : (successMessage ?? this.successMessage),
      feedbackSequence: feedbackSequence ?? this.feedbackSequence,
    );
  }

  @override
  List<Object?> get props => [
    status,
    walletContext,
    selectedPoints,
    customAmountInput,
    currentClaim,
    remainingSeconds,
    inputValidationError,
    errorMessage,
    successMessage,
    feedbackSequence,
  ];
}
