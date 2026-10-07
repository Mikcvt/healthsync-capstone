import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../providers/patient_provider.dart';
import '../../widgets/shared/floating_nav_bar.dart';
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
  Widget build(BuildContext context) {
    final unread = context.watch<PatientProvider>().unreadNotificationCount;

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
