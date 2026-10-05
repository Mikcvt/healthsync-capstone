import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/caregiver_provider.dart';
import '../../utils/snackbar_helper.dart';
import 'generate_otp_screen.dart';

/// Creates a managed patient account on the caregiver's behalf.
///
/// The patient is not present for any of this and never fills in a form — by
/// the time they type their code, this screen has already built their account.
class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _conditions = TextEditingController();
  final _allergies = TextEditingController();
  final _emergencyContact = TextEditingController();
  final _emergencyPhone = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    for (final c in [
      _firstName,
      _lastName,
      _phone,
      _conditions,
      _allergies,
      _emergencyContact,
      _emergencyPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _submitting) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    final caregiver = context.read<CaregiverProvider>();
    final uid = await caregiver.createPatient(
      firstName: _firstName.text,
      lastName: _lastName.text,
      phone: _phone.text,
      medicalConditions: _conditions.text,
      allergies: _allergies.text,
      emergencyContact: _emergencyContact.text,
      emergencyPhone: _emergencyPhone.text,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (uid == null) {
      SnackbarHelper.showError(
        context,
        caregiver.errorMessage ?? 'Could not add this patient. Please try again.',
      );
      return;
    }

    // Straight to the code: an account with no way to reach the patient is of
    // no use to the caregiver yet.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GenerateOtpScreen(
          patientUid: uid,
          patientName: '${_firstName.text.trim()} ${_lastName.text.trim()}',
          isNewPatient: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add a patient',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.ledDoneBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 20, color: AppColors.greenDark),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You are creating the account for them. They will not '
                        'sign up or choose a password — you will give them a '
                        'code to open the app.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.greenDark,
                          fontFamily: 'PlusJakartaSans',
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              _SectionLabel('Who are they?'),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _firstName,
                      label: 'First name',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _lastName,
                      label: 'Last name',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _phone,
                label: 'Phone number (optional)',
                keyboardType: TextInputType.phone,
                helper: 'Used if you send their code by SMS.',
              ),

              const SizedBox(height: 24),
              _SectionLabel('Medical details (optional)'),
              _Field(
                controller: _conditions,
                label: 'Medical conditions',
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _allergies,
                label: 'Allergies',
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),

              const SizedBox(height: 24),
              _SectionLabel('Emergency contact (optional)'),
              _Field(
                controller: _emergencyContact,
                label: 'Contact name',
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _emergencyPhone,
                label: 'Contact phone',
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 28),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.caregiverGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.borderGray,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Create account & get code',
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? helper;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    this.helper,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        color: AppColors.textPrimary,
        fontFamily: 'PlusJakartaSans',
      ),
      decoration: AppStyles.inputDecoration(label).copyWith(
        helperText: helper,
        helperStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.textMuted,
          fontFamily: 'PlusJakartaSans',
        ),
      ),
    );
  }
}
