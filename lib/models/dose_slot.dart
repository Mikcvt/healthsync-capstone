import 'dose_log_model.dart';
import 'schedule_model.dart';

/// One dose of one schedule on one day — what the dashboard lists.
///
/// Built from the schedule (the intent, which always exists) plus its dose log
/// (the event, which the Worker materialises a little ahead of time and may
/// not exist yet). Keying the dashboard on logs alone hid doses the patient
/// could already see on the caregiver's screen.
class DoseSlot {
  final ScheduleModel schedule;

  /// The exact moment this dose is due, on its own day.
  final DateTime scheduledAt;

  /// Null until the Worker (or an action in the app) creates it.
  final DoseLogModel? log;

  const DoseSlot({
    required this.schedule,
    required this.scheduledAt,
    this.log,
  });

  /// The dose log's id: the existing one, or the deterministic id the Worker
  /// would give it.
  String get doseLogId =>
      log?.doseLogId ?? DoseLogModel.idFor(schedule.scheduleId, scheduledAt);

  /// Nothing final recorded yet (no log, pending or snoozed).
  bool get isOpen => log == null || log!.isOpen;
}
