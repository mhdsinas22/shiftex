import 'package:equatable/equatable.dart';

class LockedPointAllocationEntity extends Equatable {
  final String id;
  final String sourceType;
  final int points;
  final String status;
  final String description;
  final DateTime lockedAt;
  final DateTime unlockAt;

  const LockedPointAllocationEntity({
    required this.id,
    required this.sourceType,
    required this.points,
    required this.status,
    required this.description,
    required this.lockedAt,
    required this.unlockAt,
  });

  double progressFraction(DateTime now) {
    final totalMs = unlockAt.difference(lockedAt).inMilliseconds;
    if (totalMs <= 0) return 1.0;
    final elapsedMs = now.difference(lockedAt).inMilliseconds;
    return (elapsedMs / totalMs).clamp(0.05, 1.0);
  }

  int progressPercent(DateTime now) =>
      (progressFraction(now) * 100).round().clamp(0, 100);

  Duration remainingDuration(DateTime now) {
    final diff = unlockAt.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  List<Object?> get props => [
    id,
    sourceType,
    points,
    status,
    description,
    lockedAt,
    unlockAt,
  ];
}
