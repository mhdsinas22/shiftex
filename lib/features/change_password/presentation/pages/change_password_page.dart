import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/extensions/context_extensions.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';
import 'package:shiftex/core/widgets/shiiftex_primary_button.dart';
import 'package:shiftex/core/widgets/shiiftex_text_field.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';
import 'package:shiftex/features/change_password/presentation/bloc/change_password_bloc.dart';
import 'package:shiftex/features/change_password/presentation/bloc/change_password_event.dart';
import 'package:shiftex/features/change_password/presentation/bloc/change_password_state.dart';
import 'package:shiftex/features/change_password/presentation/widgets/change_password_success_view.dart';
import 'package:shiftex/features/change_password/presentation/widgets/password_strength_meter.dart';
import 'package:shiftex/features/change_password/presentation/widgets/security_header_card.dart';
import 'package:shiftex/injection_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Allows the authenticated SHIIFTEX customer to verify their current password
/// and update to a strong new password while preserving their active session.
class ChangePasswordPage extends StatefulWidget {
  final ChangePasswordBloc? bloc;
  final VoidCallback? onForgotPassword;

  const ChangePasswordPage({
    super.key,
    this.bloc,
    this.onForgotPassword,
  });

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final FocusNode _currentFocusNode = FocusNode();
  final FocusNode _newFocusNode = FocusNode();
  final FocusNode _confirmFocusNode = FocusNode();

  late final ChangePasswordBloc _bloc;
  bool _ownsBloc = false;

  @override
  void initState() {
    super.initState();
    _bloc = _resolveBloc();
  }

  ChangePasswordBloc _resolveBloc() {
    if (widget.bloc != null) {
      _ownsBloc = false;
      return widget.bloc!;
    }
    try {
      final existing = context.read<ChangePasswordBloc>();
      _ownsBloc = false;
      return existing;
    } catch (_) {
      _ownsBloc = true;
      return getIt<ChangePasswordBloc>();
    }
  }

  @override
  void dispose() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _currentFocusNode.dispose();
    _newFocusNode.dispose();
    _confirmFocusNode.dispose();
    if (_ownsBloc) {
      _bloc.close();
    }
    super.dispose();
  }

  void _navigateBack() {
    FocusScope.of(context).unfocus();
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

  void _onSubmit() {
    FocusScope.of(context).unfocus();
    _bloc.add(const SubmitChangePassword());
  }

  String _resolveAuthenticatedEmail() {
    try {
      final authState = context.read<AuthenticationBloc>().state;
      if (authState is AuthenticationSuccess) {
        return authState.profile.email.trim();
      }
      if (authState is AuthenticationLoading &&
          authState.currentProfile != null) {
        return authState.currentProfile!.email.trim();
      }
    } catch (_) {
      // AuthenticationBloc may be absent in isolated widget tests.
    }

    try {
      return (Supabase.instance.client.auth.currentUser?.email ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  void _onForgotPassword() {
    FocusScope.of(context).unfocus();
    if (widget.onForgotPassword != null) {
      widget.onForgotPassword!();
      return;
    }

    final email = _resolveAuthenticatedEmail();
    final targetUri = Uri(
      path: RoutesNames.forgotPassword,
      queryParameters: {
        if (email.isNotEmpty) 'email': email,
        'from': 'change-password',
      },
    );

    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push(targetUri.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);

    return BlocProvider<ChangePasswordBloc>.value(
      value: _bloc,
      child: BlocConsumer<ChangePasswordBloc, ChangePasswordState>(
        listener: (context, state) {
          if (state is ChangePasswordSuccess) {
            _currentPasswordController.clear();
            _newPasswordController.clear();
            _confirmPasswordController.clear();
          } else if (state is ChangePasswordFailure &&
              state.failure.code == 'session_expired') {
            context.showFeedbackSnackBar(state.message);
          }
        },
        builder: (context, state) {
          final isLoading = state is ChangePasswordLoading;
          final isSuccess = state is ChangePasswordSuccess;
          final form = state.form;

          return PopScope(
            canPop: !isLoading,
            child: Scaffold(
              backgroundColor: AppColors.white,
              appBar: AppBar(
                backgroundColor: AppColors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: isSuccess
                    ? null
                    : IconButton(
                        tooltip: 'Back',
                        onPressed: isLoading ? null : _navigateBack,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                automaticallyImplyLeading: false,
                centerTitle: false,
                title: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Secure your account',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(1),
                  child: Divider(height: 1, color: AppColors.divider),
                ),
              ),
              body: SafeArea(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: isSuccess
                      ? ChangePasswordSuccessView(
                          key: const ValueKey('change_password_success_view'),
                          onDone: _navigateBack,
                        )
                      : Center(
                          key: const ValueKey('change_password_form_view'),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: responsive.maxContentWidth,
                            ),
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                responsive.sheetHorizontalPadding,
                                responsive.isShortScreen ? 14 : 20,
                                responsive.sheetHorizontalPadding,
                                28,
                              ),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SecurityHeaderCard(
                                    compact: responsive.isShortScreen ||
                                        responsive.isSmallWidth,
                                  ),
                                  if (state is ChangePasswordFailure) ...[
                                    const SizedBox(height: 16),
                                    _FailureBanner(
                                      message: state.message,
                                      showForgotPasswordAction:
                                          state.failure
                                              is InvalidCredentialsFailure,
                                      onForgotPassword:
                                          isLoading ? null : _onForgotPassword,
                                    ),
                                  ],
                                  SizedBox(
                                    height: responsive.scaleVertical(20),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Flexible(
                                        child: _FieldLabel('Current Password'),
                                      ),
                                      InkWell(
                                        key: const ValueKey(
                                          'change_password_forgot_password_button',
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        onTap:
                                            isLoading
                                                ? null
                                                : _onForgotPassword,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 3,
                                          ),
                                          child: Text(
                                            'Forgot Password?',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isLoading
                                                  ? AppColors.textTertiary
                                                  : AppColors.primaryBlue,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ShiiftexTextField(
                                    key: const ValueKey(
                                      'change_password_current_field',
                                    ),
                                    controller: _currentPasswordController,
                                    focusNode: _currentFocusNode,
                                    hintText: 'Enter current password',
                                    prefixIcon: Icons.lock_outline_rounded,
                                    obscureText: form.obscureCurrentPassword,
                                    enabled: !isLoading,
                                    textInputAction: TextInputAction.next,
                                    onChanged: (value) => _bloc.add(
                                      CurrentPasswordChanged(value),
                                    ),
                                    onFieldSubmitted: (_) => FocusScope.of(
                                      context,
                                    ).requestFocus(_newFocusNode),
                                    suffixIcon: IconButton(
                                      key: const ValueKey(
                                        'current_password_visibility_toggle',
                                      ),
                                      tooltip: form.obscureCurrentPassword
                                          ? 'Show current password'
                                          : 'Hide current password',
                                      onPressed: () => _bloc.add(
                                        const ToggleCurrentPasswordVisibility(),
                                      ),
                                      icon: Icon(
                                        form.obscureCurrentPassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (form.currentPasswordError != null) ...[
                                    const SizedBox(height: 6),
                                    _InlineValidationText(
                                      text: form.currentPasswordError!,
                                    ),
                                  ],
                                  SizedBox(
                                    height: responsive.scaleVertical(16),
                                  ),
                                  const _FieldLabel('New Password'),
                                  const SizedBox(height: 8),
                                  ShiiftexTextField(
                                    key: const ValueKey(
                                      'change_password_new_field',
                                    ),
                                    controller: _newPasswordController,
                                    focusNode: _newFocusNode,
                                    hintText: 'Create a strong new password',
                                    prefixIcon: Icons.lock_reset_rounded,
                                    obscureText: form.obscureNewPassword,
                                    enabled: !isLoading,
                                    textInputAction: TextInputAction.next,
                                    onChanged: (value) =>
                                        _bloc.add(NewPasswordChanged(value)),
                                    onFieldSubmitted: (_) => FocusScope.of(
                                      context,
                                    ).requestFocus(_confirmFocusNode),
                                    suffixIcon: IconButton(
                                      key: const ValueKey(
                                        'new_password_visibility_toggle',
                                      ),
                                      tooltip: form.obscureNewPassword
                                          ? 'Show new password'
                                          : 'Hide new password',
                                      onPressed: () => _bloc.add(
                                        const ToggleNewPasswordVisibility(),
                                      ),
                                      icon: Icon(
                                        form.obscureNewPassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (form.newPasswordError != null) ...[
                                    const SizedBox(height: 6),
                                    _InlineValidationText(
                                      text: form.newPasswordError!,
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  PasswordStrengthMeter(form: form),
                                  SizedBox(
                                    height: responsive.scaleVertical(16),
                                  ),
                                  const _FieldLabel('Confirm New Password'),
                                  const SizedBox(height: 8),
                                  ShiiftexTextField(
                                    key: const ValueKey(
                                      'change_password_confirm_field',
                                    ),
                                    controller: _confirmPasswordController,
                                    focusNode: _confirmFocusNode,
                                    hintText: 'Re-enter new password',
                                    prefixIcon: Icons.verified_user_outlined,
                                    obscureText: form.obscureConfirmPassword,
                                    enabled: !isLoading,
                                    textInputAction: TextInputAction.done,
                                    onChanged: (value) => _bloc.add(
                                      ConfirmPasswordChanged(value),
                                    ),
                                    onFieldSubmitted: (_) {
                                      if (form.isValid && !isLoading) {
                                        _onSubmit();
                                      }
                                    },
                                    suffixIcon: IconButton(
                                      key: const ValueKey(
                                        'confirm_password_visibility_toggle',
                                      ),
                                      tooltip: form.obscureConfirmPassword
                                          ? 'Show confirm password'
                                          : 'Hide confirm password',
                                      onPressed: () => _bloc.add(
                                        const ToggleConfirmPasswordVisibility(),
                                      ),
                                      icon: Icon(
                                        form.obscureConfirmPassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (form.confirmPasswordError != null) ...[
                                    const SizedBox(height: 6),
                                    _InlineValidationText(
                                      text: form.confirmPasswordError!,
                                    ),
                                  ] else if (form.passwordsMatch) ...[
                                    const SizedBox(height: 6),
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 15,
                                            color: AppColors.approvedBadgeText,
                                          ),
                                          SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              'Passwords match',
                                              style: TextStyle(
                                                fontSize: 12.2,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    AppColors.approvedBadgeText,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  SizedBox(
                                    height: responsive.scaleVertical(24),
                                  ),
                                  ShiiftexPrimaryButton(
                                    key: const ValueKey(
                                      'change_password_submit_button',
                                    ),
                                    label: 'Update Password',
                                    leadingIcon: Icons.shield_outlined,
                                    showTrailingArrow: false,
                                    isLoading: isLoading,
                                    onPressed:
                                        form.isValid && !isLoading
                                            ? _onSubmit
                                            : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _InlineValidationText extends StatelessWidget {
  final String text;

  const _InlineValidationText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1.5),
            child: Icon(
              Icons.error_outline_rounded,
              size: 14,
              color: AppColors.errorRed,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.2,
                fontWeight: FontWeight.w500,
                color: AppColors.errorRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureBanner extends StatelessWidget {
  final String message;
  final bool showForgotPasswordAction;
  final VoidCallback? onForgotPassword;

  const _FailureBanner({
    required this.message,
    this.showForgotPasswordAction = false,
    this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.errorBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: AppColors.errorRed,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.rejectedBadgeText,
                    height: 1.35,
                  ),
                ),
                if (showForgotPasswordAction && onForgotPassword != null) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    key: const ValueKey(
                      'change_password_failure_forgot_password_button',
                    ),
                    borderRadius: BorderRadius.circular(6),
                    onTap: onForgotPassword,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        'Forgot your password? Reset via email ->',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
