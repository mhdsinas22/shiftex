import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/core/routes/app_router.dart';
import 'package:shiftex/core/theme/app_theme.dart';
import 'package:shiftex/features/account_approval/presentation/bloc/account_approval_bloc.dart';
import 'package:shiftex/features/account_approval/presentation/bloc/account_approval_event.dart';
import 'package:shiftex/features/account_approval/presentation/bloc/account_approval_state.dart';
import 'package:shiftex/features/advertisements/presentation/bloc/advertisement_bloc.dart';
import 'package:shiftex/features/advertisements/presentation/bloc/advertisement_event.dart';
import 'package:shiftex/features/advertisements/presentation/bloc/advertisement_state.dart';
import 'package:shiftex/features/advertisements/presentation/widgets/advertisement_overlay_host.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';
import 'package:shiftex/features/home/presentation/bloc/home_bloc.dart';
import 'package:shiftex/features/home/presentation/bloc/home_event.dart';
import 'package:shiftex/features/home/presentation/bloc/home_state.dart';
import 'package:shiftex/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:shiftex/features/notifications/presentation/bloc/notification_event.dart';
import 'package:shiftex/features/notifications/presentation/bloc/notification_state.dart';
import 'package:shiftex/injection_container.dart';

class Shiftexapp extends StatefulWidget {
  final AuthenticationBloc? authenticationBloc;
  final AccountApprovalBloc? accountApprovalBloc;
  final HomeBloc? homeBloc;
  final AdvertisementBloc? advertisementBloc;
  final NotificationBloc? notificationBloc;
  final AppRouter? appRouter;
  final ExternalUrlLauncher? externalUrlLauncher;

  const Shiftexapp({
    super.key,
    this.authenticationBloc,
    this.accountApprovalBloc,
    this.homeBloc,
    this.advertisementBloc,
    this.notificationBloc,
    this.appRouter,
    this.externalUrlLauncher,
  });

  @override
  State<Shiftexapp> createState() => _ShiftexappState();
}

class _ShiftexappState extends State<Shiftexapp> {
  late final AuthenticationBloc _authBloc;
  late final AppRouter _router;

  NotificationBloc? _resolveNotificationBloc() {
    if (widget.notificationBloc != null) {
      return widget.notificationBloc;
    }
    if (getIt.isRegistered<NotificationBloc>()) {
      return getIt<NotificationBloc>();
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _authBloc = widget.authenticationBloc ?? getIt<AuthenticationBloc>();
    _router =
        widget.appRouter ??
        (widget.authenticationBloc != null
            ? AppRouter(authenticationBloc: _authBloc)
            : getIt<AppRouter>());
  }

  @override
  Widget build(BuildContext context) {
    final notifBloc = _resolveNotificationBloc();

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthenticationBloc>.value(value: _authBloc),
        if (widget.accountApprovalBloc != null)
          BlocProvider<AccountApprovalBloc>.value(
            value: widget.accountApprovalBloc!,
          )
        else if (getIt.isRegistered<AccountApprovalBloc>())
          BlocProvider<AccountApprovalBloc>(
            create: (_) => getIt<AccountApprovalBloc>(),
          ),
        if (widget.homeBloc != null)
          BlocProvider<HomeBloc>.value(value: widget.homeBloc!)
        else if (getIt.isRegistered<HomeBloc>())
          BlocProvider<HomeBloc>(create: (_) => getIt<HomeBloc>()),
        if (widget.advertisementBloc != null)
          BlocProvider<AdvertisementBloc>.value(
            value: widget.advertisementBloc!,
          )
        else if (getIt.isRegistered<AdvertisementBloc>())
          BlocProvider<AdvertisementBloc>.value(
            value: getIt<AdvertisementBloc>(),
          ),
        if (notifBloc != null)
          BlocProvider<NotificationBloc>.value(value: notifBloc),
      ],
      child: _SessionLifecycleBridge(
        authBloc: _authBloc,
        child: MaterialApp.router(
          title: 'SHIIFTEX',
          theme: AppTheme.lightTheme,
          routerConfig: _router.router,
          builder: (context, child) => AdvertisementOverlayHost(
            router: _router.router,
            externalUrlLauncher: widget.externalUrlLauncher,
            child: child ?? const SizedBox.shrink(),
          ),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

/// Synchronizes all user-scoped BLoCs (`HomeBloc`, `AccountApprovalBloc`,
/// `NotificationBloc`, `AdvertisementBloc`) with authentication transitions so
/// logout or switching accounts never retains stale customer state.
class _SessionLifecycleBridge extends StatefulWidget {
  final AuthenticationBloc authBloc;
  final Widget child;

  const _SessionLifecycleBridge({
    required this.authBloc,
    required this.child,
  });

  @override
  State<_SessionLifecycleBridge> createState() =>
      _SessionLifecycleBridgeState();
}

class _SessionLifecycleBridgeState extends State<_SessionLifecycleBridge> {
  String? _activeApprovedUserId;

  T? _maybeRead<T extends StateStreamableSource<Object?>>(BuildContext context) {
    try {
      return context.read<T>();
    } catch (_) {
      return null;
    }
  }

  void _resetUserBoundBlocs(BuildContext context) {
    final homeBloc = _maybeRead<HomeBloc>(context);
    if (homeBloc != null &&
        (homeBloc.state.status != HomeStatus.initial ||
            homeBloc.state.dashboard != null ||
            homeBloc.state.activeQrToken != null)) {
      homeBloc.add(const HomeSessionReset());
    }

    final approvalBloc = _maybeRead<AccountApprovalBloc>(context);
    if (approvalBloc != null && approvalBloc.state is! AccountApprovalInitial) {
      approvalBloc.add(const AccountApprovalReset());
    }

    final notifBloc = _maybeRead<NotificationBloc>(context);
    if (notifBloc != null &&
        (notifBloc.state.activeUserId != null ||
            notifBloc.state.status != NotificationStatus.initial)) {
      notifBloc.add(const NotificationsStopped());
    }

    final adBloc = _maybeRead<AdvertisementBloc>(context);
    if (adBloc != null &&
        (adBloc.state.activeUserId != null ||
            adBloc.state.status != AdvertisementStatus.initial)) {
      adBloc.add(const AdvertisementSessionEnded());
    }
  }

  void _syncSessionBoundBlocs(
    BuildContext context,
    AuthenticationState authState,
  ) {
    final notifBloc = _maybeRead<NotificationBloc>(context);

    if (authState is AuthenticationSuccess && authState.profile.isApproved) {
      final nextUserId = authState.profile.id;
      if (_activeApprovedUserId != null &&
          _activeApprovedUserId != nextUserId) {
        _resetUserBoundBlocs(context);
      }
      _activeApprovedUserId = nextUserId;
      notifBloc?.add(NotificationsStarted(nextUserId));
      return;
    }

    if (authState is Unauthenticated ||
        authState is PendingApproval ||
        authState is AccountRejected ||
        authState is AccountSuspended ||
        authState is PasswordResetSuccess ||
        authState is OtpVerificationRequired) {
      _activeApprovedUserId = null;
      _resetUserBoundBlocs(context);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncSessionBoundBlocs(context, widget.authBloc.state);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthenticationBloc, AuthenticationState>(
      listener: _syncSessionBoundBlocs,
      child: widget.child,
    );
  }
}
