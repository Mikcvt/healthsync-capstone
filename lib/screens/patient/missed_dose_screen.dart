import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class MissedDoseScreen extends StatefulWidget {
  final String medicineName;
  final String scheduledTime;

  const MissedDoseScreen({
    super.key,
    this.medicineName = 'Metformin 500mg',
    this.scheduledTime = '08:00 AM',
  });

  @override
  State<MissedDoseScreen> createState() => _MissedDoseScreenState();
}

class _MissedDoseScreenState extends State<MissedDoseScreen> {
  String _selectedReason = 'Forgot to take';
  final List<String> _reasons = [
    'Forgot to take',
    'Felt sick / side effects',
    'Was away from medicine box',
    'Prescription ran out',
    'Other reason',
  ];

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
        title: const Text(
          'Missed Dose Alert',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.medicineName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scheduled for ${widget.scheduledTime}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Select Reason for Missing Dose',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'This will be shared with your caregiver so they can provide support if needed.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              ..._reasons.map((r) {
                final isSelected = _selectedReason == r;
                return GestureDetector(
                  onTap: () => setState(() => _selectedReason = r),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.patientBlue.withOpacity(0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.patientBlue : AppColors.borderGray,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? AppColors.patientBlue : AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            r,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: isSelected ? AppColors.patientBlue : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Missed dose reason recorded.')),
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.patientBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Log Reason & Dismiss', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
