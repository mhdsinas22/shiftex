import 'package:equatable/equatable.dart';
import 'package:shiftex/features/home/domain/entities/customer_qr_token_entity.dart';
import 'package:shiftex/features/home/domain/entities/home_dashboard_entity.dart';

enum HomeStatus { initial, loading, refreshing, loaded, error }

enum QrModalStatus { idle, loading, ready, error }

enum HomeTab { home, showqr, history }

class HomeState extends Equatable {
  final HomeStatus status;
  final QrModalStatus qrModalStatus;
  final HomeTab selectedTab;
  final HomeDashboardEntity? dashboard;
  final CustomerQrTokenEntity? activeQrToken;
  final bool showStreakCelebration;
  final String? errorMessage;
  final String? feedbackMessage;

  const HomeState({
    this.status = HomeStatus.initial,
    this.qrModalStatus = QrModalStatus.idle,
    this.selectedTab = HomeTab.home,
    this.dashboard,
    this.activeQrToken,
    this.showStreakCelebration = false,
    this.errorMessage,
    this.feedbackMessage,
  });

  HomeState copyWith({
    HomeStatus? status,
    QrModalStatus? qrModalStatus,
    HomeTab? selectedTab,
    HomeDashboardEntity? dashboard,
    CustomerQrTokenEntity? activeQrToken,
    bool? showStreakCelebration,
    String? errorMessage,
    String? feedbackMessage,
    bool clearError = false,
    bool clearFeedback = false,
  }) {
    return HomeState(
      status: status ?? this.status,
      qrModalStatus: qrModalStatus ?? this.qrModalStatus,
      selectedTab: selectedTab ?? this.selectedTab,
      dashboard: dashboard ?? this.dashboard,
      activeQrToken: activeQrToken ?? this.activeQrToken,
      showStreakCelebration:
          showStreakCelebration ?? this.showStreakCelebration,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      feedbackMessage: clearFeedback
          ? null
          : (feedbackMessage ?? this.feedbackMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    qrModalStatus,
    selectedTab,
    dashboard,
    activeQrToken,
    showStreakCelebration,
    errorMessage,
    feedbackMessage,
  ];
}
