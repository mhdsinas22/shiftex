import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/constants/app_strings.dart';
import 'package:shiftex/core/extensions/context_extensions.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';
import 'package:shiftex/core/utils/validators.dart';
import 'package:shiftex/core/widgets/password_strength_card.dart';
import 'package:shiftex/core/widgets/registration_bonus_banner.dart';
import 'package:shiftex/core/widgets/shiiftex_auth_scaffold.dart';
import 'package:shiftex/core/widgets/shiiftex_info_bottom_sheet.dart';
import 'package:shiftex/core/widgets/shiiftex_logo_badge.dart';
import 'package:shiftex/core/widgets/shiiftex_primary_button.dart';
import 'package:shiftex/core/widgets/shiiftex_text_field.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';
import 'package:shiftex/features/authentication/presentation/widgets/mobile_country_text_field.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedCountryCode = '+91';
  bool _obscurePassword = true;
  bool _submittedOnce = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    setState(() => _submittedOnce = true);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    final fullMobile =
        '$_selectedCountryCode${_mobileController.text.trim()}';

    context.read<AuthenticationBloc>().add(
      RegisterRequested(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        mobileNumber: fullMobile,
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  void _showLegalModal(String title, String content) {
    ShiiftexInfoBottomSheet.show(
      context,
      title: title,
      message: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final fieldGap = responsive.scaleVertical(12);
    final sectionGap = responsive.scaleVertical(16);
    final autovalidate =
        _submittedOnce
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled;

    return BlocConsumer<AuthenticationBloc, AuthenticationState>(
      listener: (context, state) {
        if (state is AuthenticationFailure) {
          context.showFeedbackSnackBar(state.failure.message);
        } else if (state is OtpVerificationRequired) {
          context.go(
            Uri(
              path: RoutesNames.verifyEmail,
              queryParameters: {'email': state.email},
            ).toString(),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthenticationLoading;

        return ShiiftexAuthScaffold(
          headerBadge: const ShiiftexLogoBadge(
            variant: ShiiftexLogoVariant.full,
            size: 74,
          ),
          title: AppStrings.createAccountHeading,
          subtitle: AppStrings.createAccountSubtitle,
          sheetChild: Form(
            key: _formKey,
            autovalidateMode: autovalidate,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RegistrationBonusBanner(),
                SizedBox(height: sectionGap),
                Row(
                  children: [
                    const Expanded(
                      child: Divider(
                        color: AppColors.divider,
                        thickness: 1,
                      ),
                    ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          AppStrings.orRegisterWithDetails,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(
                        color: AppColors.divider,
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: sectionGap),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 280) {
                      return Column(
                        children: [
                          ShiiftexTextField(
                            controller: _firstNameController,
                            hintText: 'First name',
                            textInputAction: TextInputAction.next,
                            validator: Validators.validateFirstName,
                          ),
                          SizedBox(height: fieldGap),
                          ShiiftexTextField(
                            controller: _lastNameController,
                            hintText: 'Last name',
                            textInputAction: TextInputAction.next,
                            validator: Validators.validateLastName,
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ShiiftexTextField(
                            controller: _firstNameController,
                            hintText: 'First name',
                            textInputAction: TextInputAction.next,
                            validator: Validators.validateFirstName,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ShiiftexTextField(
                            controller: _lastNameController,
                            hintText: 'Last name',
                            textInputAction: TextInputAction.next,
                            validator: Validators.validateLastName,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                SizedBox(height: fieldGap),
                MobileCountryTextField(
                  controller: _mobileController,
                  selectedCountryCode: _selectedCountryCode,
                  onCountryCodeChanged: (code) {
                    setState(() => _selectedCountryCode = code);
                  },
                  validator:
                      (val) => Validators.validateMobileNumber(
                        val,
                        countryCode: _selectedCountryCode,
                      ),
                ),
                SizedBox(height: fieldGap),
                ShiiftexTextField(
                  controller: _emailController,
                  hintText: 'name@example.com',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: Validators.validateEmail,
                ),
                SizedBox(height: fieldGap),
                ShiiftexTextField(
                  controller: _passwordController,
                  hintText: 'Create password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  validator: Validators.validateStrongPassword,
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => _onSubmit(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PasswordStrengthCard(password: _passwordController.text),
                SizedBox(height: sectionGap),
                ShiiftexPrimaryButton(
                  label: 'Create account',
                  isLoading: isLoading,
                  onPressed: _onSubmit,
                ),
                SizedBox(height: responsive.scaleVertical(14)),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                    children: [
                      const TextSpan(
                        text: 'By continuing, you agree to Shiiftex ',
                      ),
                      TextSpan(
                        text: 'Terms of Service',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer:
                            TapGestureRecognizer()
                              ..onTap = () {
                                _showLegalModal(
                                  'Shiiftex Terms of Service',
                                  'By creating a customer account on Shiiftex, you agree that your registration is subject to administrator review and verification before rewards vault access is activated.',
                                );
                              },
                      ),
                      const TextSpan(text: ' and\n'),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer:
                            TapGestureRecognizer()
                              ..onTap = () {
                                _showLegalModal(
                                  'Shiiftex Privacy Policy',
                                  'Your personal contact details and authentication credentials are stored securely with row-level access controls and used strictly for account verification and rewards management.',
                                );
                              },
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                SizedBox(height: responsive.scaleVertical(14)),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
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
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
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
