import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import 'add_medicine_step1_screen.dart';
import 'medicine_detail_screen.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Schedule',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AddMedicineStep1Screen(),
                ),
              );
            },
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.patientBlue,
              size: 26,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upcoming doses',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 12),
              _ScheduleCard(
                medicine: 'Metformin',
                time: '08:00 AM',
                status: 'Taken',
                color: AppColors.ledDoneBg,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MedicineDetailScreen(
                        medicineName: 'Metformin',
                        dosage: '500mg · 1 tablet per dose',
                        scheduleTime: '8:00 AM',
                        column: 'Column 3',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _ScheduleCard(
                medicine: 'Vitamin D',
                time: '01:30 PM',
                status: 'Pending',
                color: AppColors.ledActiveBg,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MedicineDetailScreen(
                        medicineName: 'Vitamin D',
                        dosage: '1000 IU · 1 capsule per dose',
                        scheduleTime: '1:30 PM',
                        column: 'Column 2',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _ScheduleCard(
                medicine: 'Aspirin',
                time: '08:00 PM',
                status: 'Upcoming',
                color: AppColors.ledPendingBg,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MedicineDetailScreen(
                        medicineName: 'Aspirin',
                        dosage: '81mg · 1 tablet per dose',
                        scheduleTime: '8:00 PM',
                        column: 'Column 1',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final String medicine;
  final String time;
  final String status;
  final Color color;
  final VoidCallback? onTap;

  const _ScheduleCard({
    required this.medicine,
    required this.time,
    required this.status,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppStyles.cardDecoration,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time,
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
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
