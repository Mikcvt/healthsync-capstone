import 'package:flutter_test/flutter_test.dart';
import 'package:healthsync/models/box_messages.dart';
import 'package:healthsync/models/dose_log_model.dart';
import 'package:healthsync/models/schedule_model.dart';
import 'package:healthsync/services/box_link_service.dart';
import 'package:healthsync/utils/box_schedule.dart';

ScheduleModel _schedule(
  String id, {
  String time = '08:00 AM',
  int? column = 1,
  List<int> days = const [1, 2, 3, 4, 5, 6, 7],
  DateTime? start,
  DateTime? end,
  bool active = true,
}) =>
    ScheduleModel(
      scheduleId: id,
      patMedRef: 'pm_$id',
      scheduledTime: time,
      daysOfWeek: days,
      matBoxColumn: column,
      startDate: start ?? DateTime(2026, 10, 1),
      endDate: end,
      isActive: active,
    );

void main() {
  final today = DateTime(2026, 10, 27, 9, 30);

  group('BoxSchedulePlan', () {
    test('sends only dose times in a compartment, as 24-hour HH:MM', () {
      final plan = BoxSchedulePlan.build([
        _schedule('a', time: '08:00 PM', column: 3),
        _schedule('b', time: '7:05 am', column: 1, days: [1, 3, 5]),
        _schedule('liquid', column: null),
      ], today: today);

      expect(plan.items, [
        const BoxScheduleItem(
            scheduleId: 'b', compartment: 1, time: '07:05', days: [1, 3, 5]),
        // All seven days go as "every day".
        const BoxScheduleItem(
            scheduleId: 'a', compartment: 3, time: '20:00', days: []),
      ]);
      expect(plan.leftOut, 0);
    });

    test('12 AM and 12 PM are midnight and noon', () {
      final plan = BoxSchedulePlan.build([
        _schedule('m', time: '12:00 AM'),
        _schedule('n', time: '12:30 PM'),
      ], today: today);
      expect(plan.items.map((i) => i.time), ['00:00', '12:30']);
    });

    test('leaves out ended, not-yet-started and inactive dose times', () {
      final plan = BoxSchedulePlan.build([
        _schedule('ended', end: DateTime(2026, 10, 26)),
        _schedule('endsToday', end: DateTime(2026, 10, 27)),
        _schedule('later', start: DateTime(2026, 10, 28)),
        _schedule('off', active: false),
      ], today: today);
      expect(plan.items.map((i) => i.scheduleId), ['endsToday']);
    });

    test('keeps 24 dose times, the most the box holds', () {
      final schedules = [
        for (var i = 0; i < 26; i++)
          _schedule('s${i.toString().padLeft(2, '0')}',
              time: '${(i % 12) + 1}:00 AM'),
      ];
      final plan = BoxSchedulePlan.build(schedules, today: today);
      expect(plan.items.length, BoxSchedulePlan.maxItems);
      expect(plan.leftOut, 2);
    });

    test('the version changes with anything the box uses, and only then', () {
      final base = BoxSchedulePlan.build(
          [_schedule('a', column: 2)], today: today);
      final same = BoxSchedulePlan.build(
          [_schedule('a', column: 2)], today: today.add(const Duration(hours: 3)));
      final moved = BoxSchedulePlan.build(
          [_schedule('a', column: 4)], today: today);
      final retimed = BoxSchedulePlan.build(
          [_schedule('a', column: 2, time: '08:30 AM')], today: today);

      expect(same.version, base.version);
      expect(moved.version, isNot(base.version));
      expect(retimed.version, isNot(base.version));
      // sched_begin accepts at most 31 characters.
      expect(base.version.length, lessThanOrEqualTo(31));
      expect(base.version, startsWith('hs1-'));
    });

    test('an empty box has a version too, so it can be cleared', () {
      final plan = BoxSchedulePlan.build([], today: today);
      expect(plan.items, isEmpty);
      expect(plan.version, startsWith('hs1-'));
    });
  });

  group('BoxEvent', () {
    final json = {
      'seq': 7,
      'type': 'taken',
      'comp': 3,
      'date': '2026-10-24',
      'time': '08:00',
      'at': '2026-10-24T00:04:31Z',
      'timing': 'on_time',
      'sid': 'sc_K3pT8mQa',
    };

    test('parses the example in BLE_PROTOCOL.md', () {
      final e = BoxEvent.fromJson(json);
      expect(e.seq, 7);
      expect(e.isTaken, isTrue);
      expect(e.compartment, 3);
      expect(e.timing, 'on_time');
      expect(e.at, DateTime.utc(2026, 10, 24, 0, 4, 31).toLocal());
    });

    test('names the same dose log the app and the Worker use', () {
      final e = BoxEvent.fromJson(json);
      expect(e.scheduledAt, DateTime(2026, 10, 24, 8, 0));
      expect(e.doseLogId, DoseLogModel.idFor('sc_K3pT8mQa', e.scheduledAt!));
    });

    test('a console dose time has no dose log', () {
      final e = BoxEvent.fromJson({...json, 'sid': ''});
      expect(e.doseLogId, isNull);
    });

    test('a missed event has no press time and no timing', () {
      final e = BoxEvent.fromJson({
        'seq': 8,
        'type': 'missed',
        'comp': 1,
        'date': '2026-10-24',
        'time': '20:00',
        'at': '2026-10-24T13:00:00Z',
        'timing': '',
        'sid': 'x',
      });
      expect(e.isMissed, isTrue);
      expect(e.timing, isEmpty);
    });
  });

  group('BoxHello', () {
    test('parses the example in BLE_PROTOCOL.md', () {
      final hello = BoxHello.fromJson({
        'op': 'hello',
        'serial': 'HS-0001',
        'fw': '0.3.0',
        'utc': 1761300000,
        'clock_ok': true,
        'sched_ver': '2026-10-24T09:41:00Z',
        'count': 3,
        'last_seq': 6,
        'acked': 2,
        'pending': 4,
        'sd': true,
      });
      expect(hello.serial, 'HS-0001');
      expect(hello.clockOk, isTrue);
      expect(hello.acked, 2);
      expect(hello.lastSeq, 6);
      expect(hello.scheduleVersion, '2026-10-24T09:41:00Z');
    });
  });

  test('the advertised name gives the serial', () {
    expect(BoxLinkService.serialFromName('HealthSync-0001'), 'HS-0001');
    expect(BoxLinkService.serialFromName('HealthSync-12'), isNull);
    expect(BoxLinkService.serialFromName('Speaker'), isNull);
  });
}
