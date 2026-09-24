import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';

class AddMedicineSuccessScreen extends StatelessWidget {
  final String medicineName;
  final int columnNumber;
  final List<String> scheduledTimes;

  const AddMedicineSuccessScreen({
    super.key,
    required this.medicineName,
    required this.columnNumber,
    required this.scheduledTimes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.ledDoneBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.caregiverGreen,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Medication Added!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$medicineName has been successfully configured and synced with your schedule.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 32),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: AppStyles.cardDecoration,
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Assigned Compartment',
                      value: 'Column $columnNumber',
                      icon: Icons.view_column_rounded,
                    ),
                    const Divider(height: 24, color: AppColors.borderGray),
                    _InfoRow(
                      label: 'Scheduled Times',
                      value: scheduledTimes.join(', '),
                      icon: Icons.access_time_rounded,
                    ),
                    const Divider(height: 24, color: AppColors.borderGray),
                    _InfoRow(
                      label: 'LED Reminder',
                      value: 'Auto-activates on time',
                      icon: Icons.lightbulb_outline_rounded,
                    ),
                  ],
                ),
              ),
              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.patientBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'Done · View Schedule',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.patientBlue),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
      ],
    );
  }
}
