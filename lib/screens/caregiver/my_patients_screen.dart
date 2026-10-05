import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../models/user_model.dart';
import '../../providers/caregiver_provider.dart';
import '../../services/firestore_service.dart';
import 'add_patient_screen.dart';
import 'patient_detail_screen.dart';
import 'setup_medications_screen.dart';

class MyPatientsScreen extends StatelessWidget {
  const MyPatientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final caregiver = context.watch<CaregiverProvider>();
    final links = caregiver.patientLinks;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'My Patients',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Add patient',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddPatientScreen()),
            ),
            icon: const Icon(Icons.person_add_alt_1_outlined,
                color: AppColors.caregiverGreen),
          ),
        ],
      ),
      body: SafeArea(
        child: links.isEmpty
            ? ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [_EmptyPatients(onAdd: () => _addPatient(context))],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  ...links.map(
                    (link) => _PatientCard(
                      patientUid: link.patientRef,
                      isSelected:
                          caregiver.selectedPatientUid == link.patientRef,
                      onTap: () async {
                        await caregiver.selectPatient(link.patientRef);
                        if (context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PatientDetailScreen(),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _addPatient(context),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
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
                      'Add another patient',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _addPatient(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AddPatientScreen()),
      );
}

/// Loads each patient's own record rather than relying on the provider's
/// currently-selected patient, so every row shows a real name instead of a
/// uid fragment.
class _PatientCard extends StatelessWidget {
  final String patientUid;
  final bool isSelected;
  final VoidCallback onTap;

  const _PatientCard({
    required this.patientUid,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: FirestoreService().streamUser(patientUid),
      builder: (context, snapshot) {
        final patient = snapshot.data;
        final name = patient?.fullName.trim();
        final displayName =
            (name == null || name.isEmpty) ? 'Loading…' : name;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: AppStyles.cardDecoration.copyWith(
              border: isSelected
                  ? Border.all(color: AppColors.caregiverGreen, width: 1.5)
                  : null,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.patientBlue,
                  child: Text(
                    _initials(displayName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (patient != null) _StatusChip(patient: patient),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Medicines',
                  icon: const Icon(Icons.medication_outlined,
                      color: AppColors.caregiverGreen),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SetupMedicationsScreen(
                        patientUid: patientUid,
                        patientName: displayName,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _initials(String value) => value
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0])
      .join()
      .toUpperCase();
}

/// A managed patient who has never signed in still has no fcm_token, which is
/// the only honest signal available that they have not opened the app yet.
class _StatusChip extends StatelessWidget {
  final UserModel patient;
  const _StatusChip({required this.patient});

  @override
  Widget build(BuildContext context) {
    final awaitingFirstLogin = patient.isManaged;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: awaitingFirstLogin
            ? AppColors.pendingAmberBg
            : AppColors.takenGreenBg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        awaitingFirstLogin ? 'Managed patient' : 'Independent',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: awaitingFirstLogin
              ? AppColors.pendingAmber
              : AppColors.takenGreen,
          fontFamily: 'PlusJakartaSans',
        ),
      ),
    );
  }
}

class _EmptyPatients extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyPatients({required this.onAdd});

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
            child: const Icon(Icons.group_outlined,
                size: 30, color: AppColors.caregiverGreen),
          ),
          const SizedBox(height: 16),
          const Text(
            'No patients yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create an account for the person you care for, set up their '
            'medicines, then send them a code to open the app.',
            textAlign: TextAlign.center,
            style: TextStyle(
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
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.caregiverGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              label: const Text(
                'Add your first patient',
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
