import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../providers/caregiver_provider.dart';
import '../../widgets/shared/floating_nav_bar.dart';
import 'caregiver_alerts_screen.dart';
import 'caregiver_dashboard_screen.dart';
import 'caregiver_settings_screen.dart';
import 'my_patients_screen.dart';
import 'reports_screen.dart';

class CaregiverMainScreen extends StatefulWidget {
  const CaregiverMainScreen({super.key});

  @override
  State<CaregiverMainScreen> createState() => _CaregiverMainScreenState();
}

class _CaregiverMainScreenState extends State<CaregiverMainScreen> {
  int _selectedIndex = 0;

  // Five tabs, matching the spec. Alerts was missing entirely, so missed-dose
  // notifications had nowhere to surface.
  static const List<Widget> _screens = [
    CaregiverDashboardScreen(),
    MyPatientsScreen(),
    CaregiverAlertsScreen(),
    ReportsScreen(),
    CaregiverSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<CaregiverProvider>().unreadNotificationCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      // extendBody lets the content scroll underneath the floating bar instead
      // of stopping short of it.
      extendBody: true,
      body: _screens[_selectedIndex],
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        accent: AppColors.caregiverGreen,
        destinations: [
          const NavDestination(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
          ),
          const NavDestination(
            icon: Icons.group_outlined,
            activeIcon: Icons.group,
            label: 'Patients',
          ),
          NavDestination(
            icon: Icons.notifications_none_rounded,
            activeIcon: Icons.notifications_rounded,
            label: 'Alerts',
            badgeCount: unread,
          ),
          const NavDestination(
            icon: Icons.bar_chart_outlined,
            activeIcon: Icons.bar_chart,
            label: 'Reports',
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
