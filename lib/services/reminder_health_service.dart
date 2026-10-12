import 'device_settings_service.dart';
import 'dose_reminder_scheduler.dart';

/// What this phone allows, as far as reminders go.
class ReminderHealth {
  /// The OS shows HealthSync's notifications.
  final bool notifications;

  /// Exact alarms are allowed (Android 12+), so reminders ring on time.
  final bool exactAlarms;

  /// Battery optimisation is off for HealthSync, so Doze cannot hold them.
  final bool battery;

  /// A Xiaomi, Oppo or Vivo-family phone, whose own auto-start switch also
  /// matters. Android cannot report that switch, so it is advice, not a check.
  final bool vendorAutostartHint;

  const ReminderHealth({
    required this.notifications,
    required this.exactAlarms,
    required this.battery,
    required this.vendorAutostartHint,
  });

  bool get allOk => notifications && exactAlarms && battery;
}

/// Checks whether reminders can actually fire on this phone.
///
/// Reminders are scheduled on the phone, not sent from a server. If any of
/// these is blocked they fail silently, which the caregiver also cannot see —
/// so the patient app reports the result (FirestoreService.reportReminderHealth).
class ReminderHealthService {
  static final ReminderHealthService _instance = ReminderHealthService._();
  factory ReminderHealthService() => _instance;
  ReminderHealthService._();

  Future<ReminderHealth> check() async {
    final scheduler = DoseReminderScheduler();
    final device = DeviceSettingsService();
    final results = await Future.wait([
      scheduler.notificationsEnabled(),
      scheduler.canScheduleExactAlarms(),
      device.isIgnoringBatteryOptimizations(),
      device.needsBackgroundHint(),
    ]);
    return ReminderHealth(
      notifications: results[0],
      exactAlarms: results[1],
      battery: results[2],
      vendorAutostartHint: results[3],
    );
  }
}
