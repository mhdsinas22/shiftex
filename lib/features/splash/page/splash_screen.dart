import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/routes/app_router.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/core/widgets/shiiftex_logo_badge.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  void _checkRedirect(BuildContext context, AuthenticationState state) {
    final target = AppRouter.evaluateAuthRedirect(
      authState: state,
      matchedLocation: RoutesNames.splash,
    );
    if (target != null && target != RoutesNames.splash && mounted) {
      context.go(target);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<AuthenticationBloc>();
      _checkRedirect(context, bloc.state);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthenticationBloc, AuthenticationState>(
      listener: _checkRedirect,
      child: Scaffold(
        backgroundColor: AppColors.gradientDeepBlue,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFEFF6FF),
                Color(0xFF4BA0FA),
                Color(0xFF0A66E2),
                Color(0xFF0051C4),
              ],
              stops: [0.0, 0.16, 0.36, 1.0],
            ),
          ),
          child: const SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShiiftexLogoBadge(
                    variant: ShiiftexLogoVariant.full,
                    size: 88,
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
