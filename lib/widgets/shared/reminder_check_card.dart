import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../services/device_settings_service.dart';
import '../../services/dose_reminder_scheduler.dart';
import '../../services/reminder_health_service.dart';

/// Shows whether this phone lets reminders (or, for a caregiver, alerts)
/// actually ring, with a Fix button for each problem.
///
/// Re-checks whenever the app comes back to the foreground, so returning from
/// the settings screen a Fix button opened updates the card at once.
class ReminderCheckCard extends StatefulWidget {
  /// Render nothing while everything is fine — for the dashboard, where a
  /// healthy phone should not cost any space.
  final bool onlyWhenProblem;

  /// Called after every check, e.g. to report the result for the caregiver.
  final ValueChanged<ReminderHealth>? onChecked;

  /// For a caregiver. Their alerts are pushes, not alarms scheduled on the
  /// phone, so only notifications (and the vendor auto-start advice) matter;
  /// the alarm and battery rows would only mislead.
  final bool forCaregiverAlerts;

  const ReminderCheckCard({
    super.key,
    this.onlyWhenProblem = false,
    this.onChecked,
    this.forCaregiverAlerts = false,
  });

  @override
  State<ReminderCheckCard> createState() => _ReminderCheckCardState();
}

class _ReminderCheckCardState extends State<ReminderCheckCard>
    with WidgetsBindingObserver {
  ReminderHealth? _health;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final health = await ReminderHealthService().check();
    if (!mounted) return;
    setState(() => _health = health);
    widget.onChecked?.call(health);
  }

  Future<void> _fixNotifications() async {
    final granted =
        await DoseReminderScheduler().requestNotificationPermission();
    // After a couple of refusals Android stops showing the prompt; the app's
    // settings page is the only way left.
    if (!granted) await DeviceSettingsService().openAppSettings();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final health = _health;
    if (health == null) return const SizedBox.shrink();
    final alertsOnly = widget.forCaregiverAlerts;
    final allOk = alertsOnly ? health.notifications : health.allOk;
    if (widget.onlyWhenProblem && allOk) return const SizedBox.shrink();

    final noun = alertsOnly ? 'alerts' : 'reminders';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.cardDecoration.copyWith(
        border: Border.all(
          color: allOk
              ? AppColors.borderGray
              : AppColors.pendingAmber.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            allOk
                ? 'This phone is ready for $noun'
                : 'Your $noun may not ring on this phone',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _CheckRow(
            ok: health.notifications,
            okText: 'Notifications are allowed',
            problemText: 'Notifications are turned off',
            onFix: _fixNotifications,
          ),
          if (!alertsOnly) ...[
          _CheckRow(
            ok: health.exactAlarms,
            okText: 'Alarms can ring on time',
            problemText: 'Alarms may ring late',
            onFix: () async {
              await DoseReminderScheduler().requestExactAlarmPermission();
              await _refresh();
            },
          ),
          _CheckRow(
            ok: health.battery,
            okText: 'Battery saver will not hold $noun',
            problemText: 'Battery saver can delay $noun',
            fixHint: 'Find HealthSync and choose "Don\'t optimise"',
            onFix: () async {
              await DeviceSettingsService().openBatteryOptimizationSettings();
            },
          ),
          ],
          if (health.vendorAutostartHint)
            _CheckRow(
              ok: null,
              okText: '',
              problemText: 'Also allow HealthSync to auto-start',
              fixHint: 'This phone brand can stop apps in the background',
              fixLabel: 'Open',
              onFix: () async {
                await DeviceSettingsService().openBackgroundSettings();
              },
            ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  /// true = fine, false = a problem, null = advice that cannot be checked.
  final bool? ok;
  final String okText;
  final String problemText;
  final String? fixHint;
  final String fixLabel;
  final Future<void> Function() onFix;

  const _CheckRow({
    required this.ok,
    required this.okText,
    required this.problemText,
    required this.onFix,
    this.fixHint,
    this.fixLabel = 'Fix',
  });

  @override
  Widget build(BuildContext context) {
    final isOk = ok == true;
    final (icon, color) = switch (ok) {
      true => (Icons.check_circle_rounded, AppColors.takenGreen),
      false => (Icons.warning_amber_rounded, AppColors.pendingAmber),
      null => (Icons.info_outline_rounded, AppColors.upcomingBlue),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOk ? okText : problemText,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (!isOk && fixHint != null)
                  Text(
                    fixHint!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (!isOk)
            TextButton(
              onPressed: onFix,
              child: Text(
                fixLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
