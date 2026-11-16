import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/constants/app_strings.dart';
import 'package:shiftex/core/extensions/context_extensions.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';
import 'package:shiftex/core/utils/validators.dart';
import 'package:shiftex/core/widgets/shiiftex_auth_scaffold.dart';
import 'package:shiftex/core/widgets/shiiftex_logo_badge.dart';
import 'package:shiftex/core/widgets/shiiftex_primary_button.dart';
import 'package:shiftex/core/widgets/shiiftex_text_field.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';
import 'package:shiftex/features/authentication/presentation/widgets/password_requirement_indicator.dart';

class SetNewPasswordPage extends StatefulWidget {
  const SetNewPasswordPage({super.key});

  @override
  State<SetNewPasswordPage> createState() => _SetNewPasswordPageState();
}

class _SetNewPasswordPageState extends State<SetNewPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submittedOnce = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onUpdatePassword() {
    setState(() => _submittedOnce = true);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    context.read<AuthenticationBloc>().add(
      ResetPasswordRequested(newPassword: _newPasswordController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final autovalidate =
        _submittedOnce
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled;

    return BlocConsumer<AuthenticationBloc, AuthenticationState>(
      listener: (context, state) {
        if (state is AuthenticationFailure) {
          context.showFeedbackSnackBar(state.failure.message);
        } else if (state is PasswordResetSuccess) {
          context.showFeedbackSnackBar(state.message, isError: false);
          context.go(RoutesNames.login);
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthenticationLoading;

        return ShiiftexAuthScaffold(
          footerText: AppStrings.encryptedVault256Footer,
          headerBadge: const ShiiftexLogoBadge(
            variant: ShiiftexLogoVariant.keyIcon,
            size: 68,
          ),
          title: 'Set new password',
          subtitle:
              'Create a strong password to secure your\nShiiftex rewards vault.',
          sheetChild: Form(
            key: _formKey,
            autovalidateMode: autovalidate,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                ShiiftexTextField(
                  controller: _newPasswordController,
                  hintText: 'New password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscureNew,
                  textInputAction: TextInputAction.next,
                  validator: Validators.validatePassword,
                  onChanged: (_) => setState(() {}),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _obscureNew = !_obscureNew);
                    },
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: PasswordRequirementIndicator(
                    password: _newPasswordController.text,
                  ),
                ),
                SizedBox(height: responsive.scaleVertical(14)),
                ShiiftexTextField(
                  controller: _confirmPasswordController,
                  hintText: 'Confirm new password',
                  prefixIcon: Icons.lock_reset_rounded,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  validator:
                      (val) => Validators.validateConfirmPassword(
                        val,
                        _newPasswordController.text,
                      ),
                  onFieldSubmitted: (_) => _onUpdatePassword(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _obscureConfirm = !_obscureConfirm);
                    },
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                SizedBox(height: responsive.scaleVertical(24)),
                ShiiftexPrimaryButton(
                  label: 'Update Password',
                  isLoading: isLoading,
                  onPressed: _onUpdatePassword,
                ),
                SizedBox(height: responsive.scaleVertical(16)),
                Center(
                  child: TextButton(
                    onPressed:
                        isLoading
                            ? null
                            : () {
                              context.read<AuthenticationBloc>().add(
                                const LogoutRequested(),
                              );
                              context.go(RoutesNames.login);
                            },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(120, 44),
                    ),
                    child: const Text(
                      AppStrings.backToLogin,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
