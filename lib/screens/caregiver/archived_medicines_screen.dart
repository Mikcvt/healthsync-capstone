import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../models/patient_medication_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/snackbar_helper.dart';

/// Medicines that have left the active regimen.
///
/// Two kinds live here and they are not the same thing:
///
/// * **Finished** — the course ended. Its doses are real history and count in
///   adherence.
/// * **Entered by mistake** — wrong data. Its doses are kept but marked "not
///   counted", so they never affect adherence.
///
/// Nothing here can be erased. A dose log is part of the medical record, so
/// archiving is the only way out; a genuine request to erase someone's data is
/// handled by an admin from the Firebase console. Restoring is offered for
/// both kinds: the usual reason to open this screen is that something was
/// archived in error.
class ArchivedMedicinesScreen extends StatelessWidget {
  final String patientUid;
  final String patientName;

  const ArchivedMedicinesScreen({
    super.key,
    required this.patientUid,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

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
        title: const Text(
          'Archived medicines',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<PatientMedicationModel>>(
          stream: firestore.streamArchivedMedications(patientUid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2.4),
              );
            }

            final items = snapshot.data ?? const <PatientMedicationModel>[];
            if (items.isEmpty) {
              return _Empty(patientName: patientName.split(' ').first);
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  '${items.length} archived '
                  '${items.length == 1 ? 'medicine' : 'medicines'}. '
                  'Past doses stay in history and reports.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                ...items.map(
                  (med) => _ArchivedCard(
                    medication: med,
                    patientUid: patientUid,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ArchivedCard extends StatelessWidget {
  final PatientMedicationModel medication;
  final String patientUid;

  const _ArchivedCard({required this.medication, required this.patientUid});

  bool get _wasMistake => medication.archivedReason == 'mistake';

  String get _name => medication.medicationName.trim().isEmpty
      ? 'Unnamed medicine'
      : medication.medicationName;

  Future<void> _restore(BuildContext context) async {
    try {
      await FirestoreService()
          .restoreMedication(medication.patMedId, patientUid: patientUid);
      if (context.mounted) {
        SnackbarHelper.showSuccess(context, '$_name restored.');
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Could not restore $_name.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  _name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _wasMistake
                      ? AppColors.missedRedBg
                      : AppColors.takenGreenBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _wasMistake ? 'Entered by mistake' : 'Course finished',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _wasMistake
                        ? AppColors.missedRed
                        : AppColors.takenGreen,
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
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _restore(context),
              icon: const Icon(Icons.restore_rounded, size: 18),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                foregroundColor: AppColors.caregiverGreen,
                side: const BorderSide(color: AppColors.caregiverGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              label: const Text('Restore',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _wasMistake
                ? 'Entered by mistake — not counted. Its doses are kept on '
                    'record but left out of adherence.'
                : 'A finished course keeps its dose history, and its doses '
                    'still count in adherence.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String patientName;
  const _Empty({required this.patientName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 44, color: AppColors.textMuted),
            const SizedBox(height: 14),
            const Text(
              'Nothing archived',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Medicines you finish or remove from $patientName\'s regimen '
              'will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
