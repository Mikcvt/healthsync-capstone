import '../models/dose_log_model.dart';
import 'dose_timing.dart';

/// Adherence counts for a set of dose logs, computed one way everywhere
/// (DOSE_LOGIC_PROPOSAL.md, section 10).
///
/// - Cancelled doses never happened and are ignored.
/// - Doses of a medicine archived as "entered by mistake" are ignored.
/// - Open doses (pending or snoozed) are not counted either way, so a patient
///   is not shown 0% at breakfast for a dose not yet due.
class AdherenceStats {
  final int taken;
  final int missed;
  final int skipped;

  /// Taken doses by timing. [onTime] includes old logs with no timing whose
  /// taken time falls inside the on-time window.
  final int onTime;
  final int early;
  final int late;
  final int loggedLate;

  /// Reasons given for skipped and missed doses, most common first.
  final Map<String, int> reasons;

  const AdherenceStats({
    this.taken = 0,
    this.missed = 0,
    this.skipped = 0,
    this.onTime = 0,
    this.early = 0,
    this.late = 0,
    this.loggedLate = 0,
    this.reasons = const {},
  });

  factory AdherenceStats.of(Iterable<DoseLogModel> logs) {
    var taken = 0, missed = 0, skipped = 0;
    var onTime = 0, early = 0, late = 0, loggedLate = 0;
    final reasons = <String, int>{};

    for (final log in logs) {
      if (!counts(log)) continue;
      if (log.isTaken) {
        taken++;
        switch (effectiveTiming(log)) {
          case 'early':
            early++;
          case 'late':
            late++;
          case 'logged_late':
            loggedLate++;
          default:
            onTime++;
        }
      } else if (log.isSkipped || log.isMissed) {
        if (log.isSkipped) {
          skipped++;
        } else {
          missed++;
        }
        final reason = log.skippedReason.trim();
        if (reason.isNotEmpty) reasons[reason] = (reasons[reason] ?? 0) + 1;
      }
    }

    final sorted = Map.fromEntries(
      reasons.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );

    return AdherenceStats(
      taken: taken,
      missed: missed,
      skipped: skipped,
      onTime: onTime,
      early: early,
      late: late,
      loggedLate: loggedLate,
      reasons: sorted,
    );
  }

  /// Whether a log belongs in adherence at all.
  static bool counts(DoseLogModel log) =>
      !log.isCancelled && !log.excludedFromAdherence;

  /// The timing of a taken dose. Logs written before timing existed are
  /// derived from their taken time.
  static String effectiveTiming(DoseLogModel log) {
    final stored = log.timing;
    if (stored != null && stored.isNotEmpty) return stored;
    final takenAt = log.takenAt, scheduledAt = log.scheduledAt;
    if (takenAt == null || scheduledAt == null) return 'on_time';
    return DoseTiming.timingFor(takenAt: takenAt, scheduledAt: scheduledAt);
  }

  /// Doses with a decision: taken, skipped or missed.
  int get resolved => taken + missed + skipped;

  /// Doses not taken: missed plus skipped.
  int get notTaken => missed + skipped;

  /// `taken ÷ (taken + missed + skipped)`, as 0–1. 1.0 when nothing is
  /// resolved yet.
  double get adherence => resolved == 0 ? 1.0 : taken / resolved;

  /// Share of taken doses that were early or on time, as 0–1.
  double get onTimeRate => taken == 0 ? 1.0 : (onTime + early) / taken;
}
