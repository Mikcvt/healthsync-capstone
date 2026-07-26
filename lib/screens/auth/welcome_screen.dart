import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'login_screen.dart';
import 'role_select_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 28),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: const Icon(Icons.medication_rounded, color: Colors.white, size: 46),
                ),
                const SizedBox(height: 24),
                const Text(
                  'HealthSync',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Smart medication guidance for patients and caregivers',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontFamily: 'PlusJakartaSans',
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Never miss a dose again',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Use smart reminders, LED-guided medicine box signals, and caregiver monitoring in one calm experience.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontFamily: 'PlusJakartaSans',
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _FeatureRow(
                          icon: Icons.medical_services_outlined,
                          color: AppColors.patientBlue,
                          bgColor: const Color(0xFFEBF1FF),
                          text: 'LED-guided smart medicine box',
                        ),
                        const SizedBox(height: 14),
                        _FeatureRow(
                          icon: Icons.notifications_active_outlined,
                          color: const Color(0xFFF59E0B),
                          bgColor: const Color(0xFFFEF3C7),
                          text: 'Timely reminders and alerts',
                        ),
                        const SizedBox(height: 14),
                        _FeatureRow(
                          icon: Icons.groups_2_outlined,
                          color: AppColors.caregiverGreen,
                          bgColor: const Color(0xFFE4F7F0),
                          text: 'Real-time caregiver monitoring',
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.caregiverGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Get Started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.borderGray, width: 1.2),
                              foregroundColor: AppColors.textPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('I already have an account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(text: 'By continuing, you agree to our ', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontFamily: 'PlusJakartaSans')),
                                TextSpan(
                                  text: 'Terms & Privacy',
                                  style: const TextStyle(color: AppColors.patientBlue, fontWeight: FontWeight.w700, fontSize: 12, fontFamily: 'PlusJakartaSans'),
                                  recognizer: TapGestureRecognizer()..onTap = () {},
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String text;

  const _FeatureRow({required this.icon, required this.color, required this.bgColor, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'PlusJakartaSans')),
        ),
      ],
    );
  }
}
