import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/patient_provider.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final patientProvider = context.watch<PatientProvider>();
    final adherence = patientProvider.overallAdherencePercentage;
    final todayAdherence = patientProvider.todayAdherencePercentage;
    final totalTaken = patientProvider.allLogs.where((l) => l.isTaken).length;
    final totalMissed = patientProvider.allLogs.where((l) => l.isMissed).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Adherence Analytics',
          style: TextStyle(
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
              // Hero Adherence Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: AppStyles.gradientDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OVERALL ADHERENCE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${adherence.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.trending_up, color: Colors.white, size: 20),
                              SizedBox(width: 6),
                              Text(
                                'On Track',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Today: ${todayAdherence.toStringAsFixed(0)}% · $totalTaken doses successfully taken',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'ACTIVITY BREAKDOWN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Doses Taken',
                      value: '$totalTaken',
                      color: AppColors.caregiverGreen,
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Doses Missed',
                      value: '$totalMissed',
                      color: Colors.redAccent,
                      icon: Icons.cancel_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Active Meds',
                      value: '${patientProvider.medications.length}',
                      color: AppColors.patientBlue,
                      icon: Icons.medication_liquid_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Daily Schedules',
                      value: '${patientProvider.schedules.length}',
                      color: Colors.orangeAccent,
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Caregiver Sync Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: AppStyles.cardDecoration,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.patientBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.share_outlined, color: AppColors.patientBlue),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Shared with Guardian',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            patientProvider.isLinkedToCaregiver
                                ? 'Caregiver is receiving weekly reports'
                                : 'Link caregiver to share adherence reports',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppStyles.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
        ],
      ),
    );
  }
}
