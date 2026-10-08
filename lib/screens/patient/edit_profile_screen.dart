import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/validators.dart';

/// Lets a patient edit their own details.
///
/// Two fields live in different places: name, phone and email belong to
/// `users/{uid}` and go through [AuthProvider]; conditions, allergies and the
/// emergency contact belong to `patient_profile/{uid}` and go through
/// [PatientProvider]. Both are saved by the one button, and a failure in either
/// is reported rather than swallowed.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _conditions;
  late final TextEditingController _allergies;
  late final TextEditingController _emergencyContact;
  late final TextEditingController _emergencyPhone;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Prefilled from the signed-in user's real documents. These used to be
    // `hint` values for a teammate's details, so every patient opened this
    // screen looking at somebody else's name and blood type.
    final user = context.read<AuthProvider>().currentUserModel;
    final profile = context.read<PatientProvider>().profile;

    _firstName = TextEditingController(text: user?.firstName ?? '');
    _lastName = TextEditingController(text: user?.lastName ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _conditions =
        TextEditingController(text: profile?.medicalConditions.join(', ') ?? '');
    _allergies =
        TextEditingController(text: profile?.allergies.join(', ') ?? '');
    _emergencyContact =
        TextEditingController(text: profile?.emergencyContact ?? '');
    _emergencyPhone = TextEditingController(text: profile?.emergencyPhone ?? '');
  }

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _phone,
      _conditions,
      _allergies,
      _emergencyContact,
      _emergencyPhone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _onSave() async {
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
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (identitySaved && clinicalSaved) {
      SnackbarHelper.showSuccess(context, 'Profile updated.');
      Navigator.of(context).pop();
      return;
    }

    // Partial success is reported honestly: silently popping here is what let
    // the old screen look like it had saved when it had written nothing.
    SnackbarHelper.showError(
      context,
      auth.errorMessage ?? patient.errorMessage ?? AppStrings.genericError,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = context.select<AuthProvider, String>(
      (auth) => auth.currentUserModel?.email ?? '',
    );
    final isManaged = context.select<AuthProvider, bool>(
      (auth) => auth.isManaged,
    );

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
            fontFamily: AppStyles.fontFamily,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
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
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _firstName,
                  textCapitalization: TextCapitalization.words,
                  decoration: AppStyles.inputDecoration('First name'),
                  validator: (v) => Validators.name(v, label: 'first name'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _lastName,
                  textCapitalization: TextCapitalization.words,
                  decoration: AppStyles.inputDecoration('Last name'),
                  validator: (v) => Validators.name(v, label: 'last name'),
                ),
                const SizedBox(height: 14),

                // A managed patient's account carries no real email — it was
                // created by their caregiver — so there is nothing to show or
                // change here for them.
                if (!isManaged) ...[
                  TextFormField(
                    initialValue: email,
                    readOnly: true,
                    decoration: AppStyles.inputDecoration(
                      'Email address',
                      hint: 'Contact support to change this',
                    ),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                ],

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
                  'Separate multiple entries with a comma.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _conditions,
                  maxLines: 2,
                  decoration: AppStyles.inputDecoration(
                    'Medical conditions',
                    hint: 'e.g. Hypertension, Type 2 diabetes',
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
                  controller: _emergencyContact,
                  textCapitalization: TextCapitalization.words,
                  decoration: AppStyles.inputDecoration(
                    'Emergency contact name',
                    hint: 'Optional',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emergencyPhone,
                  keyboardType: TextInputType.phone,
                  decoration: AppStyles.inputDecoration(
                    'Emergency contact number',
                    hint: 'Optional',
                  ),
                  validator: (v) => Validators.phone(v),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _onSave,
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
                            'Save changes',
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
