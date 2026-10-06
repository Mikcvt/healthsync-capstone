import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../models/patient_medication_model.dart';
import '../../models/schedule_model.dart';
import '../../providers/schedule_provider.dart';
import '../../services/firestore_service.dart';
import '../patient/add_medicine_step1_screen.dart';
import 'generate_otp_screen.dart';

/// The caregiver's view of one patient's regimen, and where they add to it.
///
/// Adding reuses the patient-side add-medicine wizard; [ScheduleProvider] is
/// pointed at this patient first so the wizard writes to them rather than to
/// the caregiver.
class SetupMedicationsScreen extends StatefulWidget {
  final String patientUid;
  final String patientName;

  const SetupMedicationsScreen({
    super.key,
    required this.patientUid,
    required this.patientName,
  });

  @override
  State<SetupMedicationsScreen> createState() =>
      _SetupMedicationsScreenState();
}

class _SetupMedicationsScreenState extends State<SetupMedicationsScreen> {
  final _firestore = FirestoreService();

  /// Subscribed once. Creating these inside `build` made a new stream on every
  /// rebuild, so each keystroke elsewhere in the tree re-read the patient's
  /// whole medication list against the Spark plan's read quota.
  late final Stream<List<PatientMedicationModel>> _medications =
      _firestore.streamPatientMedications(widget.patientUid);
  late final Stream<List<ScheduleModel>> _schedules =
      _firestore.streamPatientSchedules(widget.patientUid);

  void _addMedicine(BuildContext context) {
    final schedule = context.read<ScheduleProvider>();
    schedule.resetForm();
    schedule.setTargetPatient(
      uid: widget.patientUid,
      name: widget.patientName,
    );
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => const AddMedicineStep1Screen()),
        )
        // Clear the target on the way out: a stale one would send the next
        // medicine to the wrong person.
        .then((_) => schedule.clearTargetPatient());
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.patientName.split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "$firstName's medicines",
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Their code',
            icon: const Icon(Icons.key_rounded,
                color: AppColors.caregiverGreen),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GenerateOtpScreen(
                  patientUid: widget.patientUid,
                  patientName: widget.patientName,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<PatientMedicationModel>>(
          stream: _medications,
          builder: (context, medSnapshot) {
            if (medSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2.4),
              );
            }

            final meds = medSnapshot.data ?? const [];

            return StreamBuilder<List<ScheduleModel>>(
              stream: _schedules,
              builder: (context, scheduleSnapshot) {
                final schedules = scheduleSnapshot.data ?? const [];

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  children: [
                    if (meds.isEmpty)
                      _EmptyState(
                        patientName: firstName,
                        onAdd: () => _addMedicine(context),
                      )
                    else ...[
                      Text(
                        '${meds.length} medicine${meds.length == 1 ? '' : 's'}, '
                        '${schedules.length} dose time${schedules.length == 1 ? '' : 's'} a day',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...meds.map(
                        (med) => _MedicineCard(
                          medication: med,
                          schedules: schedules
                              .where((s) => s.patMedRef == med.patMedId)
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _addMedicine(context),
                        icon: const Icon(Icons.add_rounded),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          foregroundColor: AppColors.caregiverGreen,
                          side: const BorderSide(
                              color: AppColors.caregiverGreen, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        label: const Text(
                          'Add another medicine',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  final PatientMedicationModel medication;
  final List<ScheduleModel> schedules;

  const _MedicineCard({required this.medication, required this.schedules});

  @override
  Widget build(BuildContext context) {
    final columns = schedules.map((s) => s.matBoxColumn).toSet().toList()..sort();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: AppStyles.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  medication.medicationName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ),
              if (columns.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.ledActiveBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    columns.length == 1
                        ? 'Column ${columns.first}'
                        : 'Columns ${columns.join(', ')}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ledActive,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ),
            ],
          ),
          if (medication.prescribedDosage.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              medication.prescribedDosage,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          ],
          if (schedules.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: schedules
                  .map(
                    (s) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.blueLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        s.scheduledTime,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blueDark,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ] else ...[
            const SizedBox(height: 10),
            const Text(
              'No dose times set — this medicine will not trigger a reminder.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.missedRed,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String patientName;
  final VoidCallback onAdd;

  const _EmptyState({required this.patientName, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: AppStyles.cardDecoration,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.medication_outlined,
                size: 30, color: AppColors.caregiverGreen),
          ),
          const SizedBox(height: 16),
          Text(
            'No medicines yet',
            style: AppStyles.heading3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Add $patientName\'s medicines, dose times and box compartments. '
            'They will see the schedule as soon as they enter their code.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondary,
              fontFamily: 'PlusJakartaSans',
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 20),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.caregiverGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              label: const Text(
                'Add first medicine',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
