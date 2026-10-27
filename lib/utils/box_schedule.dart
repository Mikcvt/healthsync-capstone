import '../models/box_messages.dart';
import '../models/schedule_model.dart';
import 'date_formatter.dart';

/// The schedule the medicine box should hold, built from the patient's
/// schedules, and a version for it.
///
/// The box keeps whatever the phone last sent (BLE_CONNECT_ON_DEMAND.md, M4:
/// the phone wins). The version is a hash of exactly what is sent, so any
/// change that matters to the box changes it: a dose time, a day, a
/// compartment, a medicine that started, ended or left the box. Comparing it
/// with the version the box reports avoids resending an unchanged schedule.
/// `schedules.updated_at` could not serve: moving a compartment does not
/// stamp it.
class BoxSchedulePlan {
  /// The most dose times the box stores (MAX_SCHEDULES in the firmware).
  static const maxItems = 24;

  /// What the box gets, earliest time of day first.
  final List<BoxScheduleItem> items;

  /// Sent with `sched_begin`, at most 31 characters.
  final String version;

  /// Dose times that would have gone in but did not fit in [maxItems].
  /// They stay phone-only reminders.
  final int leftOut;

  const BoxSchedulePlan._(this.items, this.version, this.leftOut);

  /// Only dose times in a compartment (1–[ScheduleModel.boxCompartments]),
  /// running on [today] or later: started, not ended, still active. A
  /// medicine that starts tomorrow is sent at the first sync on or after
  /// its start date.
  factory BoxSchedulePlan.build(
    List<ScheduleModel> schedules, {
    required DateTime today,
  }) {
    final day = DateFormatter.startOfDay(today);
    final items = <BoxScheduleItem>[];
    for (final s in schedules) {
      final compartment = s.matBoxColumn;
      if (!s.isActive || compartment == null) continue;
      if (DateFormatter.startOfDay(s.startDate).isAfter(day)) continue;
      final end = s.endDate;
      if (end != null && day.isAfter(DateFormatter.startOfDay(end))) continue;
      // The box keeps 24 characters of the id; a longer one could never
      // match the dose log it belongs to. Firestore ids are 20.
      if (s.scheduleId.isEmpty || s.scheduleId.length > 24) continue;
      final at = DateFormatter.parseScheduleTime(s.scheduledTime, onDate: day);
      if (at == null) continue;

      final days = s.daysOfWeek.where((d) => d >= 1 && d <= 7).toSet().toList()
        ..sort();
      items.add(BoxScheduleItem(
        scheduleId: s.scheduleId,
        compartment: compartment,
        time: '${_two(at.hour)}:${_two(at.minute)}',
        // All seven days and none mean the same to the box.
        days: days.length == 7 ? const [] : days,
      ));
    }

    items.sort((a, b) {
      final byTime = a.time.compareTo(b.time);
      return byTime != 0 ? byTime : a.scheduleId.compareTo(b.scheduleId);
    });
    final leftOut = items.length > maxItems ? items.length - maxItems : 0;
    final kept = items.take(maxItems).toList();
    return BoxSchedulePlan._(kept, versionOf(kept), leftOut);
  }

  /// `hs1-` and 16 hex digits: FNV-1a (64-bit) of the items in order.
  static String versionOf(List<BoxScheduleItem> items) {
    final text = items
        .map((i) => '${i.scheduleId}|${i.compartment}|${i.time}|'
            '${i.days.join(',')}')
        .join(';');
    // FNV-1a, 64-bit. Dart integers on Android are 64-bit and wrap on
    // overflow, which is exactly the arithmetic FNV expects.
    var hash = 0xcbf29ce484222325;
    for (final unit in text.codeUnits) {
      hash ^= unit;
      hash *= 0x100000001b3;
    }
    final hex = hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
    return 'hs1-$hex';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
