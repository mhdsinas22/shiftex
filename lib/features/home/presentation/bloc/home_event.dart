import 'package:equatable/equatable.dart';
import 'package:shiftex/features/home/presentation/bloc/home_state.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class HomeDashboardLoadRequested extends HomeEvent {
  final bool performDailyCheckIn;

  const HomeDashboardLoadRequested({this.performDailyCheckIn = true});

  @override
  List<Object?> get props => [performDailyCheckIn];
}

class HomeDashboardRefreshRequested extends HomeEvent {
  const HomeDashboardRefreshRequested();
}

class HomeTabChanged extends HomeEvent {
  final HomeTab tab;

  const HomeTabChanged(this.tab);

  @override
  List<Object?> get props => [tab];
}

class HomeClaimQrRequested extends HomeEvent {
  const HomeClaimQrRequested();
}

class HomeClaimQrModalDismissed extends HomeEvent {
  const HomeClaimQrModalDismissed();
}

class HomeStreakCelebrationDismissed extends HomeEvent {
  const HomeStreakCelebrationDismissed();
}

class HomeCampaignActionTapped extends HomeEvent {
  final String advertisementId;
  final String eventType;
  final String? promoCode;

  const HomeCampaignActionTapped({
    required this.advertisementId,
    required this.eventType,
    this.promoCode,
  });

  @override
  List<Object?> get props => [advertisementId, eventType, promoCode];
}

class HomeSessionReset extends HomeEvent {
  const HomeSessionReset();
}
