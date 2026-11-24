import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/claim_rewards/presentation/bloc/claim_rewards_bloc.dart';
import 'package:shiftex/features/claim_rewards/presentation/bloc/claim_rewards_event.dart';
import 'package:shiftex/features/claim_rewards/presentation/bloc/claim_rewards_state.dart';
import 'package:shiftex/features/claim_rewards/presentation/widgets/available_balance_card.dart';
import 'package:shiftex/features/claim_rewards/presentation/widgets/claim_amount_presets.dart';
import 'package:shiftex/features/claim_rewards/presentation/widgets/claim_summary_card.dart';
import 'package:shiftex/features/claim_rewards/presentation/widgets/custom_points_input.dart';
import 'package:shiftex/features/home/presentation/widgets/home_formatters.dart';

enum ChooseClaimAmountAction { close, openQr }

/// Modal bottom sheet allowing customers to select quick presets, Claim Full,
/// or enter a custom instant point amount before generating a Claim QR.
class ChooseClaimAmountSheet extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onClaimReady;

  const ChooseClaimAmountSheet({
    super.key,
    required this.onClose,
    required this.onClaimReady,
  });

  static Future<ChooseClaimAmountAction?> show(
    BuildContext context, {
    required ClaimRewardsBloc bloc,
  }) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    return showModalBottomSheet<ChooseClaimAmountAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.white,
      constraints: BoxConstraints(maxHeight: maxHeight),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) {
        return BlocProvider<ClaimRewardsBloc>.value(
          value: bloc,
          child: ChooseClaimAmountSheet(
            onClose: () => Navigator.of(
              sheetContext,
            ).pop(ChooseClaimAmountAction.close),
            onClaimReady: () {
              FocusManager.instance.primaryFocus?.unfocus();
              if (Navigator.of(sheetContext).canPop()) {
                Navigator.of(sheetContext).pop(ChooseClaimAmountAction.openQr);
              }
            },
          ),
        );
      },
    );
  }

  @override
  State<ChooseClaimAmountSheet> createState() => _ChooseClaimAmountSheetState();
}

class _ChooseClaimAmountSheetState extends State<ChooseClaimAmountSheet> {
  bool _navigatedToQr = false;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = screenWidth < 360 ? 16.0 : 22.0;

    return BlocConsumer<ClaimRewardsBloc, ClaimRewardsState>(
      listenWhen:
          (previous, current) =>
              previous.status != current.status ||
              previous.currentClaim != current.currentClaim,
      listener: (context, state) {
        if (!_navigatedToQr &&
            state.status == ClaimRewardsStatus.claimGenerated &&
            state.currentClaim != null) {
          _navigatedToQr = true;
          widget.onClaimReady();
        }
      },
      builder: (context, state) {
        final bloc = context.read<ClaimRewardsBloc>();
        final walletContext = state.walletContext;
        final isInitialLoading =
            state.status == ClaimRewardsStatus.loading && walletContext == null;
        final isInitialError =
            state.status == ClaimRewardsStatus.error && walletContext == null;
        final isGenerating =
            state.status == ClaimRewardsStatus.generatingClaim;

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 20 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.dragHandle,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose Claim Amount',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Select points to redeem at the cashier',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: AppColors.inputBackground,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: widget.onClose,
                        child: const SizedBox(
                          width: 38,
                          height: 38,
                          child: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (isInitialLoading)
                  _buildLoadingSkeleton()
                else if (isInitialError)
                  _buildErrorCard(
                    message:
                        state.errorMessage ??
                        'Unable to load claimable wallet balance.',
                    onRetry:
                        () => bloc.add(const ClaimRewardsContextRefreshed()),
                  )
                else ...[
                  if (state.status == ClaimRewardsStatus.loading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: LinearProgressIndicator(
                        minHeight: 2.5,
                        color: AppColors.primaryBlue,
                        backgroundColor: AppColors.inputBackground,
                      ),
                    ),
                  if (state.activePendingClaim != null) ...[
                    _buildActivePendingBanner(bloc, state),
                    const SizedBox(height: 12),
                  ],
                  ClaimAvailableBalanceCard(
                    availablePoints: state.availablePoints,
                    availableInr:
                        walletContext?.availableInr ??
                        state.availablePoints * state.pointsToInrRate,
                    onClaimFullTap:
                        state.availablePoints > 0 && !isGenerating
                            ? () => bloc.add(const ClaimFullRequested())
                            : null,
                  ),
                  const SizedBox(height: 18),
                  ClaimAmountPresets(
                    presets: ClaimRewardsBloc.quickPresets,
                    selectedPoints: state.selectedPoints,
                    availablePoints: state.availablePoints,
                    pointsToInrRate: state.pointsToInrRate,
                    onPresetSelected:
                        (pts) => bloc.add(ClaimPresetSelected(pts)),
                  ),
                  const SizedBox(height: 18),
                  CustomPointsInput(
                    value: state.customAmountInput,
                    discountInr: state.discountAmount,
                    enabled: !isGenerating && state.availablePoints > 0,
                    validationError: state.inputValidationError,
                    onChanged:
                        (raw) => bloc.add(ClaimCustomAmountChanged(raw)),
                  ),
                  const SizedBox(height: 16),
                  ClaimSummaryCard(
                    pointsToDeduct: state.selectedPoints,
                    discountInr: state.discountAmount,
                    remainingBalance: state.remainingBalance,
                    remainingBalanceInr: state.remainingBalanceInr,
                  ),
                  if (state.errorMessage != null &&
                      state.errorMessage!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildInlineNotice(
                      message: state.errorMessage!,
                      isError: true,
                    ),
                  ] else if (state.successMessage != null &&
                      state.successMessage!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildInlineNotice(
                      message: state.successMessage!,
                      isError: false,
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          state.canGenerateClaim
                              ? () => bloc.add(const ClaimGenerateRequested())
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.primaryBlue
                            .withValues(alpha: 0.4),
                        disabledForegroundColor: AppColors.white.withValues(
                          alpha: 0.85,
                        ),
                        elevation: 0,
                        shape: const StadiumBorder(),
                      ),
                      child:
                          isGenerating
                              ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.3,
                                  color: AppColors.white,
                                ),
                              )
                              : const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Generate Claim QR',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_rounded, size: 19),
                                  ],
                                ),
                              ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivePendingBanner(
    ClaimRewardsBloc bloc,
    ClaimRewardsState state,
  ) {
    final pending = state.activePendingClaim!;
    final remSeconds = pending.remainingSecondsAt(DateTime.now().toUtc());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.gradientTopLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pending_actions_rounded,
                size: 18,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Active Pending Claim • ${pending.claimReference}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                HomeFormatters.formatMmSs(remSeconds),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${HomeFormatters.formatPoints(pending.points)} pts reserved for cashier scan.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton.tonal(
                onPressed: () {
                  _navigatedToQr = true;
                  bloc.add(ClaimPendingResumed(pending));
                  widget.onClaimReady();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text(
                  'View QR',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton(
                onPressed: () => bloc.add(ClaimCancelRequested(pending.id)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.errorRed,
                  side: const BorderSide(color: AppColors.errorBorder),
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text(
                  'Cancel Claim',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInlineNotice({
    required String message,
    required bool isError,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? AppColors.errorSurface : AppColors.approvedBadgeBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isError
                  ? AppColors.errorBorder
                  : AppColors.validationSuccess.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 18,
            color:
                isError ? AppColors.errorRed : AppColors.approvedBadgeText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color:
                    isError ? AppColors.errorRed : AppColors.approvedBadgeText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Column(
      children: [
        Container(
          height: 70,
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 112,
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 20),
        const Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.errorBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 32,
            color: AppColors.errorRed,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryButtonDark,
              foregroundColor: AppColors.white,
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
