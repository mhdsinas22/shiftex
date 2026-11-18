import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shiftex/features/home/presentation/widgets/home_formatters.dart';

/// Displays the live MM:SS claim expiry countdown badge and notifies once
/// when the claim reaches zero seconds.
class ClaimCountdownTimer extends StatefulWidget {
  final DateTime expiresAt;
  final bool isActive;
  final VoidCallback? onExpired;
  final bool enableLiveTicker;

  const ClaimCountdownTimer({
    super.key,
    required this.expiresAt,
    required this.isActive,
    this.onExpired,
    this.enableLiveTicker = true,
  });

  @override
  State<ClaimCountdownTimer> createState() => _ClaimCountdownTimerState();
}

class _ClaimCountdownTimerState extends State<ClaimCountdownTimer> {
  Timer? _timer;
  late int _remainingSeconds;
  bool _notifiedExpiry = false;

  @override
  void initState() {
    super.initState();
    _syncRemaining();
    _startTickerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant ClaimCountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt ||
        oldWidget.isActive != widget.isActive) {
      _notifiedExpiry = false;
      _syncRemaining();
      _timer?.cancel();
      _startTickerIfNeeded();
    }
  }

  void _syncRemaining() {
    if (!widget.isActive) {
      _remainingSeconds = 0;
      return;
    }
    final diff = widget.expiresAt.difference(DateTime.now().toUtc()).inSeconds;
    _remainingSeconds = diff > 0 ? diff : 0;
  }

  void _startTickerIfNeeded() {
    if (!widget.isActive || !widget.enableLiveTicker) {
      return;
    }
    if (_remainingSeconds <= 0) {
      _notifyExpiredOnce();
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final diff =
          widget.expiresAt.difference(DateTime.now().toUtc()).inSeconds;
      final next = diff > 0 ? diff : 0;
      if (next != _remainingSeconds) {
        setState(() => _remainingSeconds = next);
      }
      if (next <= 0) {
        timer.cancel();
        _notifyExpiredOnce();
      }
    });
  }

  void _notifyExpiredOnce() {
    if (_notifiedExpiry || widget.onExpired == null) return;
    _notifiedExpiry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onExpired?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _remainingSeconds <= 0 || !widget.isActive;
    final bgColor =
        isExpired ? const Color(0xFFFEE4E2) : const Color(0xFFEDE9FE);
    final fgColor =
        isExpired ? const Color(0xFFB42318) : const Color(0xFF6D28D9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isExpired ? Icons.timer_off_outlined : Icons.timer_outlined,
            size: 13,
            color: fgColor,
          ),
          const SizedBox(width: 4),
          Text(
            HomeFormatters.formatMmSs(_remainingSeconds),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }
}
