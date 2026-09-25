import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/caregiver_provider.dart';
import 'link_patient_screen.dart';
import 'patient_detail_screen.dart';

class MyPatientsScreen extends StatelessWidget {
  const MyPatientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final caregiver = context.watch<CaregiverProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('My Patients', style: TextStyle(color: AppColors.textPrimary, fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w800)),
        actions: [
          IconButton(tooltip: 'Link patient', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LinkPatientScreen())), icon: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.caregiverGreen)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (caregiver.patientLinks.isEmpty)
              _EmptyPatients(onLink: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LinkPatientScreen())))
            else
              ...caregiver.patientLinks.map((link) => _PatientCard(
                    patientUid: link.patientRef,
                    isSelected: caregiver.selectedPatientUid == link.patientRef,
                    name: caregiver.selectedPatientUid == link.patientRef ? caregiver.selectedPatientUser?.fullName : null,
                    onTap: () async {
                      await caregiver.selectPatient(link.patientRef);
                      if (context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PatientDetailScreen()));
                    },
                  )),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LinkPatientScreen())), icon: const Icon(Icons.add_link), label: const Text('Link another patient')),
          ],
        ),
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final String patientUid;
  final String? name;
  final bool isSelected;
  final VoidCallback onTap;
  const _PatientCard({required this.patientUid, required this.name, required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final displayName = name ?? 'Patient ${patientUid.substring(0, patientUid.length > 6 ? 6 : patientUid.length)}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: AppStyles.cardDecoration.copyWith(border: isSelected ? Border.all(color: AppColors.caregiverGreen, width: 1.5) : null),
        child: Row(children: [CircleAvatar(backgroundColor: AppColors.patientBlue, child: Text(_initials(displayName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)), const SizedBox(height: 4), Text(isSelected ? 'Selected patient' : 'Tap to view details', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))])), const Icon(Icons.chevron_right, color: AppColors.textSecondary)]),
      ),
    );
  }
  String _initials(String value) => value.split(' ').where((part) => part.isNotEmpty).take(2).map((part) => part[0]).join().toUpperCase();
}

class _EmptyPatients extends StatelessWidget {
  final VoidCallback onLink;
  const _EmptyPatients({required this.onLink});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(24), decoration: AppStyles.cardDecoration, child: Column(children: [const Icon(Icons.group_outlined, size: 48, color: AppColors.caregiverGreen), const SizedBox(height: 12), const Text('No patients linked yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)), const SizedBox(height: 8), const Text('Ask a patient for their invite code to begin monitoring.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)), const SizedBox(height: 16), ElevatedButton.icon(onPressed: onLink, icon: const Icon(Icons.link), label: const Text('Link patient'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.caregiverGreen, foregroundColor: Colors.white))]));
}
