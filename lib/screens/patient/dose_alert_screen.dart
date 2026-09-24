import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/schedule_model.dart';
import '../../providers/patient_provider.dart';
import 'dose_confirmed_screen.dart';

class DoseAlertScreen extends StatelessWidget {
  final ScheduleModel? schedule;
  final String medicineName;
  final String doseTime;
  final int columnNumber;

  const DoseAlertScreen({
    super.key,
    this.schedule,
    this.medicineName = 'Metformin 500mg',
    this.doseTime = '08:00 AM',
    this.columnNumber = 1,
  });

  @override
  Widget build(BuildContext context) {
    final patientProvider = context.read<PatientProvider>();
    final activeCol = schedule?.matBoxColumn ?? columnNumber;
    final activeTime = schedule?.scheduledTime ?? doseTime;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Sleek dark alert theme
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              const Spacer(),
              // Pulsing Alert Ring
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: AppColors.patientBlue.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.patientBlue, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.patientBlue.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.alarm_on_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.patientBlue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'DOSE REMINDER · $activeTime',
                  style: const TextStyle(
                    color: Colors.lightBlueAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                medicineName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'Please take 1 tablet from Compartment $activeCol of your Smart Medicine Box.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.5,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 28),

              // Compartment Indicator Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.amberAccent, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Column $activeCol LED is Flashing',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Primary: Take Dose
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (schedule != null) {
                      await patientProvider.confirmDoseTaken(scheduleId: schedule!.scheduleId);
                    }
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => DoseConfirmedScreen(
                            medicineName: medicineName,
                            timeTaken: 'Just now',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                  label: const Text(
                    'I Took My Dose',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.caregiverGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 4,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Secondary: Snooze & Skip
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Dose snoozed for 10 minutes.')),
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.snooze_rounded, color: Colors.white70, size: 18),
                      label: const Text(
                        'Snooze 10m',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
                      label: const Text(
                        'Dismiss',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
