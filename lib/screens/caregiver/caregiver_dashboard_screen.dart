import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/caregiver_provider.dart';
import 'caregiver_alerts_screen.dart';
import 'link_patient_screen.dart';

class CaregiverDashboardScreen extends StatelessWidget {
  const CaregiverDashboardScreen({super.key});

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUserModel;
    final provider = context.watch<CaregiverProvider>();
    final patientCount = provider.patientLinks.length;
    final patient = provider.selectedPatientUser;
    final patientName = patient?.fullName ?? 'No patient selected';
    final todayLogs = provider.selectedPatientLogs
        .where((log) => log.scheduledDate == _todayKey())
        .toList();
    final taken = todayLogs.where((log) => log.isTaken).length;
    final pending = todayLogs.where((log) => log.isPending || log.isSnoozed).length;
    final missed = todayLogs.where((log) => log.isMissed).length;
    final firstName = user?.firstName.isNotEmpty == true ? user!.firstName : 'Caregiver';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Guardian Dashboard', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'PlusJakartaSans')),
                        const SizedBox(height: 6),
                        Text('Hello, $firstName', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.textPrimary, fontFamily: 'PlusJakartaSans')),
                        const SizedBox(height: 4),
                        Text(
                          patientCount == 0 ? 'No patients linked' : 'Monitoring $patientCount ${patientCount == 1 ? 'patient' : 'patients'}',
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'PlusJakartaSans'),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Alert history',
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CaregiverAlertsScreen())),
                    icon: const Icon(Icons.notifications_none_rounded, color: AppColors.patientBlue),
                    style: IconButton.styleFrom(backgroundColor: AppColors.patientBlue.withValues(alpha: 0.12)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (patientCount == 0)
                _EmptyDashboard(onLink: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LinkPatientScreen())))
              else ...[
                _NextDoseCard(
                  patientName: patientName,
                  nextDose: provider.selectedPatientSchedules.isEmpty
                      ? 'No active schedules'
                      : 'Active medication schedule',
                  pending: pending,
                ),
                const SizedBox(height: 22),
                _PatientSummaryCard(
                  patientName: patientName,
                  taken: taken,
                  total: todayLogs.length,
                  missed: missed,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NextDoseCard extends StatelessWidget {
  final String patientName;
  final String nextDose;
  final int pending;

  const _NextDoseCard({required this.patientName, required this.nextDose, required this.pending});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.gradientDecoration.copyWith(gradient: AppColors.greenGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.favorite_outline, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$patientName\'S MEDICATION STATUS',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, fontFamily: 'PlusJakartaSans'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(nextDose, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'PlusJakartaSans')),
          const SizedBox(height: 8),
          const Text('Live data from the patient schedule', style: TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'PlusJakartaSans')),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('$pending dose${pending == 1 ? '' : 's'} pending today', style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'PlusJakartaSans'))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientSummaryCard extends StatelessWidget {
  final String patientName;
  final int taken;
  final int total;
  final int missed;

  const _PatientSummaryCard({required this.patientName, required this.taken, required this.total, required this.missed});

  @override
  Widget build(BuildContext context) {
    final initials = patientName
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppStyles.cardDecoration,
      child: Row(
        children: [
          CircleAvatar(radius: 26, backgroundColor: AppColors.patientBlue, child: Text(initials.isEmpty ? '?' : initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patientName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'PlusJakartaSans')),
                const SizedBox(height: 4),
                Text(total == 0 ? 'No dose logs for today' : '$taken of $total doses taken today', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'PlusJakartaSans')),
              ],
            ),
          ),
          if (missed > 0)
            Text('$missed missed', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.missedRed)),
        ],
      ),
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  final VoidCallback onLink;
  const _EmptyDashboard({required this.onLink});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppStyles.cardDecoration,
      child: Column(
        children: [
          const Icon(Icons.people_outline, size: 48, color: AppColors.caregiverGreen),
          const SizedBox(height: 14),
          const Text('Start monitoring a patient', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'PlusJakartaSans')),
          const SizedBox(height: 8),
          const Text('Link a patient with their invite code to see schedules and dose activity.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary, fontFamily: 'PlusJakartaSans')),
          const SizedBox(height: 18),
          ElevatedButton.icon(onPressed: onLink, icon: const Icon(Icons.link_rounded), label: const Text('Link patient'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.caregiverGreen, foregroundColor: Colors.white)),
        ],
      ),
    );
  }
}
