import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/constants/app_spacing.dart';
import 'package:shiftex/core/extensions/context_extensions.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';
import 'package:shiftex/core/utils/validators.dart';
import 'package:shiftex/core/widgets/shiiftex_primary_button.dart';
import 'package:shiftex/core/widgets/shiiftex_text_field.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';
import 'package:shiftex/features/change_phone/presentation/bloc/change_phone_bloc.dart';
import 'package:shiftex/features/change_phone/presentation/bloc/change_phone_event.dart';
import 'package:shiftex/features/change_phone/presentation/bloc/change_phone_state.dart';
import 'package:shiftex/features/home/presentation/bloc/home_bloc.dart';
import 'package:shiftex/features/home/presentation/bloc/home_event.dart';
import 'package:shiftex/injection_container.dart';

/// Allows the authenticated SHIIFTEX customer to directly update their
/// registered 10-digit phone number on their existing `public.profiles` record
/// without OTP, email confirmation, password verification, or logout.
class ChangePhonePage extends StatefulWidget {
  final ChangePhoneBloc? bloc;
  final String? initialCurrentPhone;

  const ChangePhonePage({
    super.key,
    this.bloc,
    this.initialCurrentPhone,
  });

  @override
  State<ChangePhonePage> createState() => _ChangePhonePageState();
}

class _ChangePhonePageState extends State<ChangePhonePage> {
  final TextEditingController _newPhoneController = TextEditingController();
  final FocusNode _newPhoneFocusNode = FocusNode();

  late final ChangePhoneBloc _bloc;
  bool _ownsBloc = false;

  @override
  void initState() {
    super.initState();
    _bloc = _resolveBloc();
    final initialPhone = _resolveAuthenticatedPhone();
    if (initialPhone.isNotEmpty) {
      _bloc.add(InitializeChangePhone(initialPhone));
    }
  }

  ChangePhoneBloc _resolveBloc() {
    if (widget.bloc != null) {
      _ownsBloc = false;
      return widget.bloc!;
    }
    try {
      final existing = context.read<ChangePhoneBloc>();
      _ownsBloc = false;
      return existing;
    } catch (_) {
      _ownsBloc = true;
      return getIt<ChangePhoneBloc>();
    }
  }

  @override
  void dispose() {
    _newPhoneController.clear();
    _newPhoneController.dispose();
    _newPhoneFocusNode.dispose();
    if (_ownsBloc) {
      _bloc.close();
    }
    super.dispose();
  }

  String _resolveAuthenticatedPhone() {
    if (widget.initialCurrentPhone != null &&
        widget.initialCurrentPhone!.trim().isNotEmpty) {
      return widget.initialCurrentPhone!.trim();
    }
    try {
      final authState = context.read<AuthenticationBloc>().state;
      if (authState is AuthenticationSuccess) {
        return authState.profile.mobileNumber.trim();
      }
      if (authState is AuthenticationLoading &&
          authState.currentProfile != null) {
        return authState.currentProfile!.mobileNumber.trim();
      }
    } catch (_) {}

    try {
      final homeDashboard = context.read<HomeBloc>().state.dashboard;
      if (homeDashboard != null &&
          homeDashboard.mobileNumber.trim().isNotEmpty) {
        return homeDashboard.mobileNumber.trim();
      }
    } catch (_) {}

    return '';
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
    _bloc.add(const SubmitChangePhone());
  }

  void _refreshGlobalAuthAndHome() {
    try {
      context.read<AuthenticationBloc>().add(const AuthSessionChanged());
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[ChangePhonePage] AuthenticationBloc not in context: ${error.runtimeType}',
        );
      }
    }
    try {
      context.read<HomeBloc>().add(const HomeDashboardRefreshRequested());
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[ChangePhonePage] HomeBloc not in context: ${error.runtimeType}',
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

    final content = BlocConsumer<ChangePhoneBloc, ChangePhoneState>(
      bloc: _bloc,
      listener: (context, state) {
        if (state is ChangePhoneSuccess) {
          _newPhoneController.clear();
          context.showFeedbackSnackBar(
            state.result.message,
            isError: false,
          );
          _refreshGlobalAuthAndHome();
        } else if (state is ChangePhoneFailure) {
          context.showFeedbackSnackBar(state.message);
        }
      },
      builder: (context, state) {
        final isLoading = state is ChangePhoneLoading;
        final isSuccess = state is ChangePhoneSuccess;
        final form = state.form;
        final rawCurrentPhone =
            form.currentPhoneNumber.isNotEmpty
                ? form.currentPhoneNumber
                : _resolveAuthenticatedPhone();
        final displayedCurrentPhone =
            Validators.extractTenDigitPhone(rawCurrentPhone).isNotEmpty
                ? Validators.extractTenDigitPhone(rawCurrentPhone)
                : rawCurrentPhone;
        final enteredLength = form.newPhoneNumber.trim().length;

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
                    'Change Phone Number',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Update your contact number',
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
                child:
                    isSuccess
                        ? _ChangePhoneSuccessView(
                          key: const ValueKey('change_phone_success_view'),
                          updatedPhone: state.result.displayPhoneNumber,
                          message: state.result.message,
                          onDone: _navigateBack,
                        )
                        : Center(
                          key: const ValueKey('change_phone_form_view'),
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
                                  _PhoneHeaderCard(
                                    compact:
                                        responsive.isShortScreen ||
                                        responsive.isSmallWidth,
                                  ),
                                  if (state is ChangePhoneFailure) ...[
                                    const SizedBox(height: 16),
                                    _PhoneFailureBanner(
                                      key: const ValueKey(
                                        'change_phone_error_banner',
                                      ),
                                      message: state.message,
                                    ),
                                  ],
                                  SizedBox(
                                    height: responsive.scaleVertical(20),
                                  ),
                                  const _PhoneFieldLabel(
                                    'Current Phone Number',
                                  ),
                                  const SizedBox(height: 8),
                                  _ReadOnlyCurrentPhoneCard(
                                    key: const ValueKey(
                                      'change_phone_current_card',
                                    ),
                                    phoneNumber:
                                        displayedCurrentPhone.isEmpty
                                            ? 'Not available'
                                            : displayedCurrentPhone,
                                  ),
                                  SizedBox(
                                    height: responsive.scaleVertical(18),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Flexible(
                                        child: _PhoneFieldLabel(
                                          'New Phone Number',
                                        ),
                                      ),
                                      Text(
                                        '$enteredLength/10 digits',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              form.isValid
                                                  ? AppColors.approvedBadgeText
                                                  : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ShiiftexTextField(
                                    key: const ValueKey(
                                      'change_phone_new_field',
                                    ),
                                    controller: _newPhoneController,
                                    focusNode: _newPhoneFocusNode,
                                    hintText: 'Enter 10-digit phone number',
                                    prefixIcon: Icons.phone_iphone_rounded,
                                    keyboardType: TextInputType.number,
                                    enabled: !isLoading,
                                    textInputAction: TextInputAction.done,
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    onChanged:
                                        (value) => _bloc.add(
                                          NewPhoneNumberChanged(value),
                                        ),
                                    onFieldSubmitted: (_) {
                                      if (form.isValid && !isLoading) {
                                        _onSubmit();
                                      }
                                    },
                                  ),
                                  if (form.newPhoneError != null) ...[
                                    const SizedBox(height: 6),
                                    _InlinePhoneValidationText(
                                      text: form.newPhoneError!,
                                    ),
                                  ] else if (form.isValid) ...[
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
                                              'Valid 10-digit phone number',
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
                                      'change_phone_submit_button',
                                    ),
                                    label: 'Save Changes',
                                    leadingIcon: Icons.check_circle_outline_rounded,
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

    return BlocProvider<ChangePhoneBloc>.value(
      value: _bloc,
      child:
          authBloc == null
              ? content
              : BlocListener<AuthenticationBloc, AuthenticationState>(
                listener: (context, authState) {
                  if (authState is AuthenticationSuccess &&
                      _bloc.state.form.currentPhoneNumber.isEmpty) {
                    _bloc.add(
                      InitializeChangePhone(authState.profile.mobileNumber),
                    );
                  }
                },
                child: content,
              ),
    );
  }
}

class _PhoneHeaderCard extends StatelessWidget {
  final bool compact;

  const _PhoneHeaderCard({this.compact = false});

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
              Icons.phone_iphone_rounded,
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
                  'Update Contact Phone Number',
                  style: TextStyle(
                    fontSize: compact ? 16 : 17.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter a valid 10-digit numeric phone number to update your profile directly.',
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

class _ReadOnlyCurrentPhoneCard extends StatelessWidget {
  final String phoneNumber;

  const _ReadOnlyCurrentPhoneCard({super.key, required this.phoneNumber});

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
            Icons.phone_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              phoneNumber,
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

class _ChangePhoneSuccessView extends StatelessWidget {
  final String updatedPhone;
  final String message;
  final VoidCallback onDone;

  const _ChangePhoneSuccessView({
    super.key,
    required this.updatedPhone,
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
                'Phone Number Updated',
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
                      Icons.phone_iphone_rounded,
                      size: 16,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Active phone: $updatedPhone • Account & rewards preserved.',
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
                key: const ValueKey('change_phone_done_button'),
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

class _PhoneFieldLabel extends StatelessWidget {
  final String text;

  const _PhoneFieldLabel(this.text);

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

class _InlinePhoneValidationText extends StatelessWidget {
  final String text;

  const _InlinePhoneValidationText({required this.text});

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

class _PhoneFailureBanner extends StatelessWidget {
  final String message;

  const _PhoneFailureBanner({super.key, required this.message});

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
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.rejectedBadgeText,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
