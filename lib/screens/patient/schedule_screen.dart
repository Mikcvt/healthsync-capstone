import '../../widgets/shared/floating_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/patient_provider.dart';
import 'medicine_detail_screen.dart';
import '../../widgets/shared/medicine_badge.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final patientProvider = context.watch<PatientProvider>();
    final schedules = patientProvider.schedules;
    final medications = patientProvider.medications;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Medication Schedule',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ),
      body: SafeArea(
        child: schedules.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.patientBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.calendar_month_outlined, size: 40, color: AppColors.patientBlue),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No Schedules Yet',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your caregiver has not added any medicines yet. They will appear here as soon as they do.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, FloatingNavBar.contentPadding),
                itemCount: schedules.length,
                itemBuilder: (ctx, index) {
                  final sch = schedules[index];
                  final matchingMed = medications.where((m) => m.patMedId == sch.patMedRef).firstOrNull;
                  final medName = matchingMed?.medicationName.isNotEmpty == true
                      ? matchingMed!.medicationName
                      : 'Prescription ${index + 1}';
                  final showCol = patientProvider.showsCompartment(sch);

                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MedicineDetailScreen(
                            schedule: sch,
                            fallbackName: medName,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: AppStyles.cardDecoration,
                      child: Row(
                        children: [
                          MedicineBadge(
                            column: showCol ? sch.matBoxColumn : null,
                            dosageForm: matchingMed?.dosageForm ?? 'Tablet',
                            size: 52,
                            foreground: AppColors.patientBlue,
                            background: AppColors.patientBlue.withValues(alpha: 0.12),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  medName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    fontFamily: 'PlusJakartaSans',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  showCol
                                      ? '${sch.scheduledTime} · ${sch.pillsRemaining} left'
                                      : '${sch.scheduledTime} · ${patientProvider.doseInstructionFor(sch)} · ${sch.pillsRemaining} left',
                                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
