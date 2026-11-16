import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/constants/app_strings.dart';
import 'package:shiftex/core/extensions/context_extensions.dart';
import 'package:shiftex/core/extensions/string_extensions.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';
import 'package:shiftex/core/utils/validators.dart';
import 'package:shiftex/core/widgets/shiiftex_auth_scaffold.dart';
import 'package:shiftex/core/widgets/shiiftex_info_bottom_sheet.dart';
import 'package:shiftex/core/widgets/shiiftex_logo_badge.dart';
import 'package:shiftex/core/widgets/shiiftex_primary_button.dart';
import 'package:shiftex/core/widgets/shiiftex_text_field.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';

class ForgotPasswordPage extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordPage({
    super.key,
    this.initialEmail,
  });

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isEditingEmail = false;
  bool _submittedOnce = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    _isEditingEmail = (_emailController.text.trim().isEmpty);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onSendResetCode() {
    setState(() {
      _submittedOnce = true;
      if (_emailController.text.trim().isEmpty) {
        _isEditingEmail = true;
      }
    });

    final emailError = Validators.validateEmail(_emailController.text);
    if (emailError != null) {
      setState(() => _isEditingEmail = true);
      if (!(_formKey.currentState?.validate() ?? false)) {
        context.showFeedbackSnackBar(emailError);
      }
      return;
    }

    FocusScope.of(context).unfocus();
    context.read<AuthenticationBloc>().add(
      ForgotPasswordRequested(
        email: _emailController.text.trim(),
      ),
    );
  }

  void _showSupportSheet() {
    ShiiftexInfoBottomSheet.show(
      context,
      title: 'Shiiftex Support',
      message:
          'Need help recovering your account? Reach out to our support team at support@shiiftex.com from your registered email address.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final vGap = responsive.scaleVertical(20);
    final currentEmail = _emailController.text.trim();
    final maskedDisplay =
        currentEmail.isNotEmpty && Validators.validateEmail(currentEmail) == null
            ? currentEmail.maskedEmail
            : 'j••••••••e@example.\ncom';

    return BlocConsumer<AuthenticationBloc, AuthenticationState>(
      listener: (context, state) {
        if (state is AuthenticationFailure) {
          context.showFeedbackSnackBar(state.failure.message);
        } else if (state is PasswordResetEmailSent) {
          context.showFeedbackSnackBar(
            state.message,
            isError: false,
          );
          context.go(
            Uri(
              path: RoutesNames.resetCode,
              queryParameters: {'email': state.email},
            ).toString(),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthenticationLoading;

        return ShiiftexAuthScaffold(
          topBar: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Material(
                color: Colors.white.withValues(alpha: 0.28),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.go(RoutesNames.login),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_reset_rounded,
                        size: 15,
                        color: AppColors.white,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          AppStrings.accountRecoveryBadge,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          headerBadge: const ShiiftexLogoBadge(
            variant: ShiiftexLogoVariant.markOnly,
            size: 68,
          ),
          title: AppStrings.forgotPasswordHeading,
          subtitle: AppStrings.forgotPasswordSubtitle,
          sheetChild: Form(
            key: _formKey,
            autovalidateMode:
                _submittedOnce
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    const Text(
                      AppStrings.chooseResetMethod,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 16,
                          color: AppColors.primaryBlue,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          AppStrings.instantDelivery,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Material(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      setState(() => _isEditingEmail = !_isEditingEmail);
                    },
                    child: Padding(
                      padding: EdgeInsets.all(
                        responsive.isSmallWidth ? 14 : 18,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              color: AppColors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mail_outline_rounded,
                              color: AppColors.textPrimary,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  AppStrings.sendResetLinkToEmail,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  maskedDisplay,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: AppColors.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color:
                                  currentEmail.isNotEmpty
                                      ? AppColors.primaryBlue
                                      : const Color(0xFFE4E7EC),
                              shape: BoxShape.circle,
                            ),
                            child:
                                currentEmail.isNotEmpty
                                    ? const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: AppColors.white,
                                    )
                                    : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_isEditingEmail || currentEmail.isEmpty) ...[
                  const SizedBox(height: 12),
                  ShiiftexTextField(
                    controller: _emailController,
                    hintText: 'Enter your registered email address',
                    prefixIcon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    validator: Validators.validateEmail,
                    onChanged: (_) => setState(() {}),
                    onFieldSubmitted: (_) => _onSendResetCode(),
                  ),
                ],
                SizedBox(height: vGap),
                ShiiftexPrimaryButton(
                  label: AppStrings.sendResetCode,
                  isLoading: isLoading,
                  onPressed: _onSendResetCode,
                ),
                SizedBox(height: vGap),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Remembered your password? ',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => context.go(RoutesNames.login),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Text(
                          'Log in',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: responsive.scaleVertical(14)),
                Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _showSupportSheet,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.help_outline_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Need help? Contact Shiiftex Support',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
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
