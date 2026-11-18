import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/widgets/shiiftex_primary_button.dart';
import 'package:shiftex/features/claim_rewards/domain/entities/reward_claim_entity.dart';
import 'package:shiftex/features/claim_rewards/presentation/bloc/claim_rewards_bloc.dart';
import 'package:shiftex/features/claim_rewards/presentation/bloc/claim_rewards_event.dart';
import 'package:shiftex/features/claim_rewards/presentation/bloc/claim_rewards_state.dart';
import 'package:shiftex/features/claim_rewards/presentation/widgets/claim_countdown_timer.dart';
import 'package:shiftex/features/claim_rewards/presentation/widgets/claim_expired_view.dart';
import 'package:shiftex/features/home/presentation/widgets/home_formatters.dart';

enum SingleUseClaimQrAction { done, generateNew }

/// Displays the generated single-use cryptographic Claim QR for cashier
/// verification, countdown expiry, redemption confirmation, and release handling.
class SingleUseClaimQrSheet extends StatefulWidget {
  final VoidCallback onDone;
  final VoidCallback onGenerateNew;
  final bool enableLiveTicker;

  const SingleUseClaimQrSheet({
    super.key,
    required this.onDone,
    required this.onGenerateNew,
    this.enableLiveTicker = true,
  });

  static Future<SingleUseClaimQrAction?> show(
    BuildContext context, {
    required ClaimRewardsBloc bloc,
    bool enableLiveTicker = true,
  }) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    return showModalBottomSheet<SingleUseClaimQrAction>(
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
          child: SingleUseClaimQrSheet(
            enableLiveTicker: enableLiveTicker,
            onDone: () =>
                Navigator.of(sheetContext).pop(SingleUseClaimQrAction.done),
            onGenerateNew: () => Navigator.of(
              sheetContext,
            ).pop(SingleUseClaimQrAction.generateNew),
          ),
        );
      },
    );
  }

  @override
  State<SingleUseClaimQrSheet> createState() => _SingleUseClaimQrSheetState();
}

class _SingleUseClaimQrSheetState extends State<SingleUseClaimQrSheet>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<ClaimRewardsBloc>().add(const ClaimStatusCheckRequested());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = screenWidth < 360 ? 16.0 : 22.0;

    return BlocBuilder<ClaimRewardsBloc, ClaimRewardsState>(
      builder: (context, state) {
        final bloc = context.read<ClaimRewardsBloc>();
        final claim = state.currentClaim ?? state.activePendingClaim;

        if (claim == null) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'No active claim selected.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ShiiftexPrimaryButton(
                    label: 'Done',
                    showTrailingArrow: false,
                    onPressed: widget.onDone,
                  ),
                ],
              ),
            ),
          );
        }

        final isRedeemed =
            state.status == ClaimRewardsStatus.redeemed || claim.isRedeemed;
        final isExpired =
            !isRedeemed &&
            (state.status == ClaimRewardsStatus.expired ||
                claim.isExpired ||
                claim.isCancelled ||
                state.remainingSeconds <= 0 && claim.isPending && claim.isExpiredAt(DateTime.now().toUtc()));

        final pointsText = HomeFormatters.formatPoints(claim.points);
        final discountText = HomeFormatters.formatInr(claim.discountAmount);
        final isChecking = state.status == ClaimRewardsStatus.checkingStatus;
        final qrSize = (screenWidth * 0.44).clamp(142.0, 182.0);

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 20),
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
                            'Single-Use Claim QR',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Show this to the cashier / merchant to redeem',
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
                        onTap: widget.onDone,
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
                // Redemption Value summary card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryButtonDark,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.card_giftcard_rounded,
                          size: 19,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Redemption Value',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$pointsText pts ≈ $discountText Off Bill',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8EF63C),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Instant',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0B2405),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Main QR Container
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child:
                      isRedeemed
                          ? _buildRedeemedCard(claim, state)
                          : isExpired
                          ? ClaimExpiredView(
                            claimReference: claim.claimReference,
                            points: claim.points,
                            isCancelled: claim.isCancelled,
                            onGenerateNewClaim: () {
                              bloc.add(const ClaimPrepareNewRequested());
                              widget.onGenerateNew();
                            },
                          )
                          : _buildActiveQrContent(
                            claim: claim,
                            qrSize: qrSize,
                            isChecking: isChecking,
                            onExpired:
                                () => bloc.add(
                                  ClaimCountdownTicked(now: DateTime.now().toUtc()),
                                ),
                            onCheckStatus:
                                () => bloc.add(
                                  const ClaimStatusCheckRequested(),
                                ),
                          ),
                ),
                if (state.errorMessage != null &&
                    state.errorMessage!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    state.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.errorRed,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'One-time encrypted code. Automatically invalidates after cash register scan or after 5 minutes.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ShiiftexPrimaryButton(
                  label: 'Done',
                  showTrailingArrow: false,
                  onPressed: widget.onDone,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveQrContent({
    required RewardClaimEntity claim,
    required double qrSize,
    required bool isChecking,
    required VoidCallback onExpired,
    required VoidCallback onCheckStatus,
  }) {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            const Text(
              'ACTIVE • SINGLE-USE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 0.6,
              ),
            ),
            ClaimCountdownTimer(
              expiresAt: claim.expiresAt,
              isActive: claim.isPending,
              enableLiveTicker: widget.enableLiveTicker,
              onExpired: onExpired,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Semantics(
            label: 'Single-use claim QR code',
            image: true,
            child: QrImageView(
              data: claim.qrPayload,
              version: QrVersions.auto,
              size: qrSize,
              padding: EdgeInsets.zero,
              backgroundColor: AppColors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF0E1525),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF0E1525),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SelectableText(
          claim.claimReference,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Dynamic cryptographic token',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: isChecking ? null : onCheckStatus,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryBlue,
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          icon:
              isChecking
                  ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryBlue,
                    ),
                  )
                  : const Icon(Icons.sync_rounded, size: 16),
          label: Text(
            isChecking ? 'Checking status...' : 'Refresh Claim Status',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildRedeemedCard(
    RewardClaimEntity claim,
    ClaimRewardsState state,
  ) {
    final ptsText = HomeFormatters.formatPoints(claim.points);
    final discText = HomeFormatters.formatInr(claim.discountAmount);
    final updatedBalance = HomeFormatters.formatPoints(state.availablePoints);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.validationSuccess.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: AppColors.approvedBadgeBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 32,
              color: AppColors.approvedBadgeText,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Claim Redeemed!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$ptsText pts ($discText discount) deducted at checkout.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (claim.billNumber != null && claim.billNumber!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Bill #${claim.billNumber}${claim.branchName != null ? ' • ${claim.branchName}' : ''}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Remaining Instant Balance: $updatedBalance pts',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
