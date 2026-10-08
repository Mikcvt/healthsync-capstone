import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_styles.dart';
import '../../models/dose_log_model.dart';
import '../../providers/caregiver_provider.dart';
import '../../utils/date_formatter.dart';
import '../../utils/dose_status_display.dart';
import 'patient_history_screen.dart';
import 'patient_schedule_screen.dart';
import 'reports_screen.dart';
import 'setup_medications_screen.dart';

/// Everything the caregiver needs about one patient, on one screen.
///
/// The name was the only real value here before: the stat pills, today's
/// medication rows, the 87% adherence bar and the patient info tiles
/// ("Hypertension, T2D", "Dr. Martin", "B+", "31 years old") were all typed in,
/// and three of the medication rows reported a heart rate from a sensor this
/// build does not have.
class PatientDetailScreen extends StatelessWidget {
  const PatientDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final caregiver = context.watch<CaregiverProvider>();
    final patient = caregiver.selectedPatientUser;
    final patientName = patient?.fullName ?? 'Patient';
    final profile = caregiver.selectedPatientProfile;
    final link = caregiver.patientLinks
        .where((l) => l.patientRef == caregiver.selectedPatientUid)
        .firstOrNull;

    final todayLogs = caregiver.logsForDay(DateTime.now());
    final taken = todayLogs.where((l) => l.isTaken).length;
    final pending = todayLogs.where((l) => l.isOpen).length;
    // Skipped counts with missed here: both are doses not taken.
    final missed = todayLogs.where((l) => l.isMissed || l.isSkipped).length;
    final weekly = caregiver.adherenceOver(7);

    if (caregiver.selectedPatientUid == null) {
      return const _NoSelection();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          patientName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: AppStyles.fontFamily,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                link == null
                    ? 'Your patient'
                    : 'Your patient · linked '
                        '${DateFormatter.toShortDate(link.linkedSince)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
              const SizedBox(height: 22),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _StatPill(
                      label: '${(weekly * 100).round()}%',
                      value: 'This week',
                    ),
                    const SizedBox(width: 12),
                    _StatPill(
                      label: '$taken/${todayLogs.length}',
                      value: 'Today done',
                    ),
                    const SizedBox(width: 12),
                    _StatPill(label: '$pending', value: 'Pending'),
                    const SizedBox(width: 12),
                    _StatPill(label: '$missed', value: 'Not taken'),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _TabButton(
                      label: 'Schedule',
                      selected: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PatientScheduleScreen(patientName: patientName),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _TabButton(
                      label: 'History',
                      selected: false,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PatientHistoryScreen(patientName: patientName),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _TabButton(
                      label: 'Reports',
                      selected: false,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ReportsScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Today’s medications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
              const SizedBox(height: 14),

              if (todayLogs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AppStyles.cardDecoration,
                  child: Text(
                    caregiver.selectedPatientSchedules.isEmpty
                        ? AppStrings.noPatientSchedule
                        : AppStrings.noSchedulesToday,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textSecondary,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                )
              else
                for (final log in todayLogs) ...[
                  _MedicationCard(
                    title: caregiver.medicationNameForLog(log),
                    log: log,
                    column: caregiver.scheduleById(log.scheduleRef)?.matBoxColumn,
                  ),
                  const SizedBox(height: 12),
                ],
              const SizedBox(height: 6),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: AppStyles.cardDecoration,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$patientName’s weekly adherence',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontFamily: AppStyles.fontFamily,
                        ),
                      ),
                    ),
                    Text(
                      '${(weekly * 100).round()}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: weekly >= 0.8
                            ? AppColors.caregiverGreen
                            : AppColors.missedRed,
                        fontFamily: AppStyles.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LinearProgressIndicator(
                  value: weekly,
                  minHeight: 10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    weekly >= 0.8
                        ? AppColors.caregiverGreen
                        : AppColors.missedRed,
                  ),
                  backgroundColor: AppColors.ledPending,
                ),
              ),
              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: AppStyles.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Patient info',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        fontFamily: AppStyles.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Only fields the schema actually holds. Blood type and age
                    // were on the mockup but exist nowhere in patient_profile.
                    _InfoTile(
                      label: 'Conditions',
                      value: profile?.medicalConditions.isNotEmpty == true
                          ? profile!.medicalConditions.join(', ')
                          : 'None recorded',
                    ),
                    const SizedBox(height: 12),
                    _InfoTile(
                      label: 'Allergies',
                      value: profile?.allergies.isNotEmpty == true
                          ? profile!.allergies.join(', ')
                          : 'None recorded',
                    ),
                    const SizedBox(height: 12),
                    _InfoTile(
                      label: 'Emergency contact',
                      value: profile?.emergencyContact.isNotEmpty == true
                          ? [
                              profile!.emergencyContact,
                              if (profile.emergencyPhone.isNotEmpty)
                                profile.emergencyPhone,
                            ].join(' · ')
                          : 'None recorded',
                    ),
                    if (patient?.phone.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      _InfoTile(label: 'Phone', value: patient!.phone),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Replaces a "Send message to {patient}" button that did nothing:
              // there is no messaging channel in this system, and the action a
              // caregiver actually needs from here is to edit the regimen.
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: caregiver.selectedPatientUid == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SetupMedicationsScreen(
                                patientUid: caregiver.selectedPatientUid!,
                                patientName: patientName,
                              ),
                            ),
                          ),
                  icon: const Icon(Icons.medication_outlined),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.caregiverGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  label: const Text(
                    'Manage medications',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: AppStyles.fontFamily,
                    ),
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

class _NoSelection extends StatelessWidget {
  const _NoSelection();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            AppStrings.noPatientSelected,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontFamily: AppStyles.fontFamily,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: AppStyles.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              fontFamily: AppStyles.fontFamily,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontFamily: AppStyles.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.caregiverGreen : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.caregiverGreen : AppColors.borderGray,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.textSecondary,
            fontFamily: AppStyles.fontFamily,
          ),
        ),
      ),
    );
  }
}

class _MedicationCard extends StatelessWidget {
  final String title;
  final DoseLogModel log;
  final int? column;

  const _MedicationCard({
    required this.title,
    required this.log,
    this.column,
  });

  @override
  Widget build(BuildContext context) {
    // Same labels and colours as the patient sees (DOSE_LOGIC_PROPOSAL.md,
    // section 11): Upcoming / Due now / Late / Missed / Taken early / Taken
    // late / Logged late / Skipped.
    final now = DateTime.now();
    final badge = DoseStatusDisplay.badgeFor(log, log.scheduledAt ?? now, now);
    final label = badge.label;
    final accent = badge.foreground;
    final background = badge.outlined ? AppColors.missedRedBg : badge.background;

    return Container(
      decoration: AppStyles.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 6,
            height: 64,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      log.scheduledTime,
                      if (column != null) 'Compartment $column',
                      if (log.isResolved) DoseStatusDisplay.detailFor(log),
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 128,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              fontFamily: AppStyles.fontFamily,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.4,
              fontFamily: AppStyles.fontFamily,
            ),
          ),
        ),
      ],
    );
  }
}
