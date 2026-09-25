import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/caregiver_provider.dart';
import 'caregiver_main_screen.dart';

class LinkPatientScreen extends StatefulWidget {
  const LinkPatientScreen({super.key});

  @override
  State<LinkPatientScreen> createState() => _LinkPatientScreenState();
}

class _LinkPatientScreenState extends State<LinkPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _relationshipController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().currentUid;
    if (uid != null) {
      context.read<CaregiverProvider>().initForCaregiver(uid);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _linkPatient() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<CaregiverProvider>();
    final success = await provider.linkPatient(_codeController.text);
    if (!mounted) return;

    if (success) {
      final patientName = provider.selectedPatientUser?.fullName ?? 'Patient';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$patientName linked successfully.'),
          backgroundColor: AppColors.caregiverGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CaregiverMainScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'Could not link this patient.',
          ),
          backgroundColor: AppColors.missedRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CaregiverProvider>();
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
          onPressed: provider.isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Link Patient',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ask your patient to share the invite code from Profile > Guardian Link. Enter it below to connect their account.',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.7,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  decoration: AppStyles.inputDecoration(
                    'Patient invite code',
                    hint: 'HS-ABCD',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter the invite code';
                    }
                    if (!value.trim().toUpperCase().startsWith('HS-')) {
                      return 'Invite codes start with HS-';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _relationshipController,
                  decoration: AppStyles.inputDecoration(
                    'Your relationship (optional)',
                    hint: 'Parent, spouse, or guardian',
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) =>
                      provider.isLoading ? null : _linkPatient(),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: provider.isLoading ? null : _linkPatient,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.caregiverGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.caregiverGreen
                          .withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: provider.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Link Patient',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
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
