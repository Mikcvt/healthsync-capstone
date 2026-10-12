import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'package:provider/provider.dart';
import '../../constants/app_styles.dart';
import '../../providers/patient_provider.dart';

class DoseConfirmedScreen extends StatelessWidget {
  final String medicineName;
  final String timeTaken;

  const DoseConfirmedScreen({
    super.key,
    this.medicineName = 'Your medication',
    this.timeTaken = 'Just now',
  });

  @override
  Widget build(BuildContext context) {
    final linked = context.watch<PatientProvider>().isLinkedToCaregiver;
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
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.blueLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: AppColors.patientBlue,
                  size: 54,
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                'Dose Recorded!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 10),

              Text(
                'Great job! You took $medicineName at $timeTaken. Your daily adherence is updated'
                '${linked ? ' and your care partner can see it.' : '.'}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 32),

              if (linked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: AppStyles.cardDecoration,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.patientBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.favorite_rounded, color: AppColors.patientBlue),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shared with your Care Partner',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'They see this dose on their dashboard',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
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
                    'Back to Today',
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
