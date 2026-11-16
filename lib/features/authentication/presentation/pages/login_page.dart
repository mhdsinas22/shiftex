import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/constants/app_strings.dart';
import 'package:shiftex/core/extensions/context_extensions.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/core/services/secure_storage_service.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';
import 'package:shiftex/core/utils/validators.dart';
import 'package:shiftex/core/widgets/registration_bonus_banner.dart';
import 'package:shiftex/core/widgets/shiiftex_auth_scaffold.dart';
import 'package:shiftex/core/widgets/shiiftex_logo_badge.dart';
import 'package:shiftex/core/widgets/shiiftex_primary_button.dart';
import 'package:shiftex/core/widgets/shiiftex_text_field.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';
import 'package:shiftex/injection_container.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _submittedOnce = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    if (!getIt.isRegistered<SecureStorageService>()) return;
    final storage = getIt<SecureStorageService>();
    final remember = await storage.getRememberMe();
    final identifier = await storage.getRememberedIdentifier();
    if (!mounted) return;
    setState(() {
      _rememberMe = remember;
      if (identifier != null && identifier.isNotEmpty) {
        _identifierController.text = identifier;
      }
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSignIn() {
    setState(() => _submittedOnce = true);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    context.read<AuthenticationBloc>().add(
      LoginRequested(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
        rememberMe: _rememberMe,
      ),
    );
  }

  void _onForgotPassword() {
    final text = _identifierController.text.trim();
    final emailParam = text.contains('@') ? text : null;
    if (emailParam != null && emailParam.isNotEmpty) {
      context.go(
        Uri(
          path: RoutesNames.forgotPassword,
          queryParameters: {'email': emailParam},
        ).toString(),
      );
    } else {
      context.go(RoutesNames.forgotPassword);
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final vGap = responsive.scaleVertical(18);
    final autovalidate = _submittedOnce
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled;

    return BlocConsumer<AuthenticationBloc, AuthenticationState>(
      listener: (context, state) {
        if (state is AuthenticationFailure) {
          context.showFeedbackSnackBar(state.failure.message);
        } else if (state is OtpVerificationRequired) {
          if (state.infoMessage != null) {
            context.showFeedbackSnackBar(state.infoMessage!);
          }
          context.go(
            Uri(
              path: RoutesNames.verifyEmail,
              queryParameters: {'email': state.email},
            ).toString(),
          );
        } else if (state is PendingApproval ||
            state is AccountRejected ||
            state is AccountSuspended) {
          context.go(RoutesNames.pendingApproval);
        } else if (state is AuthenticationSuccess) {
          context.go(RoutesNames.home);
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthenticationLoading;

        return ShiiftexAuthScaffold(
          headerBadge: const ShiiftexLogoBadge(
            variant: ShiiftexLogoVariant.full,
            size: 74,
          ),
          title: AppStrings.welcomeBackHeading,
          subtitle: AppStrings.welcomeBackSubtitle,
          sheetChild: Form(
            key: _formKey,
            autovalidateMode: autovalidate,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RegistrationBonusBanner(),
                SizedBox(height: vGap),
                Row(
                  children: [
                    const Expanded(
                      child: Divider(color: AppColors.divider, thickness: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Text(
                        AppStrings.orSignInWithMobileEmail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(color: AppColors.divider, thickness: 1),
                    ),
                  ],
                ),
                SizedBox(height: vGap),
                ShiiftexTextField(
                  controller: _identifierController,
                  hintText: 'Mobile number or email',
                  prefixIcon: Icons.account_circle_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: Validators.validateMobileOrEmail,
                ),
                SizedBox(height: responsive.scaleVertical(14)),
                ShiiftexTextField(
                  controller: _passwordController,
                  hintText: 'Enter your password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  validator: Validators.validateLoginPassword,
                  onFieldSubmitted: (_) => _onSignIn(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                SizedBox(height: responsive.scaleVertical(12)),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() => _rememberMe = !_rememberMe);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 28,
                              child: Switch(
                                value: _rememberMe,
                                onChanged: (val) {
                                  setState(() => _rememberMe = val);
                                },
                                activeThumbColor: AppColors.white,
                                activeTrackColor: AppColors.primaryBlue,
                                inactiveThumbColor: AppColors.white,
                                inactiveTrackColor: AppColors.dragHandle,
                                trackOutlineColor: const WidgetStatePropertyAll(
                                  Colors.transparent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              AppStrings.rememberMe,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _onForgotPassword,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Text(
                          AppStrings.forgotPasswordLink,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryBlue,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: responsive.scaleVertical(20)),
                ShiiftexPrimaryButton(
                  label: AppStrings.signIn,
                  isLoading: isLoading,
                  onPressed: _onSignIn,
                ),
                SizedBox(height: responsive.scaleVertical(22)),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => context.go(RoutesNames.register),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Text(
                          'Create an account',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
