import 'package:flutter_test/flutter_test.dart';
import 'package:healthsync/models/dose_log_model.dart';
import 'package:healthsync/models/dose_slot.dart';
import 'package:healthsync/models/schedule_model.dart';
import 'package:healthsync/utils/box_watch.dart';

ScheduleModel _schedule(String id, {int? column = 1}) => ScheduleModel(
      scheduleId: id,
      patMedRef: 'pm_$id',
      scheduledTime: '08:00 AM',
      daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
      matBoxColumn: column,
      startDate: DateTime(2026, 10, 1),
      isActive: true,
    );

DoseSlot _slot(String id, DateTime at, {String? status, int? column = 1}) =>
    DoseSlot(
      schedule: _schedule(id, column: column),
      scheduledAt: at,
      log: status == null
          ? null
          : DoseLogModel(
              doseLogId: DoseLogModel.idFor(id, at),
              scheduleRef: id,
              patientRef: 'p',
              scheduledDate: '2026-11-03',
              scheduledTime: '08:00 AM',
              status: status,
              createdAt: at,
            ),
    );

BoxWatchPlan _plan(List<DoseSlot> slots, DateTime now) =>
    BoxWatchPlan.build(slots, now, inBox: (s) => s.matBoxColumn != null);

void main() {
  final eight = DateTime(2026, 11, 3, 8);
  final eightPm = DateTime(2026, 11, 3, 20);

  test('watches all day until the last box dose is 60 min past', () {
    final plan = _plan([_slot('a', eight), _slot('b', eightPm)],
        DateTime(2026, 11, 3, 6));
    expect(plan.isNeeded, isTrue);
    expect(plan.dueNow, isFalse);
    expect(plan.next, eight);
    expect(plan.until, eightPm.add(const Duration(minutes: 60)));
  });

  test('due from the dose time to +60 min, never before', () {
    final slots = [_slot('a', eight)];
    expect(_plan(slots, eight.subtract(const Duration(minutes: 1))).dueNow,
        isFalse);
    expect(_plan(slots, eight).dueNow, isTrue);
    expect(_plan(slots, eight.add(const Duration(minutes: 59))).dueNow,
        isTrue);
    expect(_plan(slots, eight.add(const Duration(minutes: 60))).isNeeded,
        isFalse);
  });

  test('a recorded dose is no longer watched', () {
    for (final status in [
      DoseStatus.taken,
      DoseStatus.skipped,
      DoseStatus.missed,
    ]) {
      final plan = _plan([_slot('a', eight, status: status)],
          eight.add(const Duration(minutes: 5)));
      expect(plan.isNeeded, isFalse, reason: status);
    }
  });

  test('pending and snoozed doses are still watched', () {
    for (final status in [DoseStatus.pending, DoseStatus.snoozed]) {
      final plan = _plan([_slot('a', eight, status: status)],
          eight.add(const Duration(minutes: 5)));
      expect(plan.dueNow, isTrue, reason: status);
    }
  });

  test('a dose outside the box (no compartment) is not watched', () {
    final plan = _plan([_slot('liquid', eight, column: null)],
        eight.add(const Duration(minutes: 5)));
    expect(plan.isNeeded, isFalse);
  });

  test('a late-evening window runs past midnight', () {
    final late = DateTime(2026, 11, 3, 23, 30);
    final plan = _plan([_slot('a', late)], DateTime(2026, 11, 4, 0, 10));
    expect(plan.dueNow, isTrue);
    expect(plan.until, late.add(const Duration(minutes: 60)));
  });

  test('nothing in the box today: no watch', () {
    expect(_plan(const [], eight).isNeeded, isFalse);
  });
}
