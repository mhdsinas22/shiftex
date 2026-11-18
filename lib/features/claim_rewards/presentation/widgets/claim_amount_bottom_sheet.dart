import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/features/claim_rewards/presentation/bloc/claim_rewards_bloc.dart';
import 'package:shiftex/features/claim_rewards/presentation/bloc/claim_rewards_event.dart';
import 'package:shiftex/features/claim_rewards/presentation/widgets/choose_claim_amount_sheet.dart';
import 'package:shiftex/features/claim_rewards/presentation/widgets/single_use_claim_qr_sheet.dart';
import 'package:shiftex/injection_container.dart';

enum _ClaimSheetFlowStep { chooseAmount, showQr, done }

/// Entry point launched when clicking "Claim Rewards" on the Home Dashboard.
/// Coordinates smooth transitions between Choose Claim Amount and
/// Single-Use Claim QR bottom sheets without losing pending claim state.
Future<void> claimAmountBottomSheet(
  BuildContext context, {
  ClaimRewardsBloc? claimRewardsBloc,
  int? initialAvailablePoints,
  double? initialPointsToInrRate,
  int? initialLockedPoints,
  VoidCallback? onFlowClosed,
  bool enableLiveTicker = true,
}) async {
  ClaimRewardsBloc? resolvedBloc = claimRewardsBloc;
  var ownsBloc = false;

  if (resolvedBloc == null) {
    try {
      resolvedBloc = context.read<ClaimRewardsBloc>();
    } catch (_) {
      if (getIt.isRegistered<ClaimRewardsBloc>()) {
        resolvedBloc = getIt<ClaimRewardsBloc>();
        ownsBloc = true;
      }
    }
  }

  if (resolvedBloc == null) {
    return;
  }

  resolvedBloc.add(
    ClaimRewardsStarted(
      fallbackAvailablePoints: initialAvailablePoints,
      fallbackPointsToInrRate: initialPointsToInrRate,
      fallbackLockedPoints: initialLockedPoints,
    ),
  );

  try {
    var step = _ClaimSheetFlowStep.chooseAmount;
    while (step != _ClaimSheetFlowStep.done) {
      if (!context.mounted) {
        break;
      }
      if (step == _ClaimSheetFlowStep.chooseAmount) {
        final action = await ChooseClaimAmountSheet.show(
          context,
          bloc: resolvedBloc,
        );
        step =
            action == ChooseClaimAmountAction.openQr
                ? _ClaimSheetFlowStep.showQr
                : _ClaimSheetFlowStep.done;
      } else if (step == _ClaimSheetFlowStep.showQr) {
        final action = await SingleUseClaimQrSheet.show(
          context,
          bloc: resolvedBloc,
          enableLiveTicker: enableLiveTicker,
        );
        step =
            action == SingleUseClaimQrAction.generateNew
                ? _ClaimSheetFlowStep.chooseAmount
                : _ClaimSheetFlowStep.done;
      }
    }
  } finally {
    if (ownsBloc) {
      await resolvedBloc.close();
    }
    onFlowClosed?.call();
  }
}
