/// Date and time helpers shared by the dose loop, the history screens and the
/// Worker-facing payloads.
///
/// Schedules store their time as a display string like `"08:00 PM"`, which is
/// what the caregiver typed. Nothing can be computed from that string directly,
/// so everything that needs to compare, sort or age a dose goes through
/// [parseScheduleTime] to get a real [DateTime] first.
class DateFormatter {
  const DateFormatter._();

  static const List<String> _monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<String> _daysShort = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  /// `"2026-10-06"` — the key format used by `dose_logs.scheduled_date`.
  static String toDateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// `"08:05 PM"` — the display format used by `schedules.scheduled_time`.
  static String toTimeLabel(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  /// `"8:05 PM"` — no leading zero, for dose cards and messages.
  static String toClockLabel(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }

  /// The date and time on a dose card: `"Today · 8:00 AM"`,
  /// `"Tomorrow · 8:00 AM"`, `"Yesterday · 8:00 AM"`, otherwise
  /// `"Thu, Oct 10 · 8:00 AM"`.
  static String doseDayTime(DateTime scheduledAt, {DateTime? now}) {
    final today = startOfDay(now ?? DateTime.now());
    final diff = startOfDay(scheduledAt).difference(today).inDays;
    final day = switch (diff) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      _ => '${weekdayShort(scheduledAt.weekday)}, '
          '${_monthsShort[scheduledAt.month - 1]} ${scheduledAt.day}',
    };
    return '$day · ${toClockLabel(scheduledAt)}';
  }

  /// `"Oct 6"`, or `"Oct 6, 2025"` when the year is not the current one.
  static String toShortDate(DateTime dt) {
    final label = '${_monthsShort[dt.month - 1]} ${dt.day}';
    return dt.year == DateTime.now().year ? label : '$label, ${dt.year}';
  }

  /// `"Mon"`. [weekday] follows [DateTime.weekday]: 1 = Monday, 7 = Sunday.
  static String weekdayShort(int weekday) =>
      _daysShort[(weekday - 1).clamp(0, 6)];

  /// `"Today"`, `"Yesterday"` or a short date — for grouping history rows.
  static String toRelativeDay(DateTime dt) {
    final today = startOfDay(DateTime.now());
    final day = startOfDay(dt);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff > 1 && diff < 7) return weekdayShort(dt.weekday);
    return toShortDate(dt);
  }

  /// `"4 minutes ago"` — for device heartbeats and sync times.
  static String toRelativeTime(DateTime dt) {
    final seconds = DateTime.now().difference(dt).inSeconds;
    if (seconds < 0) return 'just now';
    if (seconds < 60) return 'just now';
    final minutes = seconds ~/ 60;
    if (minutes < 60) {
      return '$minutes minute${minutes == 1 ? '' : 's'} ago';
    }
    final hours = minutes ~/ 60;
    if (hours < 24) return '$hours hour${hours == 1 ? '' : 's'} ago';
    final days = hours ~/ 24;
    if (days < 30) return '$days day${days == 1 ? '' : 's'} ago';
    return toShortDate(dt);
  }

  static DateTime startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Turns a stored schedule time into an instant on [onDate].
  ///
  /// Accepts `"08:00 PM"`, `"8:00 pm"`, `"20:00"` and `"8:00"`. Returns null on
  /// anything else rather than guessing — a dose placed at the wrong hour is
  /// worse than a dose the UI reports it could not read.
  static DateTime? parseScheduleTime(String raw, {DateTime? onDate}) {
    final text = raw.trim().toUpperCase();
    if (text.isEmpty) return null;

    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$').firstMatch(text);
    if (match == null) return null;

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3);

    if (minute > 59) return null;

    if (period != null) {
      if (hour < 1 || hour > 12) return null;
      // 12 AM is midnight and 12 PM is noon — the one case a naive
      // "add 12 for PM" gets wrong in both directions.
      if (period == 'AM') {
        hour = hour == 12 ? 0 : hour;
      } else {
        hour = hour == 12 ? 12 : hour + 12;
      }
    } else if (hour > 23) {
      return null;
    }

    final base = onDate ?? DateTime.now();
    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  /// Minutes past midnight, for sorting schedules by time of day. Unparseable
  /// times sort last rather than first, so a bad row cannot masquerade as the
  /// next dose due.
  static int minutesOfDay(String scheduledTime) {
    final parsed = parseScheduleTime(scheduledTime);
    if (parsed == null) return 1 << 20;
    return parsed.hour * 60 + parsed.minute;
  }
}
