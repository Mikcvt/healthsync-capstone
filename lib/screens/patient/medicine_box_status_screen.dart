import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';

class MedicineBoxStatusScreen extends StatelessWidget {
  const MedicineBoxStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Medicine box',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Device status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 12),
              _DeviceStatRow(label: 'Connection', value: 'Online'),
              const SizedBox(height: 8),
              _DeviceStatRow(label: 'Battery', value: '84%'),
              const SizedBox(height: 8),
              _DeviceStatRow(label: 'Last sync', value: '4 minutes ago'),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                decoration: AppStyles.cardDecoration,
                padding: const EdgeInsets.all(18),
                child: const Text(
                  'Your medicine box is connected and ready to support your schedule.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontFamily: 'PlusJakartaSans',
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

class _DeviceStatRow extends StatelessWidget {
  final String label;
  final String value;

  const _DeviceStatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
      ],
    );
  }
}
