import '../../utils/snackbar_helper.dart';
import '../../widgets/caregiver/delete_patient_dialog.dart';
import '../../widgets/shared/floating_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../models/user_model.dart';
import '../../providers/caregiver_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/date_formatter.dart';
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
          onLongPress: patient == null || patient.hasPendingDeletion
              ? null
              : () => _confirmRemove(
                    context,
                    patientUid: patient.uid,
                    displayName: displayName,
                  ),
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
                      if (patient != null && patient.hasPendingDeletion) ...[
                        const SizedBox(height: 6),
                        _PendingDeletionBanner(
                          patient: patient,
                          name: displayName,
                        ),
                      ],
                    ],
                  ),
                ),
                // Hidden while the account is pending deletion: medicines
                // can only change after Restore (BUG-025).
                if (patient == null || !patient.hasPendingDeletion)
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

/// Deletes a patient, behind a dialog that spells out what goes with them and
/// asks for the password. Restorable from their card for 30 days.
Future<void> _confirmRemove(
  BuildContext context, {
  required String patientUid,
  required String displayName,
}) async {
  final caregiver = context.read<CaregiverProvider>();
  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DeletePatientDialog(
      patientUid: patientUid,
      patientName: displayName,
    ),
  );
  if (deleted == true && context.mounted) {
    final purgeOn = caregiver.lastPurgeDate;
    SnackbarHelper.showSuccess(
      context,
      purgeOn == null
          ? '$displayName was deleted.'
          : '$displayName will be deleted on '
              '${DateFormatter.toShortDate(purgeOn)}. You can restore them '
              'until then.',
    );
  }
}

/// A patient deleted within the last 30 days, by the care partner or by
/// themselves, with the one thing still possible: bringing them back.
///
/// Replaces the approve/decline banner. A patient's own deletion no longer
/// waits for approval (Google Play requires that whoever asks gets it), so
/// the care partner's say is the restore instead.
class _PendingDeletionBanner extends StatefulWidget {
  final UserModel patient;
  final String name;

  const _PendingDeletionBanner({required this.patient, required this.name});

  @override
  State<_PendingDeletionBanner> createState() => _PendingDeletionBannerState();
}

class _PendingDeletionBannerState extends State<_PendingDeletionBanner> {
  bool _restoring = false;

  Future<void> _restore() async {
    setState(() => _restoring = true);
    final caregiver = context.read<CaregiverProvider>();
    final ok = await caregiver.restorePatient(widget.patient.uid);
    if (!mounted) return;
    setState(() => _restoring = false);
    ok
        ? SnackbarHelper.showSuccess(
            context,
            '${widget.name} is restored. Send them a new code to sign in.',
          )
        : SnackbarHelper.showError(
            context,
            caregiver.errorMessage ?? 'Could not restore ${widget.name}.',
          );
  }

  @override
  Widget build(BuildContext context) {
    final purgeOn = widget.patient.deletionScheduledFor;
    final when =
        purgeOn == null ? 'soon' : 'on ${DateFormatter.toShortDate(purgeOn)}';
    final who = widget.patient.deletedThemselves
        ? '${widget.name} deleted their account'
        : 'You deleted this account';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      decoration: BoxDecoration(
        color: AppColors.missedRedBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$who. It will be permanently deleted $when.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: AppColors.missedRed,
            ),
          ),
          TextButton(
            onPressed: _restoring ? null : _restore,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 30),
            ),
            child: Text(
              _restoring ? 'Restoring…' : 'Restore',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.caregiverGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
