/// The timing rules for one dose, in one place.
///
/// Every screen and the Worker follow the same timeline (see
/// DOSE_LOGIC_PROPOSAL.md, section 2.2):
///
/// ```
///        −30 min           0          +30 min        +60 min
///  ──────────┼─────────────┼──────────────┼──────────────┼────────►
///   Upcoming │  Upcoming   │   Due now    │    Late      │  Missed
///   (locked) │  (unlocked) │  (on time)   │              │
/// ```
///
/// Pure Dart with no Firebase or Flutter imports, so it can be unit-tested
/// against a fixed clock.
library;

/// Where a not-yet-decided dose sits on its timeline.
enum DosePhase {
  /// More than 30 minutes before the dose. Done/Skip are locked; tapping them
  /// asks whether the patient is logging early.
  upcomingLocked,

  /// 30 minutes before the dose, up to the dose time. Done/Skip work, but the
  /// badge still says "Upcoming" — the dose is not due yet.
  upcomingUnlocked,

  /// From the dose time up to 29 minutes after. On time.
  dueNow,

  /// 30 to 59 minutes after the dose time.
  late,

  /// 60 minutes or more after the dose time with nothing recorded.
  missed,
}

/// Whether a dose may be logged early right now.
class EarlyLogCheck {
  /// The earliest moment this dose can be logged.
  final DateTime earliest;
  final bool allowed;

  const EarlyLogCheck({required this.earliest, required this.allowed});
}

class DoseTiming {
  DoseTiming._();

  /// Done and Skip unlock this long before the dose time.
  static const Duration unlockBefore = Duration(minutes: 30);

  /// From this long after the dose time, the dose is "Late" and the caregiver
  /// gets a running-late alert.
  static const Duration lateAfter = Duration(minutes: 30);

  /// From this long after the dose time, an undecided dose is "Missed".
  static const Duration missedAfter = Duration(minutes: 60);

  /// The furthest ahead a dose may be logged early, before the half-gap rule.
  static const Duration earlyCap = Duration(hours: 3);

  /// How long the Undo toast stays, and how long the caregiver push waits.
  static const Duration undoWindow = Duration(seconds: 5);

  /// Where a dose scheduled at [scheduledAt] sits at [now].
  static DosePhase phaseOf(DateTime scheduledAt, DateTime now) {
    if (now.isBefore(scheduledAt.subtract(unlockBefore))) {
      return DosePhase.upcomingLocked;
    }
    if (now.isBefore(scheduledAt)) return DosePhase.upcomingUnlocked;
    if (now.isBefore(scheduledAt.add(lateAfter))) return DosePhase.dueNow;
    if (now.isBefore(scheduledAt.add(missedAfter))) return DosePhase.late;
    return DosePhase.missed;
  }

  /// When Done and Skip unlock for a dose.
  static DateTime unlockAt(DateTime scheduledAt) =>
      scheduledAt.subtract(unlockBefore);

  /// The earliest a dose may be logged early: [earlyCap] before it, but never
  /// more than half the gap to the previous dose of the same medicine, so a
  /// medicine taken every 4 hours cannot have its 12:00 dose logged before
  /// the 8:00 one is dealt with.
  static DateTime earliestLogAt(
    DateTime scheduledAt, {
    DateTime? previousDoseAt,
  }) {
    var lead = earlyCap;
    if (previousDoseAt != null && previousDoseAt.isBefore(scheduledAt)) {
      final halfGap = scheduledAt.difference(previousDoseAt) ~/ 2;
      if (halfGap < lead) lead = halfGap;
    }
    return scheduledAt.subtract(lead);
  }

  /// Whether tapping a locked Done/Skip at [now] may proceed through the
  /// early-logging prompt, or is simply too early.
  static EarlyLogCheck checkEarly(
    DateTime scheduledAt,
    DateTime now, {
    DateTime? previousDoseAt,
  }) {
    final earliest =
        earliestLogAt(scheduledAt, previousDoseAt: previousDoseAt);
    return EarlyLogCheck(earliest: earliest, allowed: !now.isBefore(earliest));
  }

  /// The [DoseTimingTag] value for a dose taken at [takenAt]. [early] is true
  /// when the patient came through the early-logging prompt.
  static String timingFor({
    required DateTime takenAt,
    required DateTime scheduledAt,
    bool early = false,
  }) {
    if (early) return 'early';
    if (!takenAt.isBefore(scheduledAt.add(lateAfter))) return 'late';
    return 'on_time';
  }

  /// "I took it but forgot to log it" is allowed until the end of the day
  /// after the dose's own day. Older misses stay missed.
  static bool retroLogAllowed(DateTime scheduledAt, DateTime now) {
    final endOfNextDay = DateTime(
      scheduledAt.year,
      scheduledAt.month,
      scheduledAt.day + 2,
    );
    return now.isBefore(endOfNextDay);
  }

  /// Relative wording for the badge (DOSE_LOGIC_PROPOSAL.md, section 6.4).
  ///
  /// | Time until due     | Text                    |
  /// |--------------------|-------------------------|
  /// | 2 hours or more    | Due in 3 hrs            |
  /// | 60 – 119 min       | Due in 1 hr 20 mins     |
  /// | 2 – 59 min         | Due in 15 mins          |
  /// | 0 – 1 min          | Due now                 |
  /// | 1 – 29 min after   | Due now · 12 mins ago   |
  /// | 30 – 59 min after  | 35 mins late            |
  /// | 60 min or more     | Missed                  |
  static String countdown(DateTime scheduledAt, DateTime now) {
    if (now.isBefore(scheduledAt)) {
      final minutes = scheduledAt.difference(now).inMinutes;
      if (minutes >= 120) return 'Due in ${minutes ~/ 60} hrs';
      if (minutes >= 60) {
        final rest = minutes - 60;
        return rest == 0 ? 'Due in 1 hr' : 'Due in 1 hr ${_mins(rest)}';
      }
      if (minutes >= 2) return 'Due in ${_mins(minutes)}';
      return 'Due now';
    }

    final after = now.difference(scheduledAt).inMinutes;
    if (after < 1) return 'Due now';
    if (after < lateAfter.inMinutes) return 'Due now · ${_mins(after)} ago';
    if (after < missedAfter.inMinutes) return '${_mins(after)} late';
    return 'Missed';
  }

  /// A duration in words for messages such as "in 2 hrs 10 mins".
  static String spanInWords(Duration span) {
    final total = span.inMinutes.abs();
    final hours = total ~/ 60;
    final minutes = total % 60;
    if (hours == 0) return _mins(minutes);
    final h = hours == 1 ? '1 hr' : '$hours hrs';
    return minutes == 0 ? h : '$h ${_mins(minutes)}';
  }

  static String _mins(int n) => n == 1 ? '1 min' : '$n mins';
}
