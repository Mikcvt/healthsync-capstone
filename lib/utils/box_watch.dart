import '../models/dose_slot.dart';
import '../models/schedule_model.dart';
import 'dose_timing.dart';

/// When this phone keeps watching the medicine box in the background
/// (BoxProvider, Nov 3, 2026).
///
/// A box dose is watched from its time until it is recorded or missed
/// (+60 min): the box lights it at its time and takes it with the button
/// only then, never early. While one is due the phone syncs every minute, so
/// a button press reaches the app without the Sync button.
class BoxWatchPlan {
  /// The last moment anything is still watched; null = nothing left today.
  final DateTime? until;

  /// A box dose is due right now: sync every minute.
  final bool dueNow;

  /// The next box dose still to come, for the notification text.
  final DateTime? next;

  const BoxWatchPlan({this.until, this.dueNow = false, this.next});

  bool get isNeeded => until != null;

  /// From the doses of yesterday and today (a late-evening window runs past
  /// midnight). [inBox] is PatientProvider.showsCompartment.
  factory BoxWatchPlan.build(
    Iterable<DoseSlot> slots,
    DateTime now, {
    required bool Function(ScheduleModel) inBox,
  }) {
    DateTime? until;
    DateTime? next;
    var dueNow = false;
    for (final slot in slots) {
      if (!slot.isOpen || !inBox(slot.schedule)) continue;
      final at = slot.scheduledAt;
      final end = at.add(DoseTiming.missedAfter);
      if (!now.isBefore(end)) continue;
      if (until == null || end.isAfter(until)) until = end;
      if (now.isBefore(at)) {
        if (next == null || at.isBefore(next)) next = at;
      } else {
        dueNow = true;
      }
    }
    return BoxWatchPlan(until: until, dueNow: dueNow, next: next);
  }
}
