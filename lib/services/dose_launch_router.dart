import 'package:flutter/foundation.dart';

/// Carries a tapped dose reminder to the alarm screen
/// (DOSE_LOGIC_PROPOSAL.md, 5.2 steps 1–2).
///
/// A notification can be tapped before any screen exists — the app may have
/// been closed — so the tap is parked here as the reminder's schedule id. The
/// patient's main screen opens the alarm screen once the patient's data has
/// loaded, and clears the request.
class DoseLaunchRouter {
  DoseLaunchRouter._();
  static final DoseLaunchRouter instance = DoseLaunchRouter._();

  /// The schedule id of a tapped reminder still waiting to be opened.
  final ValueNotifier<String?> pendingScheduleId = ValueNotifier<String?>(null);

  /// A dose-log id: `{scheduleId}_{YYYY-MM-DD}_{HH:mm}`.
  static final RegExp _doseLogId =
      RegExp(r'^(.+)_\d{4}-\d{2}-\d{2}_\d{2}:\d{2}$');

  /// Records a tapped reminder. Local reminders carry a schedule id; pushes
  /// carry a dose-log id, which starts with one. Anything empty is ignored.
  void open(String? payload) {
    final text = payload?.trim() ?? '';
    if (text.isEmpty) return;
    pendingScheduleId.value = _doseLogId.firstMatch(text)?.group(1) ?? text;
  }

  /// Returns and clears the waiting request.
  String? take() {
    final id = pendingScheduleId.value;
    pendingScheduleId.value = null;
    return id;
  }
}
