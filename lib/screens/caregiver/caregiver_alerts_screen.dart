import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import 'missed_alert_screen.dart';

class CaregiverAlertsScreen extends StatelessWidget {
  const CaregiverAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Alerts',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(36),
          child: Padding(
            padding: EdgeInsets.only(left: 20, bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '3 unread',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              _AlertCard(
                color: AppColors.missedRedBg,
                icon: Icons.close,
                title: 'Christian missed metformin',
                subtitle: '8:00 PM dose was not confirmed after 30 minutes.',
                status: '8:30 PM',
                dotColor: AppColors.missedRed,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MissedAlertScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _AlertCard(
                color: AppColors.takenGreenBg,
                icon: Icons.check,
                title: 'Christian took Losartan 50mg',
                subtitle: 'Taken on time. HR at intake: 80 bpm (normal)',
                status: '12:03 PM',
                dotColor: AppColors.caregiverGreen,
              ),
              const SizedBox(height: 12),
              _AlertCard(
                color: AppColors.ledPendingBg,
                icon: Icons.warning_amber_rounded,
                title: 'Elevated heart rate',
                subtitle: '140 bpm at the time of his last dose.',
                status: '7:02 AM',
                dotColor: AppColors.pendingAmber,
              ),
              const SizedBox(height: 12),
              _AlertCard(
                color: AppColors.patientBlue.withOpacity(0.15),
                icon: Icons.info_outline,
                title: 'Low stock on Christian’s Amlodipine',
                subtitle: 'Column 1 has only 4 tablets remaining.',
                status: '6:00 AM',
                dotColor: AppColors.patientBlue,
              ),
              const SizedBox(height: 20),
              const _SectionHeader(label: 'Yesterday'),
              const SizedBox(height: 12),
              _AlertCard(
                color: AppColors.takenGreenBg,
                icon: Icons.check,
                title: 'Christian completed all doses',
                subtitle: 'All 3 medications taken on time',
                status: 'Yesterday',
                dotColor: AppColors.caregiverGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          fontFamily: 'PlusJakartaSans',
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final Color dotColor;
  final VoidCallback? onTap;

  const _AlertCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.dotColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderGray),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
