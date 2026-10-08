import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../models/schedule_model.dart';
import '../../providers/patient_provider.dart';
import '../../constants/app_strings.dart';
import '../../widgets/patient/dose_actions.dart';
import '../../utils/dose_timing.dart';
import '../../utils/dose_status_display.dart';
import '../../utils/date_formatter.dart';

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
    // The live copy, so the pill count and the out-of-stock guard reflect the
    // dose just confirmed rather than the snapshot this screen opened with.
    final currentSchedule = schedule == null
        ? (patientProvider.schedules.isNotEmpty ? patientProvider.schedules.first : null)
        : patientProvider.scheduleById(schedule!.scheduleId) ?? schedule;
    final outOfStock = (currentSchedule?.pillsRemaining ?? 1) <= 0;
    final inBox = currentSchedule != null &&
        patientProvider.showsCompartment(currentSchedule);
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
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            inBox
                                ? 'Compartment ${currentSchedule.matBoxColumn}'
                                : 'Own pack · phone reminder',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        // No LED state for a medicine with no compartment
                        // to light.
                        if (inBox)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (currentSchedule.ledActive)
                                ? Colors.orangeAccent
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lightbulb,
                                size: 14,
                                color: currentSchedule.ledActive ? Colors.white : Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                currentSchedule.ledActive ? 'LED ON' : 'LED OFF',
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
                      title: 'Reminder',
                      value: inBox ? 'Phone + box light' : 'Phone notification',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              if (currentSchedule != null && outOfStock) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.missedRedBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, color: AppColors.missedRed, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppStrings.outOfStockBadge,
                          style: TextStyle(
                            color: AppColors.missedRed,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Today's dose of this medicine, through the same rules as the
              // dashboard: locked until 30 minutes before, an early-logging
              // prompt, Undo, and the missed-dose screen once it is missed.
              if (currentSchedule != null)
                _TodayDoseAction(
                  scheduleId: currentSchedule.scheduleId,
                  outOfStock: outOfStock,
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

class _TodayDoseAction extends StatelessWidget {
  final String scheduleId;
  final bool outOfStock;

  const _TodayDoseAction({required this.scheduleId, required this.outOfStock});

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<PatientProvider>();
    final slot = patient.todaySlotFor(scheduleId);
    final now = DateTime.now();

    if (slot == null) {
      return const _ActionNote('No dose of this medicine is due today.');
    }
    if (!slot.isOpen) {
      final badge = DoseStatusDisplay.resolvedBadge(slot.log!);
      return _ActionNote(
        "Today's ${DateFormatter.toClockLabel(slot.scheduledAt)} dose: "
        '${badge.label} · ${DoseStatusDisplay.detailFor(slot.log!)}',
      );
    }

    final phase = DoseTiming.phaseOf(slot.scheduledAt, now);
    if (phase == DosePhase.missed) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: OutlinedButton.icon(
          onPressed: () => DoseActions.openMissed(context, slot),
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text(
            'Missed — add a reason',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.missedRed,
            side: const BorderSide(color: AppColors.missedRed),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
    }

    final locked = phase == DosePhase.upcomingLocked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: outOfStock
                ? null
                : () async {
                    final navigator = Navigator.of(context);
                    final ok = await DoseActions.take(context, slot);
                    if (ok) navigator.pop();
                  },
            icon: Icon(
              locked ? Icons.lock_outline_rounded : Icons.check_circle_outline,
              color: outOfStock || locked ? AppColors.textMuted : Colors.white,
            ),
            label: Text(
              'Mark ${DateFormatter.toClockLabel(slot.scheduledAt)} dose as taken',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  locked ? AppColors.background : AppColors.caregiverGreen,
              foregroundColor: locked ? AppColors.textMuted : Colors.white,
              side: locked ? const BorderSide(color: AppColors.borderGray) : null,
              elevation: 0,
              disabledBackgroundColor: AppColors.borderGray,
              disabledForegroundColor: AppColors.textMuted,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        if (locked) ...[
          const SizedBox(height: 8),
          Text(
            AppStrings.actionsUnlockAt(
              DateFormatter.toClockLabel(DoseTiming.unlockAt(slot.scheduledAt)),
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionNote extends StatelessWidget {
  final String text;

  const _ActionNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13.5,
          color: AppColors.textSecondary,
          height: 1.45,
        ),
      ),
    );
  }
}
