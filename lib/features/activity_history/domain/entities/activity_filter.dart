enum ActivityFilter {
  all,
  earned,
  claims,
  dailyStreak;

  String get rpcValue {
    return switch (this) {
      ActivityFilter.all => 'all',
      ActivityFilter.earned => 'earned',
      ActivityFilter.claims => 'claims',
      ActivityFilter.dailyStreak => 'daily_streak',
    };
  }

  String get label {
    return switch (this) {
      ActivityFilter.all => 'All',
      ActivityFilter.earned => 'Earned (+)',
      ActivityFilter.claims => 'Claims (-)',
      ActivityFilter.dailyStreak => 'Daily Streak',
    };
  }
}
