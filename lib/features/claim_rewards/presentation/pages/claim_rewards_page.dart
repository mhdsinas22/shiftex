import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/features/claim_rewards/presentation/bloc/claim_rewards_bloc.dart';
import 'package:shiftex/features/claim_rewards/presentation/bloc/claim_rewards_event.dart';
import 'package:shiftex/features/claim_rewards/presentation/widgets/choose_claim_amount_sheet.dart';
import 'package:shiftex/features/claim_rewards/presentation/widgets/single_use_claim_qr_sheet.dart';
import 'package:shiftex/injection_container.dart';

/// Optional route host for deep linking directly to `/claim-rewards`.
/// Primary Home Dashboard entry opens the bottom sheets directly over Home.
class ClaimRewardsPage extends StatefulWidget {
  final ClaimRewardsBloc? bloc;

  const ClaimRewardsPage({super.key, this.bloc});

  @override
  State<ClaimRewardsPage> createState() => _ClaimRewardsPageState();
}

class _ClaimRewardsPageState extends State<ClaimRewardsPage> {
  late final ClaimRewardsBloc _bloc;
  late final bool _ownsBloc;
  bool _showingQr = false;

  @override
  void initState() {
    super.initState();
    if (widget.bloc != null) {
      _bloc = widget.bloc!;
      _ownsBloc = false;
    } else {
      ClaimRewardsBloc? parentBloc;
      try {
        parentBloc = context.read<ClaimRewardsBloc>();
      } catch (_) {
        parentBloc = null;
      }
      if (parentBloc != null) {
        _bloc = parentBloc;
        _ownsBloc = false;
      } else {
        _bloc = getIt<ClaimRewardsBloc>();
        _ownsBloc = true;
      }
    }

    _bloc.add(const ClaimRewardsStarted());
  }

  @override
  void dispose() {
    if (_ownsBloc) {
      _bloc.close();
    }
    super.dispose();
  }

  void _closePage() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(RoutesNames.home);
      }
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ClaimRewardsBloc>.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child:
                  _showingQr
                      ? SingleUseClaimQrSheet(
                        onDone: _closePage,
                        onGenerateNew: () => setState(() => _showingQr = false),
                      )
                      : ChooseClaimAmountSheet(
                        onClose: _closePage,
                        onClaimReady: () => setState(() => _showingQr = true),
                      ),
            ),
          ),
        ),
      ),
    );
  }
}
