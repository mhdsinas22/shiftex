class HomeFormatters {
  const HomeFormatters._();

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String formatPoints(int points) {
    final absStr = points.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < absStr.length; i++) {
      if (i > 0 && (absStr.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(absStr[i]);
    }
    return points < 0 ? '-${buffer.toString()}' : buffer.toString();
  }

  static String formatInr(double amount, {int decimals = 2}) {
    final prefix = amount < 0 ? '-₹' : '₹';
    return '$prefix${amount.abs().toStringAsFixed(decimals)}';
  }

  static String formatCountdown(Duration duration) {
    if (duration.inSeconds <= 0) return 'Ready to unlock';
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    if (days > 0) {
      return '${days}d ${hours}h';
    }
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  static String formatUnlockDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = _months[local.month - 1];
    final year = local.year;
    final hour12 =
        local.hour == 0
            ? 12
            : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year, ${hour12.toString().padLeft(2, '0')}:$minute $period';
  }

  static String formatShortDateRange(DateTime start, DateTime end) {
    final s = start.toLocal();
    final e = end.toLocal();
    final sMonth = _months[s.month - 1];
    final eMonth = _months[e.month - 1];
    return 'Valid $sMonth ${s.day} – $eMonth ${e.day}, ${e.year}';
  }

  static String formatRelativeTimestamp(DateTime dateTime, {DateTime? now}) {
    final local = dateTime.toLocal();
    final ref = (now ?? DateTime.now()).toLocal();
    final todayDate = DateTime(ref.year, ref.month, ref.day);
    final itemDate = DateTime(local.year, local.month, local.day);
    final diffDays = todayDate.difference(itemDate).inDays;

    final hour12 =
        local.hour == 0
            ? 12
            : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '${hour12.toString().padLeft(2, '0')}:$minute $period';

    if (diffDays == 0) {
      return 'Today, $timeStr';
    }
    if (diffDays == 1) {
      return 'Yesterday';
    }
    final month = _months[local.month - 1];
    return '${local.day} $month, $timeStr';
  }

  static String formatMmSs(int totalSeconds) {
    final clamped = totalSeconds < 0 ? 0 : totalSeconds;
    final mins = (clamped ~/ 60).toString().padLeft(2, '0');
    final secs = (clamped % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}
