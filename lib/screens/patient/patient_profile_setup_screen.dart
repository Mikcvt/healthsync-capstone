import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import 'device_pairing_screen.dart';

class PatientProfileSetupScreen extends StatelessWidget {
  const PatientProfileSetupScreen({super.key});

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
            fontFamily: 'PlusJakartaSans',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              'Skip',
              style: TextStyle(
                color: AppColors.patientBlue,
                fontWeight: FontWeight.w700,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Let\'s get to know you better',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  height: 1.5,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 24),
              _FieldRow(
                left: _TextInputField(label: 'First name', hint: 'Christian'),
                right: _TextInputField(label: 'Last name', hint: 'San Luis'),
              ),
              const SizedBox(height: 14),
              _TextInputField(label: 'Date of Birth', hint: '04/05/2005'),
              const SizedBox(height: 14),
              _ToggleGroup(
                label: 'Gender',
                options: const ['Female', 'Male', 'Other'],
              ),
              const SizedBox(height: 14),
              _FieldRow(
                left: _TextInputField(
                  label: 'Email address',
                  hint: 'sanluis12345@gmail.com',
                ),
                right: _TextInputField(
                  label: 'Phone number',
                  hint: '+63 123 456 7890',
                ),
              ),
              const SizedBox(height: 14),
              _TextInputField(label: 'Address', hint: '123 Pacific Ocean'),
              const SizedBox(height: 14),
              _FieldRow(
                left: _DropdownField(label: 'Blood type', value: 'A-'),
                right: _TextInputField(
                  label: 'Allergies (optional)',
                  hint: 'Dust',
                ),
              ),
              const SizedBox(height: 14),
              _TextInputField(
                label: 'Medical conditions (optional)',
                hint: 'Hypertension',
              ),
              const SizedBox(height: 14),
              _FieldRow(
                left: _TextInputField(
                  label: 'Emergency contact name',
                  hint: 'Miko Cervantes',
                ),
                right: _TextInputField(
                  label: 'Emergency contact phone',
                  hint: '+63 123 456 7890',
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DevicePairingScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.patientBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DevicePairingScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderGray),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── FIELD ROW ─────────────────────────────────────────────────
class _FieldRow extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _FieldRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

// ── TEXT INPUT FIELD ──────────────────────────────────────────
class _TextInputField extends StatelessWidget {
  final String label;
  final String hint;

  const _TextInputField({required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      decoration: AppStyles.inputDecoration(label, hint: hint),
    );
  }
}

// ── DROPDOWN FIELD ────────────────────────────────────────────
class _DropdownField extends StatelessWidget {
  final String label;
  final String value;

  const _DropdownField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: AppStyles.inputDecoration(label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'A+', child: Text('A+')),
            DropdownMenuItem(value: 'A-', child: Text('A-')),
            DropdownMenuItem(value: 'B+', child: Text('B+')),
            DropdownMenuItem(value: 'B-', child: Text('B-')),
            DropdownMenuItem(value: 'O+', child: Text('O+')),
            DropdownMenuItem(value: 'O-', child: Text('O-')),
            DropdownMenuItem(value: 'AB+', child: Text('AB+')),
            DropdownMenuItem(value: 'AB-', child: Text('AB-')),
          ],
          onChanged: (_) {},
        ),
      ),
    );
  }
}

// ── TOGGLE GROUP ─────────────────────────────────────────────
// THIS WAS THE MISSING WIDGET — now added below
class _ToggleGroup extends StatefulWidget {
  final String label;
  final List<String> options;

  const _ToggleGroup({
    required this.label,
    required this.options,
  });

  @override
  State<_ToggleGroup> createState() => _ToggleGroupState();
}

class _ToggleGroupState extends State<_ToggleGroup> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: widget.options.map((option) {
            final isSelected = _selected == option;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selected = option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(
                    right: option != widget.options.last ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.patientBlue
                        : AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.patientBlue
                          : AppColors.borderGray,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    option,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'PlusJakartaSans',
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}