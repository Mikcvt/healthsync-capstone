import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class CaregiverSettingsScreen extends StatelessWidget {
  const CaregiverSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Caregiver settings will appear here.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You can manage your profile, notifications, and app preferences from this screen.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
