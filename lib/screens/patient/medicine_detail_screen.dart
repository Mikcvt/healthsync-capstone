import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../models/schedule_model.dart';
import '../../providers/patient_provider.dart';
import 'edit_medicine_screen.dart';
import 'delete_medicine_screen.dart';

class MedicineDetailScreen extends StatelessWidget {
  final ScheduleModel? schedule;
  final String? fallbackName;

  const MedicineDetailScreen({
    super.key,
    this.schedule,
    this.fallbackName,
  });

  @override
  Widget build(BuildContext context) {
    final patientProvider = context.watch<PatientProvider>();
    final currentSchedule = schedule ?? (patientProvider.schedules.isNotEmpty ? patientProvider.schedules.first : null);
    final medName = fallbackName ?? 'Medication Details';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          medName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditMedicineScreen(schedule: currentSchedule),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DeleteMedicineScreen(schedule: currentSchedule),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: AppStyles.gradientDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Compartment ${currentSchedule?.matBoxColumn ?? 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (currentSchedule?.ledActive ?? false)
                                ? Colors.orangeAccent
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lightbulb,
                                size: 14,
                                color: (currentSchedule?.ledActive ?? false) ? Colors.white : Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (currentSchedule?.ledActive ?? false) ? 'LED ON' : 'LED OFF',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      medName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scheduled at ${currentSchedule?.scheduledTime ?? "08:00 AM"}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Overview Section
              const Text(
                'SCHEDULE & INVENTORY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: AppStyles.cardDecoration,
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.access_time_rounded,
                      title: 'Dose Time',
                      value: currentSchedule?.scheduledTime ?? '08:00 AM',
                    ),
                    const Divider(height: 20, color: AppColors.borderGray),
                    _DetailRow(
                      icon: Icons.repeat_rounded,
                      title: 'Days of Week',
                      value: currentSchedule != null && currentSchedule.daysOfWeek.length == 7
                          ? 'Every day'
                          : '${currentSchedule?.daysOfWeek.length ?? 7} days / week',
                    ),
                    const Divider(height: 20, color: AppColors.borderGray),
                    _DetailRow(
                      icon: Icons.medical_services_outlined,
                      title: 'Pills Remaining',
                      value: '${currentSchedule?.pillsRemaining ?? 30} pills left',
                    ),
                    const Divider(height: 20, color: AppColors.borderGray),
                    _DetailRow(
                      icon: Icons.warning_amber_rounded,
                      title: 'Low Stock Alert',
                      value: 'Below ${currentSchedule?.lowStockThreshold ?? 5} pills',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Caregiver Doctor Info
              const Text(
                'PRESCRIBER INFO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: AppStyles.cardDecoration,
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.person_pin_circle_outlined,
                      title: 'Doctor / Prescriber',
                      value: currentSchedule?.caregiverDoctor.isNotEmpty == true
                          ? currentSchedule!.caregiverDoctor
                          : 'Attending Physician',
                    ),
                    const Divider(height: 20, color: AppColors.borderGray),
                    _DetailRow(
                      icon: Icons.info_outline,
                      title: 'Smart Reminder',
                      value: 'Enabled on device',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action button
              if (currentSchedule != null)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await patientProvider.confirmDoseTaken(scheduleId: currentSchedule.scheduleId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Dose for $medName marked as taken!'),
                            backgroundColor: AppColors.caregiverGreen,
                          ),
                        );
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text(
                      'Mark Dose as Taken Now',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.caregiverGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.patientBlue),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
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
