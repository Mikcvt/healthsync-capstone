import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';

class PatientHistoryScreen extends StatelessWidget {
  const PatientHistoryScreen({super.key});

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
          'Christian’s History',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(40),
          child: Padding(
            padding: EdgeInsets.only(left: 20, bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Intake record',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _HistorySection(
                label: 'Today',
                items: [
                  _HistoryItem(
                    title: 'Amlodipine 5mg Taken',
                    subtitle: 'On time · HR 78 bpm · Normal',
                    time: '7:02 AM',
                    statusColor: AppColors.takenGreenBg,
                  ),
                  _HistoryItem(
                    title: 'Losartan 50mg Taken',
                    subtitle: 'On time · HR 80 bpm · Normal',
                    time: '12:03 PM',
                    statusColor: AppColors.takenGreenBg,
                  ),
                  _HistoryItem(
                    title: 'Metformin 500mg Pending',
                    subtitle: 'Scheduled 8:00 PM',
                    time: '8:00 PM',
                    statusColor: AppColors.pendingAmberBg,
                  ),
                ],
              ),
              SizedBox(height: 20),
              _HistorySection(
                label: 'Yesterday',
                items: [
                  _HistoryItem(
                    title: 'Amlodipine 5mg Taken',
                    subtitle: 'On time · HR 78 bpm · Normal',
                    time: '7:04 AM',
                    statusColor: AppColors.takenGreenBg,
                  ),
                  _HistoryItem(
                    title: 'Losartan 50mg Taken',
                    subtitle: 'On time · HR 80 bpm · Normal',
                    time: '12:01 PM',
                    statusColor: AppColors.takenGreenBg,
                  ),
                  _HistoryItem(
                    title: 'Metformin 500mg Pending',
                    subtitle: 'On time · HR 78 bpm · Normal',
                    time: '8:00 PM',
                    statusColor: AppColors.pendingAmberBg,
                  ),
                ],
              ),
              SizedBox(height: 20),
              _HistorySection(
                label: 'May 19',
                items: [
                  _HistoryItem(
                    title: 'Losartan 50mg MISSED',
                    subtitle: 'Guardian was notified at 12:30 PM',
                    time: 'Missed',
                    statusColor: AppColors.missedRedBg,
                  ),
                  _HistoryItem(
                    title: 'Metformin 500mg Late',
                    subtitle: 'Taken 42 min late · HR 83 bpm',
                    time: '8:42 PM',
                    statusColor: AppColors.pendingAmberBg,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  final String label;
  final List<_HistoryItem> items;

  const _HistorySection({required this.label, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
        const SizedBox(height: 12),
        ...items,
      ],
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final Color statusColor;

  const _HistoryItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
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
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
