import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../caregiver/caregiver_welcome_screen.dart';
import '../patient/patient_profile_setup_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _pollTimer;
  Timer? _resendTimer;
  int _resendSeconds = 0;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkVerification(showErrors: false);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerification({required bool showErrors}) async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    try {
      final verified = await context.read<AuthProvider>().reloadAndCheckEmailVerification();
      if (verified && mounted) {
        _pollTimer?.cancel();
        _continueToOnboarding();
      } else if (showErrors && mounted) {
        _showMessage('Email is not verified yet. Open the link in your inbox first.');
      }
    } catch (_) {
      if (showErrors && mounted) {
        _showMessage('We could not check verification status. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendVerification() async {
    if (_resendSeconds > 0) return;
    final authProvider = context.read<AuthProvider>();
    final sent = await authProvider.sendEmailVerification();
    if (!mounted) return;
    if (!sent) {
      _showMessage(authProvider.errorMessage ?? 'Could not send the verification email.');
      return;
    }
    setState(() => _resendSeconds = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
    _showMessage('Verification email sent. Check your inbox and spam folder.');
  }

  void _continueToOnboarding() {
    final authProvider = context.read<AuthProvider>();
    final role = ModalRoute.of(context)?.settings.arguments as String? ??
        authProvider.currentUserModel?.role ?? 'patient';
    final destination = role == 'caregiver'
        ? const CaregiverWelcomeScreen()
        : const PatientProfileSetupScreen();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final email = authProvider.currentUserModel?.email ?? 'your email address';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.ledDoneBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.mark_email_read_outlined, color: AppColors.caregiverGreen, size: 44),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verify your email',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'PlusJakartaSans'),
                ),
                const SizedBox(height: 10),
                Text(
                  'We sent a verification link to $email. Open it, then return here to continue.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'PlusJakartaSans', height: 1.6),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : () => _checkVerification(showErrors: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.patientBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isChecking
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('I verified my email'),
                  ),
                ),
                TextButton(
                  onPressed: _resendSeconds == 0 ? _resendVerification : null,
                  child: Text(_resendSeconds == 0 ? 'Resend verification email' : 'Resend in ${_resendSeconds}s'),
                ),
                TextButton(
                  onPressed: () => authProvider.signOut(),
                  child: const Text('Use a different account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
