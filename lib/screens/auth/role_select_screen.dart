import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'register_screen.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text('Choose your role', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'PlusJakartaSans')),
              const SizedBox(height: 8),
              const Text('Select how you want to use HealthSync.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'PlusJakartaSans', height: 1.5)),
              const SizedBox(height: 24),
              _RoleCard(
                title: 'Patient',
                subtitle: 'Track medications, confirm doses, and view your adherence progress.',
                icon: Icons.person_outline_rounded,
                color: AppColors.patientBlue,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen(role: 'patient'))),
              ),
              const SizedBox(height: 14),
              _RoleCard(
                title: 'Caregiver',
                subtitle: 'Monitor loved ones, receive alerts, and stay on top of schedules.',
                icon: Icons.groups_2_outlined,
                color: AppColors.caregiverGreen,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen(role: 'caregiver'))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontFamily: 'PlusJakartaSans',
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
