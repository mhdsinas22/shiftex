import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/constants/app_strings.dart';
import 'package:shiftex/core/extensions/context_extensions.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';
import 'package:shiftex/core/utils/validators.dart';
import 'package:shiftex/core/widgets/shiiftex_auth_scaffold.dart';
import 'package:shiftex/core/widgets/shiiftex_info_bottom_sheet.dart';
import 'package:shiftex/core/widgets/shiiftex_numeric_keypad.dart';
import 'package:shiftex/core/widgets/shiiftex_otp_input.dart';
import 'package:shiftex/core/widgets/shiiftex_primary_button.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';

class VerifyEmailOtpPage extends StatefulWidget {
  final String email;

  const VerifyEmailOtpPage({
    super.key,
    required this.email,
  });

  @override
  State<VerifyEmailOtpPage> createState() => _VerifyEmailOtpPageState();
}

class _VerifyEmailOtpPageState extends State<VerifyEmailOtpPage> {
  String _otpCode = '';
  int _remainingSeconds = 43;
  Timer? _countdownTimer;
  bool _hasOtpError = false;

  @override
  void initState() {
    super.initState();
    _startCountdown(43);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown([int seconds = 45]) {
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
    if (state is OtpVerificationRequired) return state.email;
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

  void _onVerifyPressed(String email) {
    final error = Validators.validateOtp(_otpCode);
    if (error != null) {
      setState(() => _hasOtpError = true);
      context.showFeedbackSnackBar(error);
      return;
    }

    if (email.isEmpty) {
      context.showFeedbackSnackBar(
        'Email address is missing. Please register again.',
      );
      return;
    }

    context.read<AuthenticationBloc>().add(
      VerifyEmailOtpRequested(
        email: email,
        otpCode: _otpCode,
      ),
    );
  }

  void _onResendPressed(String email) {
    if (_remainingSeconds > 0 || email.isEmpty) return;
    context.read<AuthenticationBloc>().add(
      ResendEmailOtpRequested(email: email),
    );
  }

  void _showHelpSheet() {
    ShiiftexInfoBottomSheet.show(
      context,
      title: 'Email Verification Help',
      message:
          'Please check your inbox and spam folder for the 6-digit verification code sent by Shiiftex. You can also tap the bottom-left key or long-press the code boxes to paste your code.',
      buttonLabel: 'Got it',
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final vGap = responsive.scaleVertical(16);

    return BlocConsumer<AuthenticationBloc, AuthenticationState>(
      listener: (context, state) {
        if (state is AuthenticationFailure) {
          setState(() => _hasOtpError = true);
          context.showFeedbackSnackBar(state.failure.message);
        } else if (state is OtpVerificationRequired && state.otpResent) {
          setState(() {
            _otpCode = '';
            _hasOtpError = false;
          });
          _startCountdown(43);
          if (state.infoMessage != null) {
            context.showFeedbackSnackBar(
              state.infoMessage!,
              isError: false,
            );
          }
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
        final email = _resolveEmail(state);

        return ShiiftexAuthScaffold(
          lightTopGlow: false,
          topBar: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CircleTopIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => context.go(RoutesNames.register),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 15,
                        color: AppColors.white,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          AppStrings.secureGateway,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _CircleTopIconButton(
                icon: Icons.help_outline_rounded,
                onTap: _showHelpSheet,
              ),
            ],
          ),
          title: AppStrings.verifyProfileHeading,
          subtitle: AppStrings.verifyProfileSubtitle,
          sheetChild: Column(
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to '),
                    TextSpan(
                      text: email.isEmpty ? 'your email' : email,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.go(RoutesNames.register),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Edit email',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.edit_outlined,
                        size: 15,
                        color: AppColors.primaryBlue,
                      ),
                    ],
                  ),
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
                  onTap:
                      _remainingSeconds == 0
                          ? () => _onResendPressed(email)
                          : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        if (_remainingSeconds > 0)
                          Flexible(
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                                children: [
                                  const TextSpan(
                                    text: "Didn't receive code? Resend in  ",
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
                              "Didn't receive code? Tap to resend",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
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
              SizedBox(height: vGap),
              ShiiftexPrimaryButton(
                label: AppStrings.verifyAndContinue,
                isLoading: isLoading,
                onPressed: () => _onVerifyPressed(email),
              ),
              SizedBox(height: vGap),
              ShiiftexNumericKeypad(
                onDigitPressed: _onDigitPressed,
                onBackspacePressed: _onBackspacePressed,
                onPastePressed: _onPastePressed,
                bottomLeftVariant: KeypadBottomLeftVariant.fingerprint,
                boxedActionKeys: false,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CircleTopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleTopIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: AppColors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
