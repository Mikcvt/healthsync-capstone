import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/caregiver_provider.dart';
import 'caregiver_main_screen.dart';
import 'link_patient_screen.dart';

class CaregiverWelcomeScreen extends StatefulWidget {
  const CaregiverWelcomeScreen({super.key});

  @override
  State<CaregiverWelcomeScreen> createState() => _CaregiverWelcomeScreenState();
}

class _CaregiverWelcomeScreenState extends State<CaregiverWelcomeScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().currentUid;
    if (uid != null) {
      context.read<CaregiverProvider>().initForCaregiver(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUserModel;
    final name = user?.firstName.isNotEmpty == true ? user!.firstName : 'Caregiver';
    final hasPatients = context.watch<CaregiverProvider>().hasLinkedPatients;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.ledDoneBg,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.groups_2_outlined,
                  color: AppColors.caregiverGreen,
                  size: 36,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Welcome, $name',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Connect a patient to see medication schedules, dose activity, and alerts in one place.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: AppColors.textSecondary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 28),
              _StepRow(
                number: '1',
                title: 'Ask for an invite code',
                subtitle: 'The patient can find it in Guardian Link.',
              ),
              const SizedBox(height: 18),
              _StepRow(
                number: '2',
                title: 'Link their account',
                subtitle: 'Enter the code to start monitoring securely.',
              ),
              const SizedBox(height: 18),
              _StepRow(
                number: '3',
                title: 'Stay informed',
                subtitle: 'Review adherence and missed-dose alerts as they happen.',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LinkPatientScreen()),
                    );
                  },
                  icon: const Icon(Icons.link_rounded),
                  label: Text(hasPatients ? 'Link another patient' : 'Link a patient'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.caregiverGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const CaregiverMainScreen()),
                    (route) => false,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderGray),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Go to dashboard'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;

  const _StepRow({required this.number, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.caregiverGreen,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
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
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
