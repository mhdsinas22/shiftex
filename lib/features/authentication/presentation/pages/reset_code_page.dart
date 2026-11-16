import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:shiftex/core/widgets/shiiftex_logo_badge.dart';
import 'package:shiftex/core/widgets/shiiftex_numeric_keypad.dart';
import 'package:shiftex/core/widgets/shiiftex_otp_input.dart';
import 'package:shiftex/core/widgets/shiiftex_primary_button.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';

class ResetCodePage extends StatefulWidget {
  final String email;

  const ResetCodePage({super.key, required this.email});

  @override
  State<ResetCodePage> createState() => _ResetCodePageState();
}

class _ResetCodePageState extends State<ResetCodePage> {
  String _otpCode = '';
  int _remainingSeconds = 38;
  Timer? _countdownTimer;
  bool _hasOtpError = false;

  @override
  void initState() {
    super.initState();
    _startCountdown(38);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown([int seconds = 38]) {
    _countdownTimer?.cancel();
    setState(() => _remainingSeconds = seconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        setState(() => _remainingSeconds = 0);
        timer.cancel();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  String get _formattedTimer {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  String _resolveEmail(AuthenticationState state) {
    if (widget.email.trim().isNotEmpty) return widget.email.trim();
    if (state is PasswordResetEmailSent) return state.email;
    if (state is PasswordResetVerified) return state.email;
    if (state is AuthenticationLoading && state.activeEmail != null) {
      return state.activeEmail!;
    }
    if (state is AuthenticationFailure && state.email != null) {
      return state.email!;
    }
    return '';
  }

  void _onDigitPressed(String digit) {
    if (_otpCode.length >= 6) return;
    setState(() {
      _hasOtpError = false;
      _otpCode = '$_otpCode$digit';
    });
  }

  void _onBackspacePressed() {
    if (_otpCode.isEmpty) return;
    setState(() {
      _hasOtpError = false;
      _otpCode = _otpCode.substring(0, _otpCode.length - 1);
    });
  }

  Future<void> _onPastePressed() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final digits = (data?.text ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isNotEmpty) {
      setState(() {
        _hasOtpError = false;
        _otpCode = digits.length > 6 ? digits.substring(0, 6) : digits;
      });
    }
  }

  void _onVerifyCode(String email) {
    final error = Validators.validateOtp(_otpCode);
    if (error != null) {
      setState(() => _hasOtpError = true);
      context.showFeedbackSnackBar(error);
      return;
    }

    if (email.isEmpty) {
      context.showFeedbackSnackBar(
        'Email address is missing. Please go back and enter your email.',
      );
      return;
    }

    context.read<AuthenticationBloc>().add(
      VerifyPasswordResetOtpRequested(email: email, otpCode: _otpCode),
    );
  }

  void _onResendCode(String email) {
    if (_remainingSeconds > 0 || email.isEmpty) return;
    context.read<AuthenticationBloc>().add(
      ForgotPasswordRequested(email: email, isResend: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final vGap = responsive.scaleVertical(14);

    return BlocConsumer<AuthenticationBloc, AuthenticationState>(
      listener: (context, state) {
        if (state is AuthenticationFailure) {
          setState(() => _hasOtpError = true);
          context.showFeedbackSnackBar(state.failure.message);
        } else if (state is PasswordResetEmailSent && state.isResend) {
          setState(() {
            _otpCode = '';
            _hasOtpError = false;
          });
          _startCountdown(38);
          context.showFeedbackSnackBar(
            'A new 6-digit reset code has been sent.',
            isError: false,
          );
        } else if (state is PasswordResetVerified) {
          context.go(RoutesNames.setNewPassword);
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthenticationLoading;
        final email = _resolveEmail(state);
        final maskedEmail = email.isNotEmpty
            ? email.maskedEmail
            : 'j•••••••e@example.com';

        return ShiiftexAuthScaffold(
          footerText: AppStrings.encryptedVault256Footer,
          topBar: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Material(
                color: Colors.white.withValues(alpha: 0.75),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    context.go(
                      Uri(
                        path: RoutesNames.forgotPassword,
                        queryParameters: email.isNotEmpty
                            ? {'email': email}
                            : null,
                      ).toString(),
                    );
                  },
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
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
                          AppStrings.resetCodeBadge,
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
            variant: ShiiftexLogoVariant.keyIcon,
            size: 68,
          ),
          title: AppStrings.enterResetCodeHeading,
          subtitle: 'We sent a 6-digit code to $maskedEmail',
          sheetChild: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Code expires in 10 minutes',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: vGap),
              ShiiftexOtpInput(
                code: _otpCode,
                hasError: _hasOtpError,
                onChanged: (value) {
                  setState(() {
                    _hasOtpError = false;
                    _otpCode = value;
                  });
                },
              ),
              SizedBox(height: vGap),
              Material(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _remainingSeconds == 0
                      ? () => _onResendCode(email)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sync_rounded,
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        if (_remainingSeconds > 0)
                          Flexible(
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                children: [
                                  const TextSpan(
                                    text: "Didn't get code? Resend in ",
                                  ),
                                  TextSpan(
                                    text: _formattedTimer,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          const Flexible(
                            child: Text(
                              "Didn't get code? Tap to resend",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      context.showFeedbackSnackBar(
                        'Email OTP recovery is active for your Shiiftex account.',
                        isError: false,
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        'Try SMS instead',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: vGap),
              ShiiftexPrimaryButton(
                label: AppStrings.verifyCode,
                isLoading: isLoading,
                onPressed: () => _onVerifyCode(email),
              ),
              SizedBox(height: vGap),
              ShiiftexNumericKeypad(
                onDigitPressed: _onDigitPressed,
                onBackspacePressed: _onBackspacePressed,
                onPastePressed: _onPastePressed,
                bottomLeftVariant: KeypadBottomLeftVariant.pasteCard,
                boxedActionKeys: true,
              ),
            ],
          ),
        );
      },
    );
  }
}
