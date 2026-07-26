import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'caregiver_dashboard_screen.dart';
import 'my_patients_screen.dart';
import 'reports_screen.dart';
import 'caregiver_settings_screen.dart';

class CaregiverMainScreen extends StatefulWidget {
  const CaregiverMainScreen({super.key});

  @override
  State<CaregiverMainScreen> createState() => _CaregiverMainScreenState();
}

class _CaregiverMainScreenState extends State<CaregiverMainScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _screens = [
    const CaregiverDashboardScreen(),
    const MyPatientsScreen(),
    const ReportsScreen(),
    const CaregiverSettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.caregiverGreen,
        unselectedItemColor: AppColors.textSecondary,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined),
            activeIcon: Icon(Icons.group),
            label: 'Patients',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
