import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/core/routes/app_router.dart';
import 'package:shiftex/core/theme/app_theme.dart';
import 'package:shiftex/features/account_approval/presentation/bloc/account_approval_bloc.dart';
import 'package:shiftex/features/advertisements/presentation/bloc/advertisement_bloc.dart';
import 'package:shiftex/features/advertisements/presentation/widgets/advertisement_overlay_host.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';
import 'package:shiftex/features/home/presentation/bloc/home_bloc.dart';
import 'package:shiftex/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:shiftex/features/notifications/presentation/bloc/notification_event.dart';
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

  void _syncNotificationSession(AuthenticationState authState) {
    final notifBloc = _resolveNotificationBloc();
    if (notifBloc == null) return;

    if (authState is AuthenticationSuccess && authState.profile.isApproved) {
      notifBloc.add(NotificationsStarted(authState.profile.id));
    } else if (authState is Unauthenticated ||
        authState is PendingApproval ||
        authState is AccountRejected ||
        authState is AccountSuspended) {
      if (notifBloc.state.activeUserId != null) {
        notifBloc.add(const NotificationsStopped());
      }
    }
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncNotificationSession(_authBloc.state);
      }
    });
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
      child: BlocListener<AuthenticationBloc, AuthenticationState>(
        listener: (context, authState) => _syncNotificationSession(authState),
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
