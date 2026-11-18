import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shiftex/core/extensions/context_extensions.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';
import 'package:shiftex/core/widgets/shiiftex_info_bottom_sheet.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';
import 'package:shiftex/features/customer_qr/presentation/bloc/customer_qr_bloc.dart';
import 'package:shiftex/features/customer_qr/presentation/bloc/customer_qr_event.dart';
import 'package:shiftex/features/customer_qr/presentation/bloc/customer_qr_state.dart';
import 'package:shiftex/features/customer_qr/presentation/widgets/customer_identity_header.dart';
import 'package:shiftex/features/customer_qr/presentation/widgets/customer_qr_card.dart';
import 'package:shiftex/features/customer_qr/presentation/widgets/earning_steps_card.dart';
import 'package:shiftex/features/home/presentation/bloc/home_bloc.dart';
import 'package:shiftex/features/home/presentation/widgets/customer_profile_sheet.dart';
import 'package:shiftex/injection_container.dart';

/// Displays the authenticated customer's personal accrual-only QR pass and
/// earning instructions.
class CustomerQrPage extends StatefulWidget {
  final CustomerQrBloc? bloc;

  const CustomerQrPage({super.key, this.bloc});

  @override
  State<CustomerQrPage> createState() => _CustomerQrPageState();
}

class _CustomerQrPageState extends State<CustomerQrPage>
    with WidgetsBindingObserver {
  late final CustomerQrBloc _bloc;
  late final bool _ownsBloc;
  int _lastFeedbackSequence = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.bloc != null) {
      _bloc = widget.bloc!;
      _ownsBloc = false;
    } else {
      final parentBloc = _maybeReadBloc<CustomerQrBloc>(context);
      if (parentBloc != null) {
        _bloc = parentBloc;
        _ownsBloc = false;
      } else {
        _bloc = getIt<CustomerQrBloc>();
        _ownsBloc = true;
      }
    }

    if (_bloc.state.status == CustomerQrStatus.initial) {
      _bloc.add(const CustomerQrLoadRequested());
    } else {
      _bloc.add(const CustomerQrExpiryChecked());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _bloc.add(const CustomerQrExpiryChecked());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsBloc) {
      _bloc.close();
    }
    super.dispose();
  }

  T? _maybeReadBloc<T extends StateStreamableSource<Object?>>(
    BuildContext context,
  ) {
    try {
      return context.read<T>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _onPullToRefresh() async {
    if (_bloc.state.isBusy) return;
    final completion = _bloc.stream
        .skip(1)
        .firstWhere((state) => !state.isBusy)
        .timeout(const Duration(seconds: 15), onTimeout: () => _bloc.state);
    _bloc.add(const CustomerQrRefreshRequested());
    await completion;
  }

  void _handleDone() {
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

  void _openNotifications() {
    ShiiftexInfoBottomSheet.show(
      context,
      title: 'Notifications',
      message:
          'You are all caught up! Point credits and merchant scan confirmations will appear in your Recent Rewards activity.',
    );
  }

  void _openProfileSheet(CustomerQrState qrState) {
    final authBloc = _maybeReadBloc<AuthenticationBloc>(context);
    final homeBloc = _maybeReadBloc<HomeBloc>(context);
    final authState = authBloc?.state;

    final profile = switch (authState) {
      AuthenticationSuccess(:final profile) => profile,
      AuthenticationLoading(:final currentProfile) => currentProfile,
      _ => null,
    };

    final fallbackName =
        qrState.qrData?.fullName ?? profile?.fullName ?? 'SHIIFTEX Member';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return CustomerProfileSheet(
          dashboard: homeBloc?.state.dashboard,
          fallbackFullName: fallbackName,
          fallbackEmail: profile?.email ?? '',
          fallbackMobile: profile?.mobileNumber ?? '',
          onSignOut: () {
            Navigator.of(sheetContext).pop();
            authBloc?.add(const LogoutRequested());
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final horizontalPadding = responsive.sheetHorizontalPadding;

    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: SafeArea(
          child: BlocConsumer<CustomerQrBloc, CustomerQrState>(
            listenWhen: (previous, current) =>
                previous.feedbackSequence != current.feedbackSequence,
            listener: (context, state) {
              if (state.feedbackSequence == _lastFeedbackSequence) {
                return;
              }
              _lastFeedbackSequence = state.feedbackSequence;

              if (state.errorMessage != null && state.hasData) {
                context.showFeedbackSnackBar(state.errorMessage!, isError: true);
                _bloc.add(const CustomerQrFeedbackCleared());
              } else if (state.infoMessage != null) {
                context.showFeedbackSnackBar(state.infoMessage!, isError: false);
                _bloc.add(const CustomerQrFeedbackCleared());
              }
            },
            builder: (context, state) {
              final headerName = state.qrData?.fullName ?? 'SHIIFTEX Member';

              return Column(
                children: [
                  CustomerIdentityHeader(
                    fullName: headerName,
                    onNotificationTap: _openNotifications,
                    onProfileTap: () => _openProfileSheet(state),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _onPullToRefresh,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          16,
                          horizontalPadding,
                          24,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: responsive.maxContentWidth,
                            ),
                            child: Column(
                              children: [
                                CustomerQrCard(
                                  qrData: state.qrData,
                                  isLoading:
                                      state.status == CustomerQrStatus.loading,
                                  isRefreshing:
                                      state.status ==
                                      CustomerQrStatus.refreshing,
                                  isExpired: state.isExpired,
                                  errorMessage: state.errorMessage,
                                  onCopyId:
                                      () => _bloc.add(
                                        const CustomerIdCopyRequested(),
                                      ),
                                  onDone: _handleDone,
                                  onRefresh:
                                      () => _bloc.add(
                                        const CustomerQrRefreshRequested(),
                                      ),
                                ),
                                const SizedBox(height: 16),
                                const EarningStepsCard(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
