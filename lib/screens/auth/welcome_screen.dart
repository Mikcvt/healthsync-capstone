import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../constants/app_colors.dart';
import 'login_screen.dart';
import 'role_select_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── TOP GRADIENT HERO ─────────────────────────────
          Container(
            height: MediaQuery.of(context).size.height * 0.42,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4A90D9), // top-left blue
                  Color(0xFF2BB5A0), // bottom-right teal-green
                ],
              ),
            ),
            child: Stack(
              children: [
                // Background decorative circles
                Positioned(
                  top: -30,
                  right: -20,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.10),
                    ),
                  ),
                ),
                Positioned(
                  top: 60,
                  right: 30,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: -30,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.07),
                    ),
                  ),
                ),
                // Center content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // App icon box
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.35),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.favorite_border_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // App name
                      const Text(
                        'HealthSync',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFamily: 'PlusJakartaSans',
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Tagline
                      Text(
                        'Smart Medication Companion',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.85),
                          fontFamily: 'PlusJakartaSans',
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── BOTTOM WHITE CONTENT ──────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),

                  // Headline
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Never miss a dose ',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            fontFamily: 'PlusJakartaSans',
                            height: 1.2,
                          ),
                        ),
                        TextSpan(
                          text: 'again.',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2BB5A0),
                            fontFamily: 'PlusJakartaSans',
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Description
                  Text(
                    'HealthSync keeps you and your loved ones on track with smart LED guidance, wrist alerts, and real-time caregiver monitoring',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[600],
                      fontFamily: 'PlusJakartaSans',
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Feature rows
                  _FeatureRow(
                    icon: Icons.medical_services_outlined,
                    iconBgColor: const Color(0xFFEBF1FF),
                    iconColor: const Color(0xFF1B5FD4),
                    text: 'LED-guided smart medicine box',
                  ),
                  const SizedBox(height: 14),
                  _FeatureRow(
                    icon: Icons.access_time_outlined,
                    iconBgColor: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFF59E0B),
                    text: 'Smartwatch vibration reminders',
                  ),
                  const SizedBox(height: 14),
                  _FeatureRow(
                    icon: Icons.group_outlined,
                    iconBgColor: const Color(0xFFE4F7F0),
                    iconColor: const Color(0xFF0D9B6B),
                    text: 'Real-time caregiver monitoring',
                  ),
                  const SizedBox(height: 32),

                  // Get Started button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RoleSelectScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9B6B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'PlusJakartaSans',
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Already have account button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Already have an account?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'PlusJakartaSans',
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Terms & Privacy
                  Center(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'By continuing to our ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                          TextSpan(
                            text: 'Terms & Privacy',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1B5FD4),
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.w600,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                // open terms
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── FEATURE ROW WIDGET ────────────────────────────────────────
class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String text;

  const _FeatureRow({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF0F172A),
            fontFamily: 'PlusJakartaSans',
          ),
        ),
      ],
    );
  }
}
