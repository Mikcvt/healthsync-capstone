import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import 'add_medicine_step1_screen.dart';
import 'guardian_link_screen.dart';
import 'intake_history_screen.dart';
import 'medicine_box_status_screen.dart';
import 'medicine_detail_screen.dart';
import 'notifications_screen.dart';
import 'dose_alert_screen.dart';

class PatientDashboardScreen extends StatelessWidget {
  const PatientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final patientProvider = context.watch<PatientProvider>();
    final user = authProvider.currentUserModel;
    final firstName = user?.firstName.isNotEmpty == true ? user!.firstName : 'Patient';

    final schedules = patientProvider.schedules;
    final todayLogs = patientProvider.todayLogs;
    final takenCount = todayLogs.where((l) => l.isTaken).length;
    final totalDoses = schedules.length;
    final isLinked = patientProvider.isLinkedToCaregiver;
    final caregiver = patientProvider.caregiverUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Hello, $firstName!',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Adherence Card
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
                        const Text(
                          'TODAY\'S MEDICATION PLAN',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$takenCount/$totalDoses Taken',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      totalDoses == 0
                          ? 'No medications scheduled'
                          : (takenCount >= totalDoses
                              ? 'All doses completed today!'
                              : '${totalDoses - takenCount} dose(s) pending today'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _Pill(label: '$totalDoses daily doses', color: Colors.white.withOpacity(0.18)),
                        const SizedBox(width: 10),
                        _Pill(
                          label: '${patientProvider.todayAdherencePercentage.toStringAsFixed(0)}% adherence',
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ==========================================
              // CAREGIVER LINKING BANNER
              // ==========================================
              if (!isLinked) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade300, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shield_outlined, color: Colors.amber.shade900, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No Caregiver Linked',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.amber.shade900,
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Connect accounts to share reminders & alerts.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade900.withOpacity(0.8),
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const GuardianLinkScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade900,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Link', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ] else ...[
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GuardianLinkScreen()),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.ledDoneBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.caregiverGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.caregiverGreen, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Caregiver ${caregiver != null ? caregiver.firstName : "Connected"} is monitoring',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.caregiverGreen,
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.caregiverGreen, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // ==========================================
              // TODAY'S DOSES LIST
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Today\'s Schedule',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AddMedicineStep1Screen()),
                      );
                    },
                    icon: const Icon(Icons.add, size: 18, color: AppColors.patientBlue),
                    label: const Text(
                      'Add Medicine',
                      style: TextStyle(
                        color: AppColors.patientBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (schedules.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: AppStyles.cardDecoration,
                  child: Column(
                    children: [
                      const Icon(Icons.medication_outlined, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      const Text(
                        'No medications scheduled yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Add your first prescription to start tracking doses and smart box LEDs.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AddMedicineStep1Screen()),
                          );
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Medication Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.patientBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...schedules.map((sch) {
                  final matchingMed = patientProvider.medications.where((m) => m.patMedId == sch.patMedRef).firstOrNull;
                  final medName = matchingMed?.medicationName.isNotEmpty == true
                      ? matchingMed!.medicationName
                      : (sch.caregiverDoctor.isNotEmpty ? 'Medication (Col ${sch.matBoxColumn})' : 'Scheduled Medication');

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
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: AppStyles.cardDecoration,
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.patientBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.view_column_rounded, size: 18, color: AppColors.patientBlue),
                                Text(
                                  'Col ${sch.matBoxColumn}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.patientBlue,
                                  ),
                                ),
                              ],
                            ),
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
                                  'Time: ${sch.scheduledTime} · ${sch.pillsRemaining} pills left',
                                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline, color: AppColors.caregiverGreen, size: 28),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DoseAlertScreen(
                                    schedule: sch,
                                    medicineName: medName,
                                    doseTime: sch.scheduledTime,
                                    columnNumber: sch.matBoxColumn,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 20),

              // ==========================================
              // QUICK ACTIONS
              // ==========================================
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _QuickCard(
                      title: 'Smart Box',
                      subtitle: 'Status & LED test',
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.patientBlue,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MedicineBoxStatusScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickCard(
                      title: 'Dose History',
                      subtitle: 'Past intake logs',
                      icon: Icons.history_rounded,
                      color: AppColors.caregiverGreen,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const IntakeHistoryScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: 'PlusJakartaSans',
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppStyles.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
