import '../../utils/snackbar_helper.dart';
import '../../widgets/shared/floating_nav_bar.dart';
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, FloatingNavBar.contentPadding),
                children: [_EmptyPatients(onAdd: () => _addPatient(context))],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, FloatingNavBar.contentPadding),
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
class _PatientCard extends StatefulWidget {
  final String patientUid;
  final bool isSelected;
  final VoidCallback onTap;

  const _PatientCard({
    required this.patientUid,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PatientCard> createState() => _PatientCardState();
}

class _PatientCardState extends State<_PatientCard> {
  /// Subscribed once rather than rebuilt in `build`. A stream created during
  /// build is a new stream each time, so selecting a patient re-read the user
  /// document of every card in the list.
  late final Stream<UserModel?> _patient =
      FirestoreService().streamUser(widget.patientUid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: _patient,
      builder: (context, snapshot) {
        final patient = snapshot.data;
        final name = patient?.fullName.trim();
        final displayName =
            (name == null || name.isEmpty) ? 'Loading…' : name;

        return InkWell(
          onTap: widget.onTap,
          onLongPress: patient == null
              ? null
              : () => _confirmRemove(context, patient, displayName),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: AppStyles.cardDecoration.copyWith(
              border: widget.isSelected
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
                      if (patient?.hasPendingDeletion == true) ...[
                        const SizedBox(height: 6),
                        _DeletionRequestBanner(
                          patientUid: widget.patientUid,
                          name: displayName,
                        ),
                      ],
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
                        patientUid: widget.patientUid,
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

/// Removes a patient from the caregiver's care.
///
/// Deactivates rather than erases: the dose history is the record of care
/// given, and a caregiver may need it long after the patient stops using the
/// app. The Auth account is left intact so the uid can never be reused.
Future<void> _confirmRemove(
  BuildContext context,
  UserModel patient,
  String displayName,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Remove this patient?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      content: Text(
        '$displayName will no longer appear in your list and their reminders '
        'will stop. Their dose history is kept, and they can be added again '
        'later with a new code.',
        style: const TextStyle(height: 1.5, color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Keep'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Remove',
              style: TextStyle(color: AppColors.missedRed)),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final caregiver = context.read<CaregiverProvider>();
  final ok = await caregiver.removePatient(patient.uid);
  if (!context.mounted) return;
  ok
      ? SnackbarHelper.showSuccess(context, '$displayName removed.')
      : SnackbarHelper.showError(
          context, caregiver.errorMessage ?? 'Could not remove this patient.');
}

/// Surfaces a patient's own request to be deleted, with both answers.
///
/// The patient cannot act on this themselves by design, so the caregiver has
/// to see it somewhere they actually look — their patient list.
class _DeletionRequestBanner extends StatelessWidget {
  final String patientUid;
  final String name;

  const _DeletionRequestBanner({required this.patientUid, required this.name});

  @override
  Widget build(BuildContext context) {
    final caregiver = context.read<CaregiverProvider>();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.pendingAmberBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$name asked to delete their account',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.pendingAmber,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton(
                onPressed: () async {
                  final ok = await caregiver.removePatient(patientUid);
                  if (!context.mounted) return;
                  ok
                      ? SnackbarHelper.showSuccess(context, '$name removed.')
                      : SnackbarHelper.showError(
                          context, 'Could not remove $name.');
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                ),
                child: const Text('Approve',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.missedRed)),
              ),
              TextButton(
                onPressed: () async {
                  final ok =
                      await caregiver.declineDeletionRequest(patientUid);
                  if (!context.mounted) return;
                  ok
                      ? SnackbarHelper.showInfo(context, 'Request declined.')
                      : SnackbarHelper.showError(
                          context, 'Could not decline the request.');
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                ),
                child: const Text('Decline', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
