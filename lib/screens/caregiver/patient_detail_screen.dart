import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import 'patient_analytics_screen.dart';
import 'patient_history_screen.dart';
import 'patient_schedule_screen.dart';

class PatientDetailScreen extends StatelessWidget {
  const PatientDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'Christian San Luis',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
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
              const Text(
                'Your patient · Linked May 20, 2026',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  _StatPill(label: '87%', value: 'This week'),
                  const SizedBox(width: 12),
                  _StatPill(label: '2/3', value: 'Today done'),
                  const SizedBox(width: 12),
                  _StatPill(label: '1', value: 'Pending'),
                  const SizedBox(width: 12),
                  _StatPill(label: '0', value: 'Missed'),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  _TabButton(
                    label: 'Schedule',
                    selected: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PatientScheduleScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  _TabButton(
                    label: 'History',
                    selected: false,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PatientHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  _TabButton(label: 'Vitals', selected: false),
                  const SizedBox(width: 10),
                  _TabButton(
                    label: 'Analytics',
                    selected: false,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PatientAnalyticsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Today’s medications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 14),
              const _MedicationCard(
                title: 'Amlodipine 5mg',
                detail: 'On time · HR: 78 bpm · Normal',
                status: 'Done',
                statusColor: AppColors.takenGreenBg,
                leftColor: AppColors.takenGreenBg,
              ),
              const SizedBox(height: 12),
              const _MedicationCard(
                title: 'Losartan 50mg',
                detail: 'On time · HR: 80 bpm · Normal',
                status: 'Done',
                statusColor: AppColors.takenGreenBg,
                leftColor: AppColors.takenGreenBg,
              ),
              const SizedBox(height: 12),
              const _MedicationCard(
                title: 'Metformin 500mg pending',
                detail: 'Scheduled 8:00 · Col 3',
                status: '1 pending',
                statusColor: AppColors.pendingAmberBg,
                leftColor: AppColors.pendingAmberBg,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: AppStyles.cardDecoration,
                child: Row(
                  children: const [
                    Expanded(
                      child: Text(
                        'Christian’s weekly adherence',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ),
                    Text(
                      '87%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.caregiverGreen,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LinearProgressIndicator(
                  value: 0.87,
                  minHeight: 10,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.caregiverGreen,
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
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        Expanded(
                          child: _InfoTile(
                            label: 'Condition',
                            value: 'Hypertension, T2D',
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _InfoTile(
                            label: 'Doctor',
                            value: 'Dr. Martin',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Expanded(
                          child: _InfoTile(label: 'Blood type', value: 'B+'),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _InfoTile(label: 'Age', value: '31 years old'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.patientBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Send message to Christian',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _TabButton({required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.caregiverGreen : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
      ),
    );
  }
}

class _MedicationCard extends StatelessWidget {
  final String title;
  final String detail;
  final String status;
  final Color statusColor;
  final Color leftColor;

  const _MedicationCard({
    required this.title,
    required this.detail,
    required this.status,
    required this.statusColor,
    required this.leftColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.cardDecoration.copyWith(
        border: Border.all(color: leftColor),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 60,
            decoration: BoxDecoration(
              color: leftColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
        ],
      ),
    );
  }
}
