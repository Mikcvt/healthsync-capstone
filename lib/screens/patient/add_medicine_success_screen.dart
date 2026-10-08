import '../../constants/app_strings.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';

class AddMedicineSuccessScreen extends StatelessWidget {
  final String medicineName;

  /// The compartment it was placed in, or null when it is not in the box.
  final int? columnNumber;
  final List<String> scheduledTimes;

  /// Whether the patient has a box at all, which changes what "not in a
  /// compartment" means: no box yet, or deliberately kept outside it.
  final bool hasBox;

  const AddMedicineSuccessScreen({
    super.key,
    required this.medicineName,
    required this.columnNumber,
    required this.scheduledTimes,
    this.hasBox = true,
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
                columnNumber != null
                    ? '$medicineName is on the schedule. Compartment $columnNumber will light up at each dose time.'
                    : '$medicineName is on the schedule. Reminders will come on the phone at each dose time.',
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
                      label: 'Kept in',
                      value: columnNumber != null
                          ? 'Compartment $columnNumber'
                          : hasBox
                              ? 'Outside the box'
                              : 'Its own pack',
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
                      label: 'Reminder',
                      value: columnNumber != null
                          ? 'Phone + box light'
                          : 'Phone notification',
                      icon: columnNumber != null
                          ? Icons.lightbulb_outline_rounded
                          : Icons.phone_android_rounded,
                    ),
                  ],
                ),
              ),
              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  // Leaves the whole wizard, not just this screen. A plain
                  // pop() dropped the user back on step 2, because step 3 was
                  // replaced by this screen rather than stacked on top of it.
                  onPressed: () => Navigator.of(context).popUntil(
                    (route) => route.settings.name != addMedicineFlowRoute,
                  ),
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
        const SizedBox(width: 12),
        // Flexible so four or five dose times wrap instead of overflowing.
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
        ),
      ],
    );
  }
}
