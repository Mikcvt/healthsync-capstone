import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../patient/patient_profile_setup_screen.dart';
import 'email_verification_screen.dart';

class RegisterScreen extends StatelessWidget {
  final String role;

  const RegisterScreen({super.key, this.role = 'patient'});

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Create your account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You are signing up as a ${role.toUpperCase()} user.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontFamily: 'PlusJakartaSans',
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: nameController,
                decoration: AppStyles.inputDecoration(
                  'Full name',
                  hint: 'Juan Dela Cruz',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: AppStyles.inputDecoration(
                  'Email',
                  hint: 'you@example.com',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: AppStyles.inputDecoration(
                  'Password',
                  hint: 'Create a strong password',
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderGray),
                ),
                child: Row(
                  children: [
                    Icon(
                      role == 'caregiver'
                          ? Icons.groups_2_outlined
                          : Icons.person_outline_rounded,
                      color: role == 'caregiver'
                          ? AppColors.caregiverGreen
                          : AppColors.patientBlue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        role == 'caregiver'
                            ? 'Caregiver account'
                            : 'Patient account',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.caregiverGreen,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    if (role == 'patient') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PatientProfileSetupScreen(),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EmailVerificationScreen(),
                          settings: RouteSettings(arguments: role),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.caregiverGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Create account',
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
