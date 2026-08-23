import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Edit profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update your personal information below.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 20),
              _ProfileField(label: 'First name', hint: 'Christian'),
              const SizedBox(height: 14),
              _ProfileField(label: 'Last name', hint: 'San Luis'),
              const SizedBox(height: 14),
              _ProfileField(
                label: 'Email address',
                hint: 'sanluis12345@gmail.com',
              ),
              const SizedBox(height: 14),
              _ProfileField(label: 'Phone number', hint: '+63 912 345 6789'),
              const SizedBox(height: 14),
              _ProfileField(label: 'Date of birth', hint: '04/05/2005'),
              const SizedBox(height: 14),
              _ProfileField(label: 'Blood type', hint: 'A-'),
              const SizedBox(height: 14),
              _ProfileField(label: 'Allergies', hint: 'Dust'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.patientBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Save changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'PlusJakartaSans',
                    ),
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

class _ProfileField extends StatelessWidget {
  final String label;
  final String hint;

  const _ProfileField({required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      decoration: AppStyles.inputDecoration(label, hint: hint),
      initialValue: hint,
    );
  }
}
