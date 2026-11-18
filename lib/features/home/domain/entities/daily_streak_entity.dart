import 'package:equatable/equatable.dart';

class DailyStreakEntity extends Equatable {
  final bool dailyLoginEnabled;
  final int dailyPoints;
  final int currentStreakDay;
  final bool claimedToday;
  final int daysRemaining;
  final String cycleDate;
  final DateTime nextResetAt;
  final bool justCompletedDay7;
  final int completedStreakPoints;
  final DateTime? completedUnlockAt;

  const DailyStreakEntity({
    required this.dailyLoginEnabled,
    required this.dailyPoints,
    required this.currentStreakDay,
    required this.claimedToday,
    required this.daysRemaining,
    required this.cycleDate,
    required this.nextResetAt,
    required this.justCompletedDay7,
    required this.completedStreakPoints,
    this.completedUnlockAt,
  });

  int get totalStreakTargetPoints => dailyPoints * 7;

  DailyStreakEntity copyWith({
    bool? dailyLoginEnabled,
    int? dailyPoints,
    int? currentStreakDay,
    bool? claimedToday,
    int? daysRemaining,
    String? cycleDate,
    DateTime? nextResetAt,
    bool? justCompletedDay7,
    int? completedStreakPoints,
    DateTime? completedUnlockAt,
  }) {
    return DailyStreakEntity(
      dailyLoginEnabled: dailyLoginEnabled ?? this.dailyLoginEnabled,
      dailyPoints: dailyPoints ?? this.dailyPoints,
      currentStreakDay: currentStreakDay ?? this.currentStreakDay,
      claimedToday: claimedToday ?? this.claimedToday,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      cycleDate: cycleDate ?? this.cycleDate,
      nextResetAt: nextResetAt ?? this.nextResetAt,
      justCompletedDay7: justCompletedDay7 ?? this.justCompletedDay7,
      completedStreakPoints:
          completedStreakPoints ?? this.completedStreakPoints,
      completedUnlockAt: completedUnlockAt ?? this.completedUnlockAt,
    );
  }

  @override
  List<Object?> get props => [
    dailyLoginEnabled,
    dailyPoints,
    currentStreakDay,
    claimedToday,
    daysRemaining,
    cycleDate,
    nextResetAt,
    justCompletedDay7,
    completedStreakPoints,
    completedUnlockAt,
  ];
}
