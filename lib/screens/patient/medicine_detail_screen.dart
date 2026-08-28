import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import 'edit_medicine_screen.dart';
import 'delete_medicine_screen.dart';

class MedicineDetailScreen extends StatelessWidget {
  final String medicineName;
  final String dosage;
  final String frequency;
  final String column;
  final String scheduleTime;
  final String remaining;
  final String doctor;
  final String adherence;

  const MedicineDetailScreen({
    super.key,
    this.medicineName = 'Metformin',
    this.dosage = '500mg · 1 tablet per dose',
    this.frequency = 'Once daily',
    this.column = 'Column 3',
    this.scheduleTime = '8:00 PM',
    this.remaining = '6 doses',
    this.doctor = 'Dr. Santos',
    this.adherence = '89%',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Blue Gradient Hero Section
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: AppColors.blueGradient,
                ),
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chevron_left_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          Text(
                            'Back',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      medicineName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dosage,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.85),
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                  ],
                ),
              ),

              // Detail Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Grid Row 1
                    Row(
                      children: [
                        _buildMetricCard('FREQUENCY', frequency),
                        const SizedBox(width: 12),
                        _buildMetricCard(
                          'BOX COLUMN',
                          column,
                          valueColor: const Color(0xFF2563EB),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Grid Row 2
                    Row(
                      children: [
                        _buildMetricCard('SCHEDULE', scheduleTime),
                        const SizedBox(width: 12),
                        _buildMetricCard('REMAINING', remaining),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Grid Row 3
                    Row(
                      children: [
                        _buildMetricCard('PRESCRIBED BY', doctor),
                        const SizedBox(width: 12),
                        _buildMetricCard(
                          'THIS MONTH',
                          adherence,
                          valueColor: AppColors.caregiverGreen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Adherence Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: AppStyles.cardDecoration,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'This week’s adherence',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  fontFamily: 'PlusJakartaSans',
                                ),
                              ),
                              Text(
                                '5/7',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.caregiverGreen,
                                  fontFamily: 'PlusJakartaSans',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              _AdherenceBar(day: 'M', height: 44, color: AppColors.caregiverGreen),
                              _AdherenceBar(day: 'T', height: 44, color: AppColors.caregiverGreen),
                              _AdherenceBar(day: 'W', height: 16, color: Color(0xFFFCEBEB)),
                              _AdherenceBar(day: 'TH', height: 44, color: AppColors.caregiverGreen),
                              _AdherenceBar(day: 'F', height: 44, color: AppColors.caregiverGreen),
                              _AdherenceBar(day: 'S', height: 12, color: Color(0xFFEBF3FF)),
                              _AdherenceBar(day: 'S', height: 12, color: Color(0xFFEBF3FF)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Doctor's Notes
                    const Text(
                      'DOCTOR’S NOTES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: AppStyles.cardDecoration,
                      child: const Text(
                        'Take with food. Avoid skipping doses. Contact Dr. Santos if you experience unusual side effects such as nausea or dizziness.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.6,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Edit Medication Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const EditMedicineScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.borderGray),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Edit Medication',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Remove Medication Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DeleteMedicineScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Remove Medication',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, {Color? valueColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: AppStyles.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: valueColor ?? AppColors.textPrimary,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdherenceBar extends StatelessWidget {
  final String day;
  final double height;
  final Color color;

  const _AdherenceBar({
    required this.day,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 48,
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 32,
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
      ],
    );
  }
}
