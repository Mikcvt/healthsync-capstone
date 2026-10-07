import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/schedule_model.dart';
import '../utils/date_formatter.dart';

/// Schedules the on-device dose reminders.
///
/// This is the primary reminder path. The Worker's cron is the backstop: it
/// sends a push if the phone never fired locally, which happens whenever an
/// aggressive OEM launcher kills the app. Neither alone is reliable enough for
/// medication adherence — local alarms die with the process, and push needs a
/// network — so both run and the notification id de-duplicates them.
class DoseReminderScheduler {
  static final DoseReminderScheduler _instance =
      DoseReminderScheduler._internal();
  factory DoseReminderScheduler() => _instance;
  DoseReminderScheduler._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Matches `MANILA_UTC_OFFSET_HOURS` in the Worker's materializer. Both sides
  /// must agree on which calendar day a dose belongs to, or the app will remind
  /// for a dose the server filed under a different date.
  static const String _timezone = 'Asia/Manila';

  /// How far ahead to schedule. Android caps pending alarms per app, and the
  /// app re-syncs whenever it opens or a schedule changes, so a long horizon
  /// buys nothing and risks hitting that cap.
  static const int _horizonDays = 7;

  /// Namespaces reminder ids away from the ad-hoc notifications that
  /// [NotificationService.showLocalNotification] posts with arbitrary hashes.
  static const int _idBase = 100000;

  bool _ready = false;

  Future<void> initialize() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_timezone));
    _ready = true;
  }

  /// Asks for the two permissions an exact alarm needs on modern Android.
  ///
  /// Android 13+ requires POST_NOTIFICATIONS at runtime; 14+ requires the user
  /// to grant exact alarms separately. Returns false if reminders cannot fire,
  /// so the caller can tell the patient rather than silently never reminding.
  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;

    final notifications = await android.requestNotificationsPermission();
    final exact = await android.canScheduleExactNotifications();
    if (exact == false) {
      await android.requestExactAlarmsPermission();
    }
    return notifications ?? false;
  }

  /// True when the OS will let us post an exact alarm. Surfaced in settings so
  /// a patient whose reminders are silently disabled can find out why.
  Future<bool> canScheduleExactAlarms() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? false;
  }

  /// A stable id for one dose instance.
  ///
  /// Derived from the schedule and the exact instant, so re-syncing replaces
  /// the same alarm instead of stacking duplicates, and a push carrying the
  /// same dose can reuse it rather than double-notifying.
  static int notificationId(String scheduleId, DateTime at) {
    final key = '$scheduleId|${DateFormatter.toDateKey(at)}|${at.hour}:${at.minute}';
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x3FFFFFF;
    }
    return _idBase + hash;
  }

  /// Rebuilds every pending reminder from [schedules].
  ///
  /// Cancel-then-reschedule rather than diffing: a dose time the caregiver
  /// deleted must not keep firing, and the ids are deterministic so the cost of
  /// rewriting them is a few hundred microseconds.
  Future<void> syncReminders(List<ScheduleModel> schedules) async {
    await initialize();

    try {
      await cancelAll();

      final now = tz.TZDateTime.now(tz.local);
      var scheduled = 0;

      for (final schedule in schedules) {
        if (!schedule.isActive) continue;

        for (var day = 0; day < _horizonDays; day++) {
          final date = now.add(Duration(days: day));
          final instant = _instantFor(schedule, date);
          if (instant == null) continue;
          if (!instant.isAfter(now)) continue;

          await _scheduleOne(schedule, instant);
          scheduled++;
        }
      }

      debugPrint('DoseReminderScheduler: $scheduled reminder(s) scheduled.');
    } catch (e) {
      // A failure here must never break the screen that triggered the sync.
      // The Worker's push backstop still covers the patient.
      debugPrint('DoseReminderScheduler.syncReminders failed: $e');
    }
  }

  /// The exact instant [schedule] falls on [date], or null if it does not run
  /// that day.
  tz.TZDateTime? _instantFor(ScheduleModel schedule, tz.TZDateTime date) {
    // days_of_week uses DateTime.weekday numbering: 1 = Monday, 7 = Sunday.
    if (schedule.daysOfWeek.isNotEmpty &&
        !schedule.daysOfWeek.contains(date.weekday)) {
      return null;
    }

    final dayStart = tz.TZDateTime(tz.local, date.year, date.month, date.day);
    if (dayStart.isBefore(_dateOnly(schedule.startDate))) return null;

    final end = schedule.endDate;
    if (end != null && dayStart.isAfter(_dateOnly(end))) return null;

    final parsed = DateFormatter.parseScheduleTime(schedule.scheduledTime);
    if (parsed == null) return null;

    return tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      parsed.hour,
      parsed.minute,
    );
  }

  tz.TZDateTime _dateOnly(DateTime value) =>
      tz.TZDateTime(tz.local, value.year, value.month, value.day);

  Future<void> _scheduleOne(ScheduleModel schedule, tz.TZDateTime at) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'healthsync_dose_channel',
        'Medication Reminders',
        channelDescription:
            'Notifications for scheduled medication doses and alerts',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        // Survives Do Not Disturb the way an alarm does. A missed dose is the
        // failure this whole app exists to prevent.
        fullScreenIntent: false,
        autoCancel: true,
      ),
    );

    await _plugin.zonedSchedule(
      id: notificationId(schedule.scheduleId, at),
      title: 'Time for your medicine',
      body: 'Compartment ${schedule.matBoxColumn} · ${schedule.scheduledTime}',
      scheduledDate: at,
      notificationDetails: details,
      // exactAllowWhileIdle is the only mode that fires in Doze. inexact
      // scheduling can drift by tens of minutes, which would collide with the
      // 30-minute missed-dose window.
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: schedule.scheduleId,
    );
  }

  /// Clears only reminder ids, leaving any other notification intact.
  Future<void> cancelAll() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id >= _idBase) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  /// Used by the snooze action: re-fire this dose in [delay].
  Future<void> scheduleSnooze({
    required String scheduleId,
    required int matBoxColumn,
    Duration delay = const Duration(minutes: 10),
  }) async {
    await initialize();
    final at = tz.TZDateTime.now(tz.local).add(delay);

    await _plugin.zonedSchedule(
      id: notificationId(scheduleId, at),
      title: 'Snoozed dose',
      body: 'Compartment $matBoxColumn — please take it now.',
      scheduledDate: at,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'healthsync_dose_channel',
          'Medication Reminders',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          autoCancel: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: scheduleId,
    );
  }

  /// Diagnostics for the settings screen.
  Future<int> pendingCount() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.where((r) => r.id >= _idBase).length;
  }
}
