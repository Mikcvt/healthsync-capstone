import 'package:flutter_test/flutter_test.dart';
import 'package:healthsync/models/dose_log_model.dart';
import 'package:healthsync/utils/adherence.dart';
import 'package:healthsync/utils/dose_timing.dart';

/// An 8:00 AM dose on a fixed day, and helpers for "minutes from it".
final dose = DateTime(2026, 10, 9, 8, 0);
DateTime at(int minutesFromDose) => dose.add(Duration(minutes: minutesFromDose));

DoseLogModel log(
  String status, {
  String? timing,
  DateTime? takenAt,
  String reason = '',
  bool excluded = false,
}) =>
    DoseLogModel(
      doseLogId: 'x',
      scheduleRef: 's',
      patientRef: 'p',
      scheduledDate: '2026-10-09',
      scheduledTime: '08:00 AM',
      scheduledAt: dose,
      status: status,
      timing: timing,
      takenAt: takenAt,
      skippedReason: reason,
      excludedFromAdherence: excluded,
      createdAt: dose,
    );

void main() {
  group('phase (proposal 2.2)', () {
    test('locked more than 30 minutes before', () {
      expect(DoseTiming.phaseOf(dose, at(-60)), DosePhase.upcomingLocked);
      expect(DoseTiming.phaseOf(dose, at(-31)), DosePhase.upcomingLocked);
    });
    test('unlocked but still upcoming from −30 to −1', () {
      expect(DoseTiming.phaseOf(dose, at(-30)), DosePhase.upcomingUnlocked);
      expect(DoseTiming.phaseOf(dose, at(-1)), DosePhase.upcomingUnlocked);
    });
    test('"Due now" only from the exact time to +29', () {
      expect(DoseTiming.phaseOf(dose, at(0)), DosePhase.dueNow);
      expect(DoseTiming.phaseOf(dose, at(29)), DosePhase.dueNow);
    });
    test('late from +30 to +59', () {
      expect(DoseTiming.phaseOf(dose, at(30)), DosePhase.late);
      expect(DoseTiming.phaseOf(dose, at(59)), DosePhase.late);
    });
    test('missed from +60', () {
      expect(DoseTiming.phaseOf(dose, at(60)), DosePhase.missed);
      expect(DoseTiming.phaseOf(dose, at(240)), DosePhase.missed);
    });
    test('actions unlock 30 minutes before', () {
      expect(DoseTiming.unlockAt(dose), at(-30));
    });
  });

  group('countdown wording (proposal 6.4)', () {
    String c(int minutes) => DoseTiming.countdown(dose, at(minutes));

    test('whole hours from 2 hours out, rounded down', () {
      expect(c(-180), 'Due in 3 hrs');
      expect(c(-179), 'Due in 2 hrs');
      expect(c(-120), 'Due in 2 hrs');
    });
    test('hour and minutes from 60 to 119', () {
      expect(c(-119), 'Due in 1 hr 59 mins');
      expect(c(-80), 'Due in 1 hr 20 mins');
      expect(c(-61), 'Due in 1 hr 1 min');
      expect(c(-60), 'Due in 1 hr');
    });
    test('minutes from 2 to 59', () {
      expect(c(-59), 'Due in 59 mins');
      expect(c(-15), 'Due in 15 mins');
      expect(c(-2), 'Due in 2 mins');
    });
    test('due now in the last minute and at the time', () {
      expect(c(-1), 'Due now');
      expect(c(0), 'Due now');
    });
    test('minutes ago, then late, then missed', () {
      expect(c(1), 'Due now · 1 min ago');
      expect(c(12), 'Due now · 12 mins ago');
      expect(c(29), 'Due now · 29 mins ago');
      expect(c(30), '30 mins late');
      expect(c(35), '35 mins late');
      expect(c(59), '59 mins late');
      expect(c(60), 'Missed');
    });
  });

  group('early logging (proposal 3.3)', () {
    test('up to 3 hours before', () {
      final ninePm = DateTime(2026, 10, 9, 21);
      expect(
        DoseTiming.checkEarly(ninePm, DateTime(2026, 10, 9, 18)).allowed,
        isTrue,
      );
      final tooEarly = DoseTiming.checkEarly(ninePm, DateTime(2026, 10, 9, 17, 59));
      expect(tooEarly.allowed, isFalse);
      expect(tooEarly.earliest, DateTime(2026, 10, 9, 18));
    });
    test('never more than half the gap to the previous dose', () {
      final noon = DateTime(2026, 10, 9, 12);
      final check = DoseTiming.checkEarly(
        noon,
        DateTime(2026, 10, 9, 9),
        previousDoseAt: DateTime(2026, 10, 9, 8),
      );
      expect(check.allowed, isFalse);
      expect(check.earliest, DateTime(2026, 10, 9, 10));
    });
    test('twice-daily medicines keep the full 3 hours', () {
      final eightPm = DateTime(2026, 10, 9, 20);
      expect(
        DoseTiming.earliestLogAt(eightPm, previousDoseAt: dose),
        DateTime(2026, 10, 9, 17),
      );
    });
    test('crosses midnight', () {
      final halfPastMidnight = DateTime(2026, 10, 10, 0, 30);
      expect(
        DoseTiming.checkEarly(halfPastMidnight, DateTime(2026, 10, 9, 23)).allowed,
        isTrue,
      );
    });
  });

  group('timing tag (proposal 2.5)', () {
    test('early only through the prompt', () {
      expect(
        DoseTiming.timingFor(takenAt: at(-120), scheduledAt: dose, early: true),
        'early',
      );
    });
    test('on time from −30 to +29', () {
      expect(DoseTiming.timingFor(takenAt: at(-30), scheduledAt: dose), 'on_time');
      expect(DoseTiming.timingFor(takenAt: at(29), scheduledAt: dose), 'on_time');
    });
    test('late from +30', () {
      expect(DoseTiming.timingFor(takenAt: at(30), scheduledAt: dose), 'late');
      expect(DoseTiming.timingFor(takenAt: at(59), scheduledAt: dose), 'late');
    });
  });

  group('retro logging window (proposal 7.3)', () {
    test('allowed until the end of the next day', () {
      expect(
        DoseTiming.retroLogAllowed(dose, DateTime(2026, 10, 10, 23, 59)),
        isTrue,
      );
      expect(DoseTiming.retroLogAllowed(dose, DateTime(2026, 10, 11)), isFalse);
      expect(
        DoseTiming.retroLogAllowed(dose, DateTime(2026, 10, 12, 9)),
        isFalse,
      );
    });
  });

  group('spanInWords', () {
    test('hours and minutes with singular forms', () {
      expect(DoseTiming.spanInWords(const Duration(minutes: 130)), '2 hrs 10 mins');
      expect(DoseTiming.spanInWords(const Duration(minutes: 61)), '1 hr 1 min');
      expect(DoseTiming.spanInWords(const Duration(minutes: 120)), '2 hrs');
      expect(DoseTiming.spanInWords(const Duration(minutes: 1)), '1 min');
    });
  });

  group('adherence (proposal 10)', () {
    test('taken ÷ (taken + missed + skipped)', () {
      final stats = AdherenceStats.of([
        log(DoseStatus.taken, timing: 'on_time'),
        log(DoseStatus.taken, timing: 'late'),
        log(DoseStatus.missed, reason: 'Forgot to take'),
        log(DoseStatus.skipped, reason: 'Felt sick / side effects'),
      ]);
      expect(stats.taken, 2);
      expect(stats.resolved, 4);
      expect(stats.adherence, 0.5);
      expect(stats.onTimeRate, 0.5);
      expect(stats.reasons.length, 2);
    });
    test('ignores open, cancelled and mistake doses', () {
      final stats = AdherenceStats.of([
        log(DoseStatus.taken, timing: 'on_time'),
        log(DoseStatus.pending),
        log(DoseStatus.snoozed),
        log(DoseStatus.cancelled),
        log(DoseStatus.missed, excluded: true),
      ]);
      expect(stats.resolved, 1);
      expect(stats.adherence, 1.0);
    });
    test('logged-late counts as taken but not on time', () {
      final stats = AdherenceStats.of([
        log(DoseStatus.taken, timing: 'logged_late'),
        log(DoseStatus.taken, timing: 'early'),
      ]);
      expect(stats.adherence, 1.0);
      expect(stats.loggedLate, 1);
      expect(stats.onTimeRate, 0.5);
    });
    test('old logs without timing are derived from taken_at', () {
      expect(
        AdherenceStats.effectiveTiming(log(DoseStatus.taken, takenAt: at(40))),
        'late',
      );
      expect(
        AdherenceStats.effectiveTiming(log(DoseStatus.taken, takenAt: at(5))),
        'on_time',
      );
    });
    test('nothing resolved reads as 100%', () {
      expect(AdherenceStats.of([log(DoseStatus.pending)]).adherence, 1.0);
    });
  });

  test('deterministic id matches the Worker', () {
    expect(
      DoseLogModel.idFor('sc1', DateTime(2026, 10, 9, 20, 5)),
      'sc1_2026-10-09_20:05',
    );
  });
}
