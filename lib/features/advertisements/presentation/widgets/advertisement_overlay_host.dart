import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/features/advertisements/domain/entities/advertisement_entity.dart';
import 'package:shiftex/features/advertisements/presentation/bloc/advertisement_bloc.dart';
import 'package:shiftex/features/advertisements/presentation/bloc/advertisement_event.dart';
import 'package:shiftex/features/advertisements/presentation/bloc/advertisement_state.dart';
import 'package:shiftex/features/advertisements/presentation/widgets/advertisement_popup.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ExternalUrlLauncher = Future<bool> Function(Uri uri);

/// App-root host widget synchronizing authenticated customer sessions with
/// [AdvertisementBloc], rendering the popup overlay over approved customer screens,
/// and executing validated CTA actions without wrapping or rebuilding [child].
class AdvertisementOverlayHost extends StatelessWidget {
  final Widget child;
  final GoRouter router;
  final ExternalUrlLauncher? externalUrlLauncher;

  const AdvertisementOverlayHost({
    super.key,
    required this.child,
    required this.router,
    this.externalUrlLauncher,
  });

  @override
  Widget build(BuildContext context) {
    AdvertisementBloc? adBloc;
    AuthenticationBloc? authBloc;
    try {
      adBloc = context.read<AdvertisementBloc>();
      authBloc = context.read<AuthenticationBloc>();
    } catch (_) {
      adBloc = null;
      authBloc = null;
    }

    if (adBloc == null || authBloc == null) {
      return child;
    }

    return Stack(
      children: [
        child,
        _AdvertisementOverlayLayer(
          adBloc: adBloc,
          authBloc: authBloc,
          router: router,
          externalUrlLauncher: externalUrlLauncher,
        ),
      ],
    );
  }
}

class _AdvertisementOverlayLayer extends StatefulWidget {
  final AdvertisementBloc adBloc;
  final AuthenticationBloc authBloc;
  final GoRouter router;
  final ExternalUrlLauncher? externalUrlLauncher;

  const _AdvertisementOverlayLayer({
    required this.adBloc,
    required this.authBloc,
    required this.router,
    this.externalUrlLauncher,
  });

  @override
  State<_AdvertisementOverlayLayer> createState() =>
      _AdvertisementOverlayLayerState();
}

class _AdvertisementOverlayLayerState
    extends State<_AdvertisementOverlayLayer> {
  StreamSubscription<AuthenticationState>? _authSub;
  StreamSubscription<AdvertisementState>? _adSub;
  int _lastHandledCtaSequence = 0;

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_onRouterChanged);

    _authSub = widget.authBloc.stream.listen((authState) {
      _syncAuthState(authState);
      if (mounted) setState(() {});
    });

    _adSub = widget.adBloc.stream.listen((adState) {
      _handleAdStateAction(adState);
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncAuthState(widget.authBloc.state);
      _handleAdStateAction(widget.adBloc.state);
    });
  }

  @override
  void didUpdateWidget(_AdvertisementOverlayLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routerDelegate.removeListener(_onRouterChanged);
      widget.router.routerDelegate.addListener(_onRouterChanged);
    }
  }

  void _onRouterChanged() {
    if (!mounted) return;
    // Schedule after Router finishes its current build/notification frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _syncAuthState(AuthenticationState authState) {
    if (authState is AuthenticationSuccess && authState.profile.isApproved) {
      widget.adBloc.add(
        AdvertisementSessionStarted(userId: authState.profile.id),
      );
    } else if (authState is Unauthenticated ||
        (authState is AuthenticationSuccess && !authState.profile.isApproved) ||
        authState is PendingApproval ||
        authState is AccountRejected ||
        authState is AccountSuspended ||
        authState is OtpVerificationRequired) {
      widget.adBloc.add(const AdvertisementSessionEnded());
    }
  }

  void _handleAdStateAction(AdvertisementState adState) {
    final action = adState.pendingCtaAction;
    if (action == null ||
        adState.ctaActionSequence == _lastHandledCtaSequence) {
      return;
    }
    _lastHandledCtaSequence = adState.ctaActionSequence;
    widget.adBloc.add(const AdvertisementPendingActionHandled());
    unawaited(_executeCtaAction(action));
  }

  Future<void> _executeCtaAction(AdvertisementPendingCtaAction action) async {
    if (action.actionType == AdvertisementCtaActionType.internalRoute) {
      final route = action.internalRoute;
      if (route != null &&
          AdvertisementEntity.allowedInternalRoutes.contains(route)) {
        if (route == RoutesNames.home) {
          widget.router.go(route);
        } else {
          unawaited(widget.router.push(route));
        }
      }
      return;
    }

    if (action.actionType == AdvertisementCtaActionType.externalUrl) {
      final uri = action.externalUri;
      if (uri == null || uri.scheme.toLowerCase() != 'https') return;
      try {
        final launcher =
            widget.externalUrlLauncher ??
            (u) => launchUrl(u, mode: LaunchMode.externalApplication);
        await launcher(uri);
      } catch (_) {
        // Fail silently if no external browser handler exists on device.
      }
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRouterChanged);
    unawaited(_authSub?.cancel());
    unawaited(_adSub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = widget.authBloc.state;
    final adState = widget.adBloc.state;
    final isApprovedCustomer =
        authState is AuthenticationSuccess && authState.profile.isApproved;
    final currentLocation =
        widget.router.routerDelegate.currentConfiguration.uri.path;
    final onProtectedCustomerRoute =
        currentLocation == RoutesNames.home ||
        currentLocation == RoutesNames.customerQr ||
        currentLocation == RoutesNames.claimRewards ||
        currentLocation == RoutesNames.activityHistory;

    final showPopup =
        isApprovedCustomer &&
        onProtectedCustomerRoute &&
        adState.status == AdvertisementStatus.showing &&
        adState.activeAdvertisement != null;

    if (!showPopup) {
      return const SizedBox.shrink();
    }

    return AdvertisementPopup(
      key: ValueKey(
        'ad_popup_${adState.activeAdvertisement!.id}_${adState.presentationSequence}',
      ),
      advertisement: adState.activeAdvertisement!,
      remainingSeconds: adState.remainingSeconds,
      totalSeconds: adState.totalSeconds,
      onClose: () => widget.adBloc.add(const AdvertisementDismissRequested()),
      onCtaTap: adState.activeAdvertisement!.hasConfiguredCta
          ? () => widget.adBloc.add(const AdvertisementCtaPressed())
          : null,
    );
  }
}
