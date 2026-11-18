import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/core/router/app_router.dart';
import 'package:shiftex/core/theme/app_theme.dart';
import 'package:shiftex/features/account_approval/presentation/bloc/account_approval_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/home/presentation/bloc/home_bloc.dart';
import 'package:shiftex/injection_container.dart';

class Shiftexapp extends StatefulWidget {
  final AuthenticationBloc? authenticationBloc;
  final AccountApprovalBloc? accountApprovalBloc;
  final HomeBloc? homeBloc;
  final AppRouter? appRouter;

  const Shiftexapp({
    super.key,
    this.authenticationBloc,
    this.accountApprovalBloc,
    this.homeBloc,
    this.appRouter,
  });

  @override
  State<Shiftexapp> createState() => _ShiftexappState();
}

class _ShiftexappState extends State<Shiftexapp> {
  late final AuthenticationBloc _authBloc;
  late final AppRouter _router;

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
          BlocProvider<HomeBloc>(
            create: (_) => getIt<HomeBloc>(),
          ),
      ],
      child: MaterialApp.router(
        title: 'SHIIFTEX',
        theme: AppTheme.lightTheme,
        routerConfig: _router.router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
