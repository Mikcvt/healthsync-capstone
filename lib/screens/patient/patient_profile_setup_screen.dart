import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../../utils/date_formatter.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/validators.dart';
import 'device_pairing_screen.dart';

/// First-run setup for a patient.
///
/// Every field here maps to a real column in `users` or `patient_profile`.
/// Address and blood type were on the original mockup but exist nowhere in the
/// Firestore schema, so they are not collected — a field with nowhere to go is
/// worse than a missing one.
class PatientProfileSetupScreen extends StatefulWidget {
  const PatientProfileSetupScreen({super.key});

  @override
  State<PatientProfileSetupScreen> createState() =>
      _PatientProfileSetupScreenState();
}

class _PatientProfileSetupScreenState extends State<PatientProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  final _conditions = TextEditingController();
  final _allergies = TextEditingController();
  final _emergencyContact = TextEditingController();
  final _emergencyPhone = TextEditingController();

  DateTime? _dateOfBirth;
  String _gender = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUserModel;
    _firstName = TextEditingController(text: user?.firstName ?? '');
    _lastName = TextEditingController(text: user?.lastName ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
  }

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

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 40),
      firstDate: DateTime(now.year - 110),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  /// Saves, then continues. A failure keeps the patient on this screen with a
  /// message — the previous version pushed on regardless and dropped every
  /// value the patient had typed.
  Future<void> _onContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();
    final patient = context.read<PatientProvider>();

    final identitySaved = await auth.updateProfile(
      firstName: _firstName.text,
      lastName: _lastName.text,
      phone: _phone.text,
    );
    final clinicalSaved = await patient.saveProfileDetails(
      medicalConditions: _conditions.text,
      allergies: _allergies.text,
      emergencyContact: _emergencyContact.text.trim(),
      emergencyPhone: _emergencyPhone.text.trim(),
      dateOfBirth: _dateOfBirth,
      gender: _gender,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!identitySaved || !clinicalSaved) {
      SnackbarHelper.showError(
        context,
        auth.errorMessage ?? patient.errorMessage ?? AppStrings.genericError,
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DevicePairingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            fontFamily: AppStyles.fontFamily,
          ),
        ),
        actions: [
          TextButton(
            // A genuine skip: it saves nothing and says so by going straight
            // to the dashboard, rather than mimicking the Continue button.
            onPressed: _isSaving
                ? null
                : () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text(
              'Skip for now',
              style: TextStyle(
                color: AppColors.patientBlue,
                fontWeight: FontWeight.w700,
                fontFamily: AppStyles.fontFamily,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Let's get to know you better",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    height: 1.5,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstName,
                        textCapitalization: TextCapitalization.words,
                        decoration: AppStyles.inputDecoration('First name'),
                        validator: (v) =>
                            Validators.name(v, label: 'first name'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastName,
                        textCapitalization: TextCapitalization.words,
                        decoration: AppStyles.inputDecoration('Last name'),
                        validator: (v) => Validators.name(v, label: 'last name'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                InkWell(
                  onTap: _pickDateOfBirth,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: AppStyles.inputDecoration('Date of birth'),
                    child: Text(
                      _dateOfBirth == null
                          ? 'Tap to choose'
                          : DateFormatter.toShortDate(_dateOfBirth!),
                      style: TextStyle(
                        fontSize: 14,
                        color: _dateOfBirth == null
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        fontFamily: AppStyles.fontFamily,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                _ToggleGroup(
                  label: 'Gender',
                  options: const ['Female', 'Male', 'Other'],
                  selected: _gender,
                  onChanged: (value) => setState(() => _gender = value),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: AppStyles.inputDecoration(
                    'Phone number',
                    hint: 'Optional',
                  ),
                  validator: (v) => Validators.phone(v),
                ),
                const SizedBox(height: 26),

                const Text(
                  'Medical details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Optional, and you can change these any time. Separate '
                  'multiple entries with a comma.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.5,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _allergies,
                  maxLines: 2,
                  decoration: AppStyles.inputDecoration(
                    'Allergies',
                    hint: 'e.g. Penicillin, peanuts',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _conditions,
                  maxLines: 2,
                  decoration: AppStyles.inputDecoration(
                    'Medical conditions',
                    hint: 'e.g. Hypertension',
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _emergencyContact,
                        textCapitalization: TextCapitalization.words,
                        decoration:
                            AppStyles.inputDecoration('Emergency contact'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _emergencyPhone,
                        keyboardType: TextInputType.phone,
                        decoration:
                            AppStyles.inputDecoration('Contact number'),
                        validator: (v) => Validators.phone(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.patientBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.borderGray,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save and continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamily: AppStyles.fontFamily,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single-select row of pills, for short option sets where a dropdown would
/// hide the choices.
class _ToggleGroup extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _ToggleGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            fontFamily: AppStyles.fontFamily,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: options.map((option) {
            final isSelected = option == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ChoiceChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (_) => onChanged(isSelected ? '' : option),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: AppStyles.fontFamily,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
                selectedColor: AppColors.patientBlue,
                backgroundColor: AppColors.cardWhite,
                side: const BorderSide(color: AppColors.borderGray),
                showCheckmark: false,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
