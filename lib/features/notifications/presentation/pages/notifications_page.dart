import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_category.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_filter.dart';
import 'package:shiftex/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:shiftex/features/notifications/presentation/bloc/notification_event.dart';
import 'package:shiftex/features/notifications/presentation/bloc/notification_state.dart';
import 'package:shiftex/features/notifications/presentation/widgets/notification_campaign_sheet.dart';
import 'package:shiftex/features/notifications/presentation/widgets/notification_card.dart';
import 'package:shiftex/features/notifications/presentation/widgets/notification_filter_tabs.dart';
import 'package:shiftex/features/notifications/presentation/widgets/notification_header.dart';
import 'package:shiftex/features/notifications/presentation/widgets/notification_state_views.dart';
import 'package:shiftex/injection_container.dart';

typedef NotificationRouteHandler = void Function(
  String route,
  NotificationScrollTarget scrollTarget,
);

/// Opens the SHIIFTEX Notifications Center matching the modal bottom-sheet presentation.
Future<void> showNotificationsBottomSheet(
  BuildContext context, {
  NotificationBloc? notificationBloc,
  NotificationRouteHandler? onNavigate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x730E1525),
    builder: (sheetContext) {
      final resolvedBloc = notificationBloc ?? _tryReadBloc(context);
      return FractionallySizedBox(
        heightFactor: 0.93,
        alignment: Alignment.bottomCenter,
        child: NotificationsSheetContent(
          notificationBloc: resolvedBloc,
          onNavigate: onNavigate,
          onCloseSheet: () => Navigator.of(sheetContext).pop(),
        ),
      );
    },
  );
}

NotificationBloc? _tryReadBloc(BuildContext context) {
  try {
    return context.read<NotificationBloc>();
  } catch (_) {
    if (getIt.isRegistered<NotificationBloc>()) {
      return getIt<NotificationBloc>();
    }
    return null;
  }
}

/// Full-route entry point (`/notifications`) displaying the modal-sheet backdrop & panel.
class NotificationsPage extends StatelessWidget {
  final NotificationBloc? notificationBloc;
  final NotificationRouteHandler? onNavigate;

  const NotificationsPage({
    super.key,
    this.notificationBloc,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedBloc = notificationBloc ?? _tryReadBloc(context);
    return Scaffold(
      backgroundColor: const Color(0x730E1525),
      body: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: 0.93,
          widthFactor: 1,
          child: NotificationsSheetContent(
            notificationBloc: resolvedBloc,
            onNavigate: onNavigate,
            onCloseSheet: () {
              final router = GoRouter.maybeOf(context);
              if (router != null) {
                if (router.canPop()) {
                  router.pop();
                } else {
                  router.go(RoutesNames.home);
                }
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
        ),
      ),
    );
  }
}

class NotificationsSheetContent extends StatefulWidget {
  final NotificationBloc? notificationBloc;
  final NotificationRouteHandler? onNavigate;
  final VoidCallback onCloseSheet;

  const NotificationsSheetContent({
    super.key,
    this.notificationBloc,
    this.onNavigate,
    required this.onCloseSheet,
  });

  @override
  State<NotificationsSheetContent> createState() =>
      _NotificationsSheetContentState();
}

class _NotificationsSheetContentState extends State<NotificationsSheetContent> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final bloc = widget.notificationBloc;
    if (bloc != null &&
        (bloc.state.status == NotificationStatus.initial ||
            bloc.state.status == NotificationStatus.error) &&
        bloc.state.notifications.isEmpty) {
      bloc.add(const NotificationsLoadRequested(syncCampaigns: true));
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 180) {
      widget.notificationBloc?.add(const NotificationsLoadMoreRequested());
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _executeNavigation(
    String route,
    NotificationScrollTarget scrollTarget,
  ) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(route, scrollTarget);
      return;
    }

    final router = GoRouter.maybeOf(context);
    widget.onCloseSheet();
    if (router == null) return;

    if (route == RoutesNames.home &&
        scrollTarget != NotificationScrollTarget.none) {
      router.go(
        Uri(
          path: RoutesNames.home,
          queryParameters: {'section': scrollTarget.name},
        ).toString(),
      );
      return;
    }

    router.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final bloc = widget.notificationBloc;
    if (bloc == null) {
      return _buildShellContainer(
        child: NotificationEmptyView(filter: NotificationFilter.all),
      );
    }

    return BlocProvider<NotificationBloc>.value(
      value: bloc,
      child: BlocConsumer<NotificationBloc, NotificationState>(
        listenWhen: (previous, current) =>
            previous.navigationIntent?.sequence !=
                current.navigationIntent?.sequence ||
            (previous.feedbackSequence != current.feedbackSequence &&
                current.feedbackMessage != null),
        listener: (context, state) {
          if (state.feedbackMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.feedbackMessage!),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: state.isFeedbackError
                      ? AppColors.errorRed
                      : AppColors.primaryButtonDark,
                ),
              );
            bloc.add(const NotificationFeedbackCleared());
          }

          final intent = state.navigationIntent;
          if (intent != null) {
            bloc.add(const NotificationNavigationHandled());
            if (intent.unavailableMessage != null) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(intent.unavailableMessage!),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
            } else if (intent.hasCampaignDetail) {
              NotificationCampaignSheet.show(
                context,
                notification: intent.campaignDetail!,
                onExploreHome: () => _executeNavigation(
                  RoutesNames.home,
                  NotificationScrollTarget.none,
                ),
              );
            } else if (intent.hasRoute) {
              _executeNavigation(intent.route!, intent.scrollTarget);
            }
          }
        },
        builder: (context, state) {
          final screenWidth = MediaQuery.sizeOf(context).width;
          final horizontalPadding = screenWidth < 360 ? 16.0 : 20.0;

          return _buildShellContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NotificationHeader(
                  hasUnread: state.hasUnread,
                  isUpdating: state.isUpdating,
                  onClose: widget.onCloseSheet,
                  onMarkAllAsRead: () =>
                      bloc.add(const NotificationsAllMarkedAsRead()),
                ),
                NotificationFilterTabs(
                  activeFilter: state.activeFilter,
                  counts: state.counts,
                  onFilterSelected: (filter) =>
                      bloc.add(NotificationFilterChanged(filter)),
                ),
                const SizedBox(height: 12),
                if (state.isFromCache)
                  NotificationOfflineBanner(
                    onRetry: () => bloc.add(const NotificationsRefreshed()),
                  ),
                Expanded(
                  child: _buildFeedBody(
                    bloc: bloc,
                    state: state,
                    horizontalPadding: horizontalPadding,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShellContainer({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F0E1525),
            blurRadius: 28,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: SafeArea(
          top: false,
          child: child,
        ),
      ),
    );
  }

  Widget _buildFeedBody({
    required NotificationBloc bloc,
    required NotificationState state,
    required double horizontalPadding,
  }) {
    if ((state.status == NotificationStatus.loading ||
            state.status == NotificationStatus.initial) &&
        state.notifications.isEmpty) {
      return const NotificationLoadingSkeleton();
    }

    if (state.status == NotificationStatus.error &&
        state.notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          bloc.add(const NotificationsRefreshed());
          await bloc.stream.firstWhere(
            (next) => next.status != NotificationStatus.refreshing,
          );
        },
        child: NotificationErrorView(
          message: state.errorMessage ??
              'Unable to connect right now. Pull down or tap Try Again.',
          onRetry: () => bloc.add(
            const NotificationsLoadRequested(syncCampaigns: true),
          ),
        ),
      );
    }

    if (state.notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          bloc.add(const NotificationsRefreshed());
          await bloc.stream.firstWhere(
            (next) => next.status != NotificationStatus.refreshing,
          );
        },
        child: NotificationEmptyView(
          filter: state.activeFilter,
          onResetFilter: state.activeFilter == NotificationFilter.all
              ? null
              : () => bloc.add(
                    const NotificationFilterChanged(NotificationFilter.all),
                  ),
        ),
      );
    }

    final itemCount =
        state.notifications.length + (state.isLoadingMore ? 1 : 0);

    return RefreshIndicator(
      color: AppColors.primaryBlue,
      onRefresh: () async {
        bloc.add(const NotificationsRefreshed());
        await bloc.stream.firstWhere(
          (next) => next.status != NotificationStatus.refreshing,
        );
      },
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          4,
          horizontalPadding,
          28,
        ),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= state.notifications.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            );
          }

          final notification = state.notifications[index];
          return NotificationCard(
            notification: notification,
            onTap: () => bloc.add(NotificationOpened(notification)),
          );
        },
      ),
    );
  }
}
