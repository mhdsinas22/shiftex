import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/features/advertisements/domain/entities/advertisement_entity.dart';
import 'package:shiftex/features/advertisements/domain/entities/advertisement_event_type.dart';
import 'package:shiftex/features/advertisements/domain/usecases/clear_advertisement_session_usecase.dart';
import 'package:shiftex/features/advertisements/domain/usecases/get_eligible_advertisement_usecase.dart';
import 'package:shiftex/features/advertisements/domain/usecases/track_advertisement_analytics_usecase.dart';
import 'package:shiftex/features/advertisements/presentation/bloc/advertisement_event.dart';
import 'package:shiftex/features/advertisements/presentation/bloc/advertisement_state.dart';

/// Coordinates customer ad session boundaries, eligibility checks, single-timer
/// auto-dismissal countdowns, frequency cap tracking, and analytics events.
class AdvertisementBloc extends Bloc<AdvertisementEvent, AdvertisementState> {
  final GetEligibleAdvertisementUseCase _getEligibleAdvertisementUseCase;
  final TrackAdvertisementAnalyticsUseCase _trackAdvertisementAnalyticsUseCase;
  final ClearAdvertisementSessionUseCase _clearAdvertisementSessionUseCase;
  final DateTime Function() _clockProvider;
  final String Function(String userId) _sessionIdGenerator;
  final Duration _tickInterval;

  Timer? _countdownTimer;
  int _requestGeneration = 0;
  int _sessionCounter = 0;
  bool _sessionActive = false;
  String? _activeUserId;
  String? _activeSessionId;

  final Set<String> _recordedImpressionKeys = <String>{};
  final Set<String> _recordedOutcomeKeys = <String>{};

  AdvertisementBloc({
    required GetEligibleAdvertisementUseCase getEligibleAdvertisementUseCase,
    required TrackAdvertisementAnalyticsUseCase
    trackAdvertisementAnalyticsUseCase,
    required ClearAdvertisementSessionUseCase clearAdvertisementSessionUseCase,
    DateTime Function()? clockProvider,
    String Function(String userId)? sessionIdGenerator,
    Duration tickInterval = const Duration(seconds: 1),
  }) : _getEligibleAdvertisementUseCase = getEligibleAdvertisementUseCase,
       _trackAdvertisementAnalyticsUseCase = trackAdvertisementAnalyticsUseCase,
       _clearAdvertisementSessionUseCase = clearAdvertisementSessionUseCase,
       _clockProvider = clockProvider ?? (() => DateTime.now().toUtc()),
       _sessionIdGenerator =
           sessionIdGenerator ??
           ((userId) =>
               'ad_sess_${userId}_${DateTime.now().millisecondsSinceEpoch}'),
       _tickInterval = tickInterval,
       super(const AdvertisementState()) {
    on<AdvertisementSessionStarted>(_onSessionStarted);
    on<AdvertisementSessionEnded>(_onSessionEnded);
    on<AdvertisementCountdownTicked>(_onCountdownTicked);
    on<AdvertisementDismissRequested>(_onDismissRequested);
    on<AdvertisementCtaPressed>(_onCtaPressed);
    on<AdvertisementPendingActionHandled>(_onPendingActionHandled);
  }

  Future<void> _onSessionStarted(
    AdvertisementSessionStarted event,
    Emitter<AdvertisementState> emit,
  ) async {
    final userId = event.userId.trim();
    if (userId.isEmpty) return;

    // Ignore duplicate startup triggers or widget rebuilds inside the same session.
    if (!event.forceNewSession &&
        _sessionActive &&
        _activeUserId == userId &&
        _activeSessionId != null) {
      return;
    }

    _cancelTimer();
    final generation = ++_requestGeneration;
    _sessionCounter += 1;
    final sessionId = '${_sessionIdGenerator(userId)}_$_sessionCounter';
    _sessionActive = true;
    _activeUserId = userId;
    _activeSessionId = sessionId;

    emit(
      state.copyWith(
        status: AdvertisementStatus.loading,
        activeUserId: userId,
        sessionId: sessionId,
        clearActiveAdvertisement: true,
        clearErrorMessage: true,
        clearPendingCtaAction: true,
      ),
    );

    final refNow = _clockProvider().toUtc();
    final result = await _getEligibleAdvertisementUseCase(
      GetEligibleAdvertisementParams(
        userId: userId,
        sessionId: sessionId,
        nowOverride: refNow,
      ),
    );

    // Abort safely if user logged out or another session superseded this request.
    if (isClosed ||
        generation != _requestGeneration ||
        !_sessionActive ||
        _activeUserId != userId ||
        _activeSessionId != sessionId) {
      return;
    }

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: AdvertisementStatus.error,
            errorMessage: failure.message,
            clearActiveAdvertisement: true,
          ),
        );
      },
      (ad) {
        final effectiveNow = ad?.serverNow ?? _clockProvider().toUtc();
        if (ad == null || !ad.isEligibleAt(effectiveNow)) {
          emit(
            state.copyWith(
              status: AdvertisementStatus.empty,
              clearActiveAdvertisement: true,
              remainingSeconds: 0,
              totalSeconds: 0,
            ),
          );
          return;
        }

        final duration = ad.effectiveDurationSeconds;
        final nextSeq = state.presentationSequence + 1;
        final impressionKey = '$sessionId:${ad.id}:$nextSeq';

        if (_recordedImpressionKeys.add(impressionKey)) {
          // Non-blocking impression analytics tied cleanly to the actual display.
          unawaited(
            _trackAdvertisementAnalyticsUseCase(
              TrackAdvertisementAnalyticsParams(
                userId: userId,
                advertisementId: ad.id,
                eventType: AdvertisementEventType.impression,
                sessionId: sessionId,
                presentationSequence: nextSeq,
                metadata: {'popup_duration_seconds': duration},
                nowOverride: _clockProvider().toUtc(),
              ),
            ),
          );
        }

        emit(
          state.copyWith(
            status: AdvertisementStatus.showing,
            activeAdvertisement: ad,
            remainingSeconds: duration,
            totalSeconds: duration,
            presentationSequence: nextSeq,
            clearErrorMessage: true,
          ),
        );

        _startCountdownTimer(generation: generation);
      },
    );
  }

  void _startCountdownTimer({required int generation}) {
    _cancelTimer();
    _countdownTimer = Timer.periodic(_tickInterval, (_) {
      if (!isClosed && generation == _requestGeneration) {
        add(const AdvertisementCountdownTicked());
      }
    });
  }

  void _onCountdownTicked(
    AdvertisementCountdownTicked event,
    Emitter<AdvertisementState> emit,
  ) {
    if (state.status != AdvertisementStatus.showing ||
        state.activeAdvertisement == null) {
      _cancelTimer();
      return;
    }

    final nextRemaining = state.remainingSeconds - 1;
    if (nextRemaining > 0) {
      emit(state.copyWith(remainingSeconds: nextRemaining));
      return;
    }

    _cancelTimer();
    final ad = state.activeAdvertisement!;
    final userId = state.activeUserId;
    final sessionId = state.sessionId;
    final seq = state.presentationSequence;

    emit(
      state.copyWith(
        status: AdvertisementStatus.dismissed,
        remainingSeconds: 0,
        clearActiveAdvertisement: true,
      ),
    );

    _recordOutcomeOnce(
      userId: userId,
      advertisementId: ad.id,
      sessionId: sessionId,
      presentationSequence: seq,
      eventType: AdvertisementEventType.autoDismissal,
      metadata: {'total_duration_seconds': state.totalSeconds},
    );
  }

  void _onDismissRequested(
    AdvertisementDismissRequested event,
    Emitter<AdvertisementState> emit,
  ) {
    if (state.status != AdvertisementStatus.showing ||
        state.activeAdvertisement == null) {
      return;
    }

    _cancelTimer();
    final ad = state.activeAdvertisement!;
    final userId = state.activeUserId;
    final sessionId = state.sessionId;
    final seq = state.presentationSequence;
    final remaining = state.remainingSeconds;
    final elapsed = (state.totalSeconds - remaining).clamp(
      0,
      state.totalSeconds,
    );

    emit(
      state.copyWith(
        status: AdvertisementStatus.dismissed,
        clearActiveAdvertisement: true,
      ),
    );

    _recordOutcomeOnce(
      userId: userId,
      advertisementId: ad.id,
      sessionId: sessionId,
      presentationSequence: seq,
      eventType: AdvertisementEventType.dismissal,
      metadata: {'remaining_seconds': remaining, 'elapsed_seconds': elapsed},
    );
  }

  void _onCtaPressed(
    AdvertisementCtaPressed event,
    Emitter<AdvertisementState> emit,
  ) {
    if (state.status != AdvertisementStatus.showing ||
        state.activeAdvertisement == null) {
      return;
    }

    _cancelTimer();
    final ad = state.activeAdvertisement!;
    final userId = state.activeUserId;
    final sessionId = state.sessionId;
    final seq = state.presentationSequence;
    final remaining = state.remainingSeconds;

    AdvertisementPendingCtaAction? action;
    if (ad.hasConfiguredCta) {
      if (ad.resolvedInternalRoute != null) {
        action = AdvertisementPendingCtaAction(
          advertisementId: ad.id,
          actionType: AdvertisementCtaActionType.internalRoute,
          internalRoute: ad.resolvedInternalRoute,
        );
      } else if (ad.resolvedExternalUri != null) {
        action = AdvertisementPendingCtaAction(
          advertisementId: ad.id,
          actionType: AdvertisementCtaActionType.externalUrl,
          externalUri: ad.resolvedExternalUri,
        );
      }
    }

    emit(
      state.copyWith(
        status: AdvertisementStatus.dismissed,
        clearActiveAdvertisement: true,
        pendingCtaAction: action,
        ctaActionSequence:
            action != null
                ? state.ctaActionSequence + 1
                : state.ctaActionSequence,
      ),
    );

    _recordOutcomeOnce(
      userId: userId,
      advertisementId: ad.id,
      sessionId: sessionId,
      presentationSequence: seq,
      eventType: AdvertisementEventType.ctaClick,
      metadata: {
        'cta_label': ad.ctaLabel,
        'cta_action_type': ad.ctaActionType?.rawValue,
        'cta_action_value': ad.ctaActionValue,
        'remaining_seconds': remaining,
      },
    );
  }

  void _onPendingActionHandled(
    AdvertisementPendingActionHandled event,
    Emitter<AdvertisementState> emit,
  ) {
    emit(state.copyWith(clearPendingCtaAction: true));
  }

  Future<void> _onSessionEnded(
    AdvertisementSessionEnded event,
    Emitter<AdvertisementState> emit,
  ) async {
    _requestGeneration += 1;
    _cancelTimer();
    final prevSession = _activeSessionId;
    _sessionActive = false;
    _activeUserId = null;
    _activeSessionId = null;
    _recordedImpressionKeys.clear();
    _recordedOutcomeKeys.clear();

    if (prevSession != null && prevSession.isNotEmpty) {
      unawaited(
        _clearAdvertisementSessionUseCase(
          ClearAdvertisementSessionParams(sessionId: prevSession),
        ),
      );
    }

    emit(const AdvertisementState());
  }

  void _recordOutcomeOnce({
    required String? userId,
    required String advertisementId,
    required String? sessionId,
    required int presentationSequence,
    required AdvertisementEventType eventType,
    Map<String, dynamic>? metadata,
  }) {
    if (userId == null ||
        userId.isEmpty ||
        sessionId == null ||
        sessionId.isEmpty) {
      return;
    }
    final outcomeKey = '$sessionId:$advertisementId:$presentationSequence';
    if (!_recordedOutcomeKeys.add(outcomeKey)) {
      return;
    }
    unawaited(
      _trackAdvertisementAnalyticsUseCase(
        TrackAdvertisementAnalyticsParams(
          userId: userId,
          advertisementId: advertisementId,
          eventType: eventType,
          sessionId: sessionId,
          presentationSequence: presentationSequence,
          metadata: metadata,
          nowOverride: _clockProvider().toUtc(),
        ),
      ),
    );
  }

  void _cancelTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  @override
  Future<void> close() {
    _cancelTimer();
    return super.close();
  }
}
