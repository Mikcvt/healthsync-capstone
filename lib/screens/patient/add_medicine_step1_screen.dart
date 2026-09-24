import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/schedule_provider.dart';
import 'add_medicine_step2_screen.dart';

class AddMedicineStep1Screen extends StatefulWidget {
  const AddMedicineStep1Screen({super.key});

  @override
  State<AddMedicineStep1Screen> createState() => _AddMedicineStep1ScreenState();
}

class _AddMedicineStep1ScreenState extends State<AddMedicineStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _genericController = TextEditingController();
  final _dosageController = TextEditingController(text: '500mg');
  final _doctorController = TextEditingController();
  final _purposeController = TextEditingController();

  String _dosageForm = 'Tablet';
  final List<String> _forms = ['Tablet', 'Capsule', 'Liquid', 'Drops', 'Inhaler', 'Injection'];

  @override
  void dispose() {
    _nameController.dispose();
    _genericController.dispose();
    _dosageController.dispose();
    _doctorController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (!_formKey.currentState!.validate()) return;

    context.read<ScheduleProvider>().updateStep1(
      medicationName: _nameController.text.trim(),
      genericName: _genericController.text.trim(),
      dosageForm: _dosageForm,
      prescribedDosage: _dosageController.text.trim(),
      prescribingDoctor: _doctorController.text.trim(),
      purpose: _purposeController.text.trim(),
    );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddMedicineStep2Screen()),
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Medicine · Step 1 of 3',
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step Progress Indicator
                Row(
                  children: [
                    _StepBar(active: true),
                    const SizedBox(width: 8),
                    _StepBar(active: false),
                    const SizedBox(width: 8),
                    _StepBar(active: false),
                  ],
                ),
                const SizedBox(height: 24),

                const Text(
                  'Basic Medication Info',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter the medication name and prescribed dosage from your prescription.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                const SizedBox(height: 24),

                // Medicine Name
                TextFormField(
                  controller: _nameController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter medication name' : null,
                  decoration: AppStyles.inputDecoration(
                    'Medication Name *',
                    hint: 'e.g., Metformin, Amoxicillin',
                  ),
                ),
                const SizedBox(height: 16),

                // Generic Name (Optional)
                TextFormField(
                  controller: _genericController,
                  decoration: AppStyles.inputDecoration(
                    'Generic Name (Optional)',
                    hint: 'e.g., Metformin Hydrochloride',
                  ),
                ),
                const SizedBox(height: 16),

                // Dosage Form Selector
                const Text(
                  'Dosage Form',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _forms.map((f) {
                    final selected = _dosageForm == f;
                    return ChoiceChip(
                      label: Text(f),
                      selected: selected,
                      onSelected: (val) {
                        if (val) setState(() => _dosageForm = f);
                      },
                      selectedColor: AppColors.patientBlue,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selected ? AppColors.patientBlue : AppColors.borderGray,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Prescribed Dosage
                TextFormField(
                  controller: _dosageController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter dosage strength' : null,
                  decoration: AppStyles.inputDecoration(
                    'Dosage Strength *',
                    hint: 'e.g., 500mg, 10ml, 1 puff',
                  ),
                ),
                const SizedBox(height: 16),

                // Purpose
                TextFormField(
                  controller: _purposeController,
                  decoration: AppStyles.inputDecoration(
                    'Treatment Purpose (Optional)',
                    hint: 'e.g., Blood sugar regulation, Hypertension',
                  ),
                ),
                const SizedBox(height: 16),

                // Prescribing Doctor
                TextFormField(
                  controller: _doctorController,
                  decoration: AppStyles.inputDecoration(
                    'Prescribing Doctor (Optional)',
                    hint: 'e.g., Dr. Santos',
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.patientBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Continue to Timing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  final bool active;
  const _StepBar({required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 5,
        decoration: BoxDecoration(
          color: active ? AppColors.patientBlue : AppColors.borderGray,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
