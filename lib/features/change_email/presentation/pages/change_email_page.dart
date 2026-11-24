import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/constants/app_spacing.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/extensions/context_extensions.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';
import 'package:shiftex/core/widgets/shiiftex_primary_button.dart';
import 'package:shiftex/core/widgets/shiiftex_text_field.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';
import 'package:shiftex/features/change_email/presentation/bloc/change_email_bloc.dart';
import 'package:shiftex/features/change_email/presentation/bloc/change_email_event.dart';
import 'package:shiftex/features/change_email/presentation/bloc/change_email_state.dart';
import 'package:shiftex/features/home/presentation/bloc/home_bloc.dart';
import 'package:shiftex/features/home/presentation/bloc/home_event.dart';
import 'package:shiftex/injection_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Allows the authenticated SHIIFTEX customer to update their registered email
/// address on their existing Supabase Auth account while preserving their UUID,
/// wallet points, transactions, and profile data.
class ChangeEmailPage extends StatefulWidget {
  final ChangeEmailBloc? bloc;
  final String? initialCurrentEmail;
  final VoidCallback? onForgotPassword;

  const ChangeEmailPage({
    super.key,
    this.bloc,
    this.initialCurrentEmail,
    this.onForgotPassword,
  });

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _confirmEmailController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  final FocusNode _newEmailFocusNode = FocusNode();
  final FocusNode _confirmEmailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();

  late final ChangeEmailBloc _bloc;
  bool _ownsBloc = false;
  int _lastNotifiedPendingSequence = 0;

  @override
  void initState() {
    super.initState();
    _bloc = _resolveBloc();
    final initialEmail = _resolveAuthenticatedEmail();
    if (initialEmail.isNotEmpty) {
      _bloc.add(InitializeChangeEmail(initialEmail));
    }
  }

  ChangeEmailBloc _resolveBloc() {
    if (widget.bloc != null) {
      _ownsBloc = false;
      return widget.bloc!;
    }
    try {
      final existing = context.read<ChangeEmailBloc>();
      _ownsBloc = false;
      return existing;
    } catch (_) {
      _ownsBloc = true;
      return getIt<ChangeEmailBloc>();
    }
  }

  @override
  void dispose() {
    _newEmailController.clear();
    _confirmEmailController.clear();
    _currentPasswordController.clear();
    _otpController.clear();
    _newEmailController.dispose();
    _confirmEmailController.dispose();
    _currentPasswordController.dispose();
    _otpController.dispose();
    _newEmailFocusNode.dispose();
    _confirmEmailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _otpFocusNode.dispose();
    if (_ownsBloc) {
      _bloc.close();
    }
    super.dispose();
  }

  String _resolveAuthenticatedEmail() {
    if (widget.initialCurrentEmail != null &&
        widget.initialCurrentEmail!.trim().isNotEmpty) {
      return widget.initialCurrentEmail!.trim();
    }
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

  User? _resolveActiveSupabaseUser() {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
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
    _bloc.add(const SubmitChangeEmail());
  }

  void _onForgotPassword() {
    FocusScope.of(context).unfocus();
    if (widget.onForgotPassword != null) {
      widget.onForgotPassword!();
      return;
    }

    final email =
        _bloc.state.form.currentEmail.isNotEmpty
            ? _bloc.state.form.currentEmail
            : _resolveAuthenticatedEmail();
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

  void _refreshGlobalAuthAndHome() {
    try {
      context.read<AuthenticationBloc>().add(const AuthSessionChanged());
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[ChangeEmailPage] AuthenticationBloc not in context: ${error.runtimeType}',
        );
      }
    }
    try {
      context.read<HomeBloc>().add(const HomeDashboardRefreshRequested());
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[ChangeEmailPage] HomeBloc not in context: ${error.runtimeType}',
        );
      }
    }
  }

  AuthenticationBloc? _maybeReadAuthBloc(BuildContext context) {
    try {
      return context.read<AuthenticationBloc>();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final authBloc = _maybeReadAuthBloc(context);

    final content = BlocConsumer<ChangeEmailBloc, ChangeEmailState>(
      bloc: _bloc,
      listener: (context, state) {
        if (state is ChangeEmailPendingVerification) {
          _currentPasswordController.clear();
          if (_otpController.text != state.form.otpCode) {
            _otpController.value = TextEditingValue(
              text: state.form.otpCode,
              selection: TextSelection.collapsed(
                offset: state.form.otpCode.length,
              ),
            );
          }
          if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
            context.showFeedbackSnackBar(state.errorMessage!);
          } else if (state.notificationSequence !=
              _lastNotifiedPendingSequence) {
            _lastNotifiedPendingSequence = state.notificationSequence;
            context.showFeedbackSnackBar(
              state.infoMessage,
              isError: false,
            );
          }
        } else if (state is ChangeEmailSuccess) {
          _lastNotifiedPendingSequence = 0;
          _newEmailController.clear();
          _confirmEmailController.clear();
          _currentPasswordController.clear();
          _otpController.clear();
          context.showFeedbackSnackBar(
            state.message,
            isError: false,
          );
          _refreshGlobalAuthAndHome();
        } else if (state is ChangeEmailFailure) {
          context.showFeedbackSnackBar(state.message);
        } else {
          _lastNotifiedPendingSequence = 0;
        }
      },
      builder: (context, state) {
        final isLoading = state is ChangeEmailLoading;
        final isPending = state is ChangeEmailPendingVerification;
        final isSuccess = state is ChangeEmailSuccess;
        final form = state.form;
        final displayedCurrentEmail =
            form.currentEmail.isNotEmpty
                ? form.currentEmail
                : _resolveAuthenticatedEmail();

        final activeSupabaseUser = _resolveActiveSupabaseUser();
        final serverPendingEmail =
            (activeSupabaseUser?.newEmail ?? '').trim().toLowerCase();

        return PopScope(
          canPop: !isLoading,
          child: Scaffold(
            backgroundColor: AppColors.white,
            appBar: AppBar(
              backgroundColor: AppColors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading:
                  isSuccess
                      ? null
                      : IconButton(
                        tooltip: 'Back',
                        onPressed:
                            isLoading
                                ? null
                                : () {
                                  if (isPending) {
                                    _otpController.clear();
                                    _bloc.add(
                                      const EditPendingNewEmailRequested(),
                                    );
                                    return;
                                  }
                                  _navigateBack();
                                },
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
              automaticallyImplyLeading: false,
              centerTitle: false,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isPending ? 'Verify Email OTP' : 'Change Email',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    isPending
                        ? 'Enter 6-digit verification code'
                        : 'Update your registered email',
                    style: const TextStyle(
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
                child:
                    isSuccess
                        ? _ChangeEmailSuccessView(
                          key: const ValueKey('change_email_success_view'),
                          confirmedEmail: state.confirmedEmail,
                          message: state.message,
                          onDone: _navigateBack,
                        )
                        : isPending
                        ? _ChangeEmailPendingVerificationView(
                          key: const ValueKey('change_email_pending_view'),
                          state: state,
                          otpController: _otpController,
                          otpFocusNode: _otpFocusNode,
                          responsive: responsive,
                          onOtpChanged:
                              (val) => _bloc.add(EmailChangeOtpChanged(val)),
                          onSelectTarget: (verifyCurrent) {
                            _otpController.clear();
                            _bloc.add(
                              SelectEmailChangeOtpTarget(
                                verifyCurrentEmail: verifyCurrent,
                              ),
                            );
                          },
                          onVerifyOtp: () {
                            FocusScope.of(context).unfocus();
                            _bloc.add(const VerifyChangeEmailOtpRequested());
                          },
                          onCheckStatus: () {
                            FocusScope.of(context).unfocus();
                            _bloc.add(const CheckChangeEmailStatusRequested());
                          },
                          onResend: () {
                            FocusScope.of(context).unfocus();
                            _bloc.add(
                              const ResendChangeEmailVerificationRequested(),
                            );
                          },
                          onEditEmail: () {
                            _otpController.clear();
                            _bloc.add(const EditPendingNewEmailRequested());
                          },
                        )
                        : Center(
                          key: const ValueKey('change_email_form_view'),
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
                                  _EmailSecurityHeaderCard(
                                    compact:
                                        responsive.isShortScreen ||
                                        responsive.isSmallWidth,
                                  ),
                                  if (serverPendingEmail.isNotEmpty &&
                                      serverPendingEmail !=
                                          displayedCurrentEmail
                                              .toLowerCase()) ...[
                                    const SizedBox(height: 14),
                                    _ResumePendingEmailBanner(
                                      pendingEmail: serverPendingEmail,
                                      onResumeTap: () {
                                        _bloc.add(
                                          ResumePendingEmailChange(
                                            userId:
                                                activeSupabaseUser?.id ?? '',
                                            currentEmail: displayedCurrentEmail,
                                            targetEmail: serverPendingEmail,
                                            emailChangeSentAt:
                                                activeSupabaseUser
                                                    ?.emailChangeSentAt,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                  if (state is ChangeEmailFailure) ...[
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
                                  const _FieldLabel('Current Registered Email'),
                                  const SizedBox(height: 8),
                                  _ReadOnlyCurrentEmailCard(
                                    key: const ValueKey(
                                      'change_email_current_email_card',
                                    ),
                                    email:
                                        displayedCurrentEmail.isEmpty
                                            ? 'Not available'
                                            : displayedCurrentEmail,
                                  ),
                                  SizedBox(
                                    height: responsive.scaleVertical(16),
                                  ),
                                  const _FieldLabel('New Email Address'),
                                  const SizedBox(height: 8),
                                  ShiiftexTextField(
                                    key: const ValueKey(
                                      'change_email_new_field',
                                    ),
                                    controller: _newEmailController,
                                    focusNode: _newEmailFocusNode,
                                    hintText: 'Enter new email address',
                                    prefixIcon: Icons.mail_outline_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    enabled: !isLoading,
                                    textInputAction: TextInputAction.next,
                                    onChanged:
                                        (value) =>
                                            _bloc.add(NewEmailChanged(value)),
                                    onFieldSubmitted:
                                        (_) => FocusScope.of(
                                          context,
                                        ).requestFocus(_confirmEmailFocusNode),
                                  ),
                                  if (form.newEmailError != null) ...[
                                    const SizedBox(height: 6),
                                    _InlineValidationText(
                                      text: form.newEmailError!,
                                    ),
                                  ],
                                  SizedBox(
                                    height: responsive.scaleVertical(16),
                                  ),
                                  const _FieldLabel(
                                    'Confirm New Email Address',
                                  ),
                                  const SizedBox(height: 8),
                                  ShiiftexTextField(
                                    key: const ValueKey(
                                      'change_email_confirm_field',
                                    ),
                                    controller: _confirmEmailController,
                                    focusNode: _confirmEmailFocusNode,
                                    hintText: 'Re-enter new email address',
                                    prefixIcon: Icons.mark_email_read_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    enabled: !isLoading,
                                    textInputAction: TextInputAction.next,
                                    onChanged:
                                        (value) => _bloc.add(
                                          ConfirmNewEmailChanged(value),
                                        ),
                                    onFieldSubmitted:
                                        (_) => FocusScope.of(
                                          context,
                                        ).requestFocus(_passwordFocusNode),
                                  ),
                                  if (form.confirmEmailError != null) ...[
                                    const SizedBox(height: 6),
                                    _InlineValidationText(
                                      text: form.confirmEmailError!,
                                    ),
                                  ] else if (form.emailsMatch) ...[
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
                                              'Email addresses match',
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
                                    height: responsive.scaleVertical(16),
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
                                          'change_email_forgot_password_button',
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
                                              color:
                                                  isLoading
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
                                      'change_email_password_field',
                                    ),
                                    controller: _currentPasswordController,
                                    focusNode: _passwordFocusNode,
                                    hintText:
                                        'Enter current password to verify',
                                    prefixIcon: Icons.lock_outline_rounded,
                                    obscureText: form.obscureCurrentPassword,
                                    enabled: !isLoading,
                                    textInputAction: TextInputAction.done,
                                    onChanged:
                                        (value) => _bloc.add(
                                          CurrentPasswordForEmailChanged(value),
                                        ),
                                    onFieldSubmitted: (_) {
                                      if (form.isValid && !isLoading) {
                                        _onSubmit();
                                      }
                                    },
                                    suffixIcon: IconButton(
                                      key: const ValueKey(
                                        'change_email_password_visibility_toggle',
                                      ),
                                      tooltip:
                                          form.obscureCurrentPassword
                                              ? 'Show current password'
                                              : 'Hide current password',
                                      onPressed:
                                          () => _bloc.add(
                                            const ToggleChangeEmailPasswordVisibility(),
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
                                  const SizedBox(height: 16),
                                  const _VerificationInstructionsCard(),
                                  SizedBox(
                                    height: responsive.scaleVertical(22),
                                  ),
                                  ShiiftexPrimaryButton(
                                    key: const ValueKey(
                                      'change_email_submit_button',
                                    ),
                                    label: 'Change Email',
                                    leadingIcon: Icons.mark_email_read_outlined,
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
    );

    return BlocProvider<ChangeEmailBloc>.value(
      value: _bloc,
      child:
          authBloc == null
              ? content
              : BlocListener<AuthenticationBloc, AuthenticationState>(
                listener: (context, authState) {
                  if (authState is AuthenticationSuccess) {
                    final blocState = _bloc.state;
                    if (blocState is ChangeEmailPendingVerification) {
                      final target =
                          blocState.result.targetEmail.trim().toLowerCase();
                      if (authState.profile.email.trim().toLowerCase() ==
                          target) {
                        _bloc.add(
                          MarkChangeEmailConfirmedExternally(
                            confirmedEmail: authState.profile.email.trim(),
                            userId: authState.profile.id,
                          ),
                        );
                      }
                    } else if (blocState.form.currentEmail.isEmpty) {
                      _bloc.add(InitializeChangeEmail(authState.profile.email));
                    }
                  }
                },
                child: content,
              ),
    );
  }
}

class _ResumePendingEmailBanner extends StatelessWidget {
  final String pendingEmail;
  final VoidCallback onResumeTap;

  const _ResumePendingEmailBanner({
    required this.pendingEmail,
    required this.onResumeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.approvedBadgeBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.approvedBadgeText.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.mark_email_unread_rounded,
                size: 18,
                color: AppColors.approvedBadgeText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pending Email Change: $pendingEmail',
                  style: const TextStyle(
                    fontSize: 13.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.approvedBadgeText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Already received a 6-digit verification code? Tap below to enter your OTP without requesting another email.',
            style: TextStyle(
              fontSize: 12.2,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('change_email_resume_pending_button'),
              onPressed: onResumeTap,
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.white,
                side: const BorderSide(color: AppColors.approvedBadgeText),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                Icons.pin_outlined,
                size: 17,
                color: AppColors.approvedBadgeText,
              ),
              label: const Text(
                'Enter 6-Digit OTP Code',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.approvedBadgeText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailSecurityHeaderCard extends StatelessWidget {
  final bool compact;

  const _EmailSecurityHeaderCard({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF3F8FF), Color(0xFFEAF2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: const Color(0xFFD6E6FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 44 : 50,
            height: compact ? 44 : 50,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x141D63ED),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.alternate_email_rounded,
              color: AppColors.primaryBlue,
              size: compact ? 22 : 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update Registered Email',
                  style: TextStyle(
                    fontSize: compact ? 16 : 17.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your existing account ID, rewards balance, and transaction history stay preserved.',
                  style: TextStyle(
                    fontSize: compact ? 12.5 : 13.2,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyCurrentEmailCard extends StatelessWidget {
  final String email;

  const _ReadOnlyCurrentEmailCard({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              email,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.approvedBadgeBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Current',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.approvedBadgeText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationInstructionsCard extends StatelessWidget {
  const _VerificationInstructionsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 17,
                color: AppColors.primaryBlue,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'How Email Verification Works',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '• We will send a 6-digit verification code to your new email address (and to your current email if Secure Email Change is enabled).\n'
            '• Your current email address remains active until the new email is confirmed.\n'
            '• Your existing account ID, points, streaks, and transactions are never reset or duplicated.',
            style: TextStyle(
              fontSize: 12.3,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeEmailPendingVerificationView extends StatefulWidget {
  final ChangeEmailPendingVerification state;
  final TextEditingController otpController;
  final FocusNode otpFocusNode;
  final ResponsiveLayout responsive;
  final ValueChanged<String> onOtpChanged;
  final ValueChanged<bool> onSelectTarget;
  final VoidCallback onVerifyOtp;
  final VoidCallback onCheckStatus;
  final VoidCallback onResend;
  final VoidCallback onEditEmail;

  const _ChangeEmailPendingVerificationView({
    super.key,
    required this.state,
    required this.otpController,
    required this.otpFocusNode,
    required this.responsive,
    required this.onOtpChanged,
    required this.onSelectTarget,
    required this.onVerifyOtp,
    required this.onCheckStatus,
    required this.onResend,
    required this.onEditEmail,
  });

  @override
  State<_ChangeEmailPendingVerificationView> createState() =>
      _ChangeEmailPendingVerificationViewState();
}

class _ChangeEmailPendingVerificationViewState
    extends State<_ChangeEmailPendingVerificationView> {
  int _remainingSeconds = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown(60);
  }

  @override
  void didUpdateWidget(covariant _ChangeEmailPendingVerificationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.notificationSequence !=
            oldWidget.state.notificationSequence &&
        !widget.state.isVerifyingOtp) {
      _startCountdown(60);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown([int seconds = 60]) {
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

  Future<void> _pasteOtpFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final digits = (data?.text ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isNotEmpty) {
      final clipped = digits.length > 6 ? digits.substring(0, 6) : digits;
      widget.otpController.value = TextEditingValue(
        text: clipped,
        selection: TextSelection.collapsed(offset: clipped.length),
      );
      widget.onOtpChanged(clipped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final responsive = widget.responsive;
    final isBusy =
        state.isVerifyingOtp || state.isCheckingStatus || state.isResending;
    final currentOtp = state.form.otpCode;
    final activeTargetEmail = state.activeOtpTargetEmail;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: responsive.maxContentWidth),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            responsive.sheetHorizontalPadding,
            responsive.isShortScreen ? 16 : 22,
            responsive.sheetHorizontalPadding,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Clear Confirmation / Pending Verification Banner
              Container(
                key: const ValueKey(
                  'change_email_pending_confirmation_banner',
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.approvedBadgeBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.approvedBadgeText.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: AppColors.approvedBadgeText,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.result.newEmailVerified ||
                                    state.result.currentEmailVerified
                                ? 'Step 1 of 2 Verified — Enter Second Code'
                                : 'Verification Code Sent',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.approvedBadgeText,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            state.infoMessage,
                            style: const TextStyle(
                              fontSize: 12.6,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Pending Verification Card & Secure Email Change Inbox Selector
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F8FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD6E6FF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.mark_email_unread_outlined,
                            color: AppColors.primaryBlue,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Verify Your New Email',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.suspendedBadgeBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Pending Confirmation',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.suspendedBadgeText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            key: const ValueKey(
                              'change_email_target_new_email_pill',
                            ),
                            borderRadius: BorderRadius.circular(10),
                            onTap:
                                isBusy
                                    ? null
                                    : () => widget.onSelectTarget(false),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    state.result.newEmailVerified
                                        ? Icons.check_circle_rounded
                                        : (!state.verifyCurrentEmail
                                            ? Icons.radio_button_checked_rounded
                                            : Icons.radio_button_off_rounded),
                                    size: 17,
                                    color:
                                        state.result.newEmailVerified
                                            ? AppColors.approvedBadgeText
                                            : AppColors.primaryBlue,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Pending new email: ${state.result.targetEmail}',
                                      style: const TextStyle(
                                        fontSize: 12.8,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  if (state.result.newEmailVerified)
                                    const Text(
                                      'Verified ✓',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.approvedBadgeText,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 12, color: AppColors.divider),
                          InkWell(
                            key: const ValueKey(
                              'change_email_target_current_email_pill',
                            ),
                            borderRadius: BorderRadius.circular(10),
                            onTap:
                                isBusy
                                    ? null
                                    : () => widget.onSelectTarget(true),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    state.result.currentEmailVerified
                                        ? Icons.check_circle_rounded
                                        : (state.verifyCurrentEmail
                                            ? Icons.radio_button_checked_rounded
                                            : Icons.radio_button_off_rounded),
                                    size: 17,
                                    color:
                                        state.result.currentEmailVerified
                                            ? AppColors.approvedBadgeText
                                            : (state.verifyCurrentEmail
                                                ? AppColors.primaryBlue
                                                : AppColors.textSecondary),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Active email: ${state.result.currentEmail}',
                                      style: TextStyle(
                                        fontSize: 12.3,
                                        fontWeight:
                                            state.verifyCurrentEmail
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                        color:
                                            state.verifyCurrentEmail
                                                ? AppColors.primaryBlue
                                                : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (state.result.currentEmailVerified)
                                    const Text(
                                      'Verified ✓',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.approvedBadgeText,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (state.errorMessage != null) ...[
                const SizedBox(height: 14),
                _FailureBanner(message: state.errorMessage!),
              ],

              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: _FieldLabel(
                      'Enter 6-Digit Verification Code',
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('change_email_paste_otp_button'),
                    onPressed: isBusy ? null : _pasteOtpFromClipboard,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.content_paste_rounded, size: 15),
                    label: const Text(
                      'Paste Code',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Verifying code for: $activeTargetEmail',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 3. 6-Digit Visual OTP Boxes + Accessible Numeric Input
              _SixDigitOtpBoxesDisplay(
                code: currentOtp,
                hasError: state.errorMessage != null,
                onTap: () {
                  if (!isBusy) {
                    widget.otpFocusNode.requestFocus();
                  }
                },
                onLongPress: isBusy ? null : _pasteOtpFromClipboard,
              ),
              const SizedBox(height: 10),
              ShiiftexTextField(
                key: const ValueKey('change_email_otp_field'),
                controller: widget.otpController,
                focusNode: widget.otpFocusNode,
                hintText: 'Type or paste 6-digit OTP code',
                prefixIcon: Icons.pin_outlined,
                keyboardType: TextInputType.number,
                enabled: !isBusy,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: widget.onOtpChanged,
                onFieldSubmitted: (_) {
                  if (!isBusy) widget.onVerifyOtp();
                },
              ),

              const SizedBox(height: 14),
              ShiiftexPrimaryButton(
                key: const ValueKey('change_email_verify_otp_button'),
                label: 'Verify Code & Update Email',
                leadingIcon: Icons.verified_outlined,
                showTrailingArrow: false,
                isLoading: state.isVerifyingOtp,
                onPressed: isBusy ? null : widget.onVerifyOtp,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('change_email_refresh_status_button'),
                onPressed: isBusy ? null : widget.onCheckStatus,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: AppColors.primaryBlue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon:
                    state.isCheckingStatus
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(
                          Icons.refresh_rounded,
                          size: 18,
                          color: AppColors.primaryBlue,
                        ),
                label: const Text(
                  "I've Confirmed via Email Link (Refresh Status)",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: TextButton.icon(
                      key: const ValueKey('change_email_resend_button'),
                      onPressed: isBusy ? null : widget.onResend,
                      icon: const Icon(Icons.send_outlined, size: 16),
                      label: Text(
                        state.isResending
                            ? 'Sending...'
                            : (_remainingSeconds > 0
                                ? 'Resend Code ($_formattedTimer)'
                                : 'Resend Verification'),
                        style: const TextStyle(
                          fontSize: 12.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: TextButton.icon(
                      key: const ValueKey('change_email_edit_email_button'),
                      onPressed: isBusy ? null : widget.onEditEmail,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text(
                        'Edit Email',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SixDigitOtpBoxesDisplay extends StatelessWidget {
  final String code;
  final bool hasError;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SixDigitOtpBoxesDisplay({
    required this.code,
    required this.hasError,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final activeIndex = code.length < 6 ? code.length : 5;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
          final spacing =
              availableWidth < 310 ? 5.0 : (availableWidth < 350 ? 7.0 : 9.0);
          final rawBoxWidth = (availableWidth - (spacing * 5)) / 6;
          final boxWidth = math.min(50.0, math.max(28.0, rawBoxWidth));
          final boxHeight = (boxWidth * 1.16).clamp(42.0, 58.0);
          final digitFontSize = boxWidth < 38 ? 17.0 : 20.0;

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              final hasChar = index < code.length;
              final char = hasChar ? code[index] : '';
              final isCurrentBox = index == activeIndex && code.length < 6;

              return Padding(
                padding: EdgeInsets.only(right: index == 5 ? 0 : spacing),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: boxWidth,
                  height: boxHeight,
                  decoration: BoxDecoration(
                    color:
                        isCurrentBox
                            ? AppColors.white
                            : const Color(0xFFF3F8FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          hasError
                              ? AppColors.errorRed
                              : (isCurrentBox
                                  ? AppColors.primaryBlue
                                  : (hasChar
                                      ? AppColors.primaryBlue.withValues(
                                        alpha: 0.45,
                                      )
                                      : const Color(0xFFD6E6FF))),
                      width: isCurrentBox || hasError ? 1.8 : 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child:
                      hasChar
                          ? Text(
                            char,
                            style: TextStyle(
                              fontSize: digitFontSize,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          )
                          : Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color:
                                  isCurrentBox
                                      ? AppColors.primaryBlue
                                      : const Color(0xFF94A3B8),
                              shape: BoxShape.circle,
                            ),
                          ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _ChangeEmailSuccessView extends StatelessWidget {
  final String confirmedEmail;
  final String message;
  final VoidCallback onDone;

  const _ChangeEmailSuccessView({
    super.key,
    required this.confirmedEmail,
    required this.message,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: AppColors.approvedBadgeBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  size: 44,
                  color: AppColors.approvedBadgeText,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Email Updated Successfully',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14.2,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F8FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD6E6FF)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Active email: $confirmedEmail • Account & rewards preserved.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              ShiiftexPrimaryButton(
                key: const ValueKey('change_email_done_button'),
                label: 'Done',
                showTrailingArrow: false,
                onPressed: onDone,
              ),
            ],
          ),
        ),
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
                      'change_email_failure_forgot_password_button',
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
