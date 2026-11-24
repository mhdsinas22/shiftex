import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/home/domain/usecases/generate_claim_qr_usecase.dart';
import 'package:shiftex/features/home/domain/usecases/get_home_dashboard_usecase.dart';
import 'package:shiftex/features/home/domain/usecases/track_advertisement_event_usecase.dart';
import 'package:shiftex/features/home/presentation/bloc/home_event.dart';
import 'package:shiftex/features/home/presentation/bloc/home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetHomeDashboardUseCase _getHomeDashboardUseCase;
  final GenerateClaimQrUseCase _generateClaimQrUseCase;
  final TrackAdvertisementEventUseCase _trackAdvertisementEventUseCase;

  late String _sessionId;
  int _sessionCounter = 0;
  int _requestGeneration = 0;
  final Set<String> _celebratedCycleDates = <String>{};

  HomeBloc({
    required GetHomeDashboardUseCase getHomeDashboardUseCase,
    required GenerateClaimQrUseCase generateClaimQrUseCase,
    required TrackAdvertisementEventUseCase trackAdvertisementEventUseCase,
    String? sessionId,
  }) : _getHomeDashboardUseCase = getHomeDashboardUseCase,
       _generateClaimQrUseCase = generateClaimQrUseCase,
       _trackAdvertisementEventUseCase = trackAdvertisementEventUseCase,
       _sessionId =
           sessionId ?? 'sess_${DateTime.now().millisecondsSinceEpoch}',
       super(const HomeState()) {
    on<HomeDashboardLoadRequested>(_onLoadRequested);
    on<HomeDashboardRefreshRequested>(_onRefreshRequested);
    on<HomeTabChanged>(_onTabChanged);
    on<HomeClaimQrRequested>(_onClaimQrRequested);
    on<HomeClaimQrModalDismissed>(_onClaimQrModalDismissed);
    on<HomeStreakCelebrationDismissed>(_onStreakCelebrationDismissed);
    on<HomeCampaignActionTapped>(_onCampaignActionTapped);
    on<HomeSessionReset>(_onSessionReset);
  }

  Future<void> _onLoadRequested(
    HomeDashboardLoadRequested event,
    Emitter<HomeState> emit,
  ) async {
    if (state.status == HomeStatus.loading) return;
    emit(
      state.copyWith(
        status:
            state.dashboard == null
                ? HomeStatus.loading
                : HomeStatus.refreshing,
        clearError: true,
        clearFeedback: true,
      ),
    );

    await _fetchDashboard(
      emit,
      performDailyCheckIn: event.performDailyCheckIn,
    );
  }

  Future<void> _onRefreshRequested(
    HomeDashboardRefreshRequested event,
    Emitter<HomeState> emit,
  ) async {
    if (state.status == HomeStatus.loading ||
        state.status == HomeStatus.refreshing) {
      return;
    }

    emit(
      state.copyWith(
        status:
            state.dashboard == null
                ? HomeStatus.loading
                : HomeStatus.refreshing,
        clearError: true,
        clearFeedback: true,
      ),
    );

    await _fetchDashboard(emit, performDailyCheckIn: true);
  }

  Future<void> _fetchDashboard(
    Emitter<HomeState> emit, {
    required bool performDailyCheckIn,
  }) async {
    final generation = _requestGeneration;
    final result = await _getHomeDashboardUseCase(
      GetHomeDashboardParams(
        performDailyCheckIn: performDailyCheckIn,
        sessionId: _sessionId,
      ),
    );

    if (isClosed || generation != _requestGeneration) return;

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: HomeStatus.error,
            errorMessage: failure.message,
          ),
        );
      },
      (dashboard) {
        final cycleDate = dashboard.streak.cycleDate;
        final shouldCelebrate =
            dashboard.streak.justCompletedDay7 &&
            cycleDate.isNotEmpty &&
            !_celebratedCycleDates.contains(cycleDate);

        if (shouldCelebrate) {
          _celebratedCycleDates.add(cycleDate);
        }

        emit(
          state.copyWith(
            status: HomeStatus.loaded,
            dashboard: dashboard,
            showStreakCelebration:
                shouldCelebrate ? true : state.showStreakCelebration,
            clearError: true,
          ),
        );
      },
    );
  }

  void _onTabChanged(
    HomeTabChanged event,
    Emitter<HomeState> emit,
  ) {
    emit(
      state.copyWith(
        selectedTab: event.tab,
        clearError: true,
        clearFeedback: true,
      ),
    );
  }

  Future<void> _onClaimQrRequested(
    HomeClaimQrRequested event,
    Emitter<HomeState> emit,
  ) async {
    if (state.qrModalStatus == QrModalStatus.loading) return;

    emit(
      state.copyWith(
        qrModalStatus: QrModalStatus.loading,
        clearError: true,
        clearFeedback: true,
      ),
    );

    final generation = _requestGeneration;
    final result = await _generateClaimQrUseCase(const NoParams());
    if (isClosed || generation != _requestGeneration) return;
    result.fold(
      (failure) {
        emit(
          state.copyWith(
            qrModalStatus: QrModalStatus.error,
            errorMessage: failure.message,
          ),
        );
      },
      (qrToken) {
        emit(
          state.copyWith(
            qrModalStatus: QrModalStatus.ready,
            activeQrToken: qrToken,
            clearError: true,
          ),
        );
      },
    );
  }

  void _onClaimQrModalDismissed(
    HomeClaimQrModalDismissed event,
    Emitter<HomeState> emit,
  ) {
    emit(
      state.copyWith(
        qrModalStatus: QrModalStatus.idle,
        clearError: true,
      ),
    );
  }

  void _onStreakCelebrationDismissed(
    HomeStreakCelebrationDismissed event,
    Emitter<HomeState> emit,
  ) {
    emit(
      state.copyWith(
        showStreakCelebration: false,
      ),
    );
  }

  Future<void> _onCampaignActionTapped(
    HomeCampaignActionTapped event,
    Emitter<HomeState> emit,
  ) async {
    await _trackAdvertisementEventUseCase(
      TrackAdvertisementEventParams(
        advertisementId: event.advertisementId,
        eventType: event.eventType,
        sessionId: _sessionId,
      ),
    );

    if (event.promoCode != null && event.promoCode!.isNotEmpty) {
      emit(
        state.copyWith(
          feedbackMessage:
              'Voucher code ${event.promoCode} copied and ready at checkout!',
        ),
      );
    }
  }

  void _onSessionReset(HomeSessionReset event, Emitter<HomeState> emit) {
    _requestGeneration++;
    _celebratedCycleDates.clear();
    _sessionCounter++;
    _sessionId =
        'sess_${DateTime.now().millisecondsSinceEpoch}_$_sessionCounter';
    emit(const HomeState());
  }
}
