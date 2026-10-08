import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/patient_provider.dart';
import '../../services/device_settings_service.dart';
import '../../services/dose_launch_router.dart';
import '../../services/preferences_service.dart';
import '../../widgets/shared/floating_nav_bar.dart';
import 'dose_alert_screen.dart';
import 'medicine_box_status_screen.dart';
import 'notifications_screen.dart';
import 'patient_dashboard_screen.dart';
import 'patient_profile_screen.dart';
import 'schedule_screen.dart';

class PatientMainScreen extends StatefulWidget {
  const PatientMainScreen({super.key});

  @override
  State<PatientMainScreen> createState() => _PatientMainScreenState();
}

class _PatientMainScreenState extends State<PatientMainScreen> {
  int _selectedIndex = 0;
  bool _openingAlarm = false;

  // Five tabs per the spec — Box was previously unreachable from the nav even
  // though the screen existed.
  static const List<Widget> _screens = [
    PatientDashboardScreen(),
    ScheduleScreen(),
    MedicineBoxStatusScreen(),
    NotificationsScreen(),
    PatientProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    DoseLaunchRouter.instance.pendingScheduleId.addListener(_openPendingAlarm);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openPendingAlarm();
      _maybeShowBackgroundHint();
    });
  }

  @override
  void dispose() {
    DoseLaunchRouter.instance.pendingScheduleId
        .removeListener(_openPendingAlarm);
    super.dispose();
  }

  /// Opens the alarm screen for a tapped reminder — the only place Snooze is
  /// offered. Waits for the patient's data, since a cold start can get here
  /// before the schedules have loaded; the build below retries once they do.
  void _openPendingAlarm() {
    if (!mounted || _openingAlarm) return;
    final router = DoseLaunchRouter.instance;
    if (router.pendingScheduleId.value == null) return;

    final patient = context.read<PatientProvider>();
    if (patient.isLoading) return;

    final scheduleId = router.take()!;
    // A reminder for a medicine archived since it was scheduled, or for
    // another account on this phone, has nothing to open.
    if (patient.todaySlotFor(scheduleId) == null) return;

    _openingAlarm = true;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => DoseAlertScreen(scheduleId: scheduleId),
          ),
        )
        .whenComplete(() => _openingAlarm = false);
  }

  /// A one-time hint on phones whose battery savers stop reminders from
  /// firing (DOSE_LOGIC_PROPOSAL.md, 5.2 step 3).
  Future<void> _maybeShowBackgroundHint() async {
    final prefs = PreferencesService();
    final device = DeviceSettingsService();
    if (await prefs.backgroundHintShown()) return;
    if (!await device.needsBackgroundHint()) return;
    if (!mounted) return;

    await prefs.setBackgroundHintShown();
    if (!mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Keep your reminders on time',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: const Text(
          'This phone can stop apps running in the background to save battery, '
          'which can stop dose reminders from ringing.\n\n'
          'Open settings and allow HealthSync to start automatically and run '
          'in the background.',
          style: TextStyle(
            height: 1.5,
            color: AppColors.textSecondary,
            fontFamily: AppStyles.fontFamily,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Open settings',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (open == true) await device.openBackgroundSettings();
  }

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<PatientProvider>();
    final unread = patient.unreadNotificationCount;

    // A reminder tapped during a cold start waits for the data to load; this
    // rebuild is the signal that it has.
    if (!patient.isLoading &&
        DoseLaunchRouter.instance.pendingScheduleId.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingAlarm());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: _screens[_selectedIndex],
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        accent: AppColors.patientBlue,
        destinations: [
          const NavDestination(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
          ),
          const NavDestination(
            icon: Icons.calendar_today_outlined,
            activeIcon: Icons.calendar_today_rounded,
            label: 'Schedule',
          ),
          const NavDestination(
            icon: Icons.widgets_outlined,
            activeIcon: Icons.widgets_rounded,
            label: 'Box',
          ),
          NavDestination(
            icon: Icons.notifications_none_rounded,
            activeIcon: Icons.notifications_rounded,
            label: 'Alerts',
            badgeCount: unread,
          ),
          const NavDestination(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Profile',
            isAvatar: true,
          ),
        ],
      ),
    );
  }
}
