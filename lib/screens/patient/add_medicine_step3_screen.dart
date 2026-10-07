import '../../constants/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import 'add_medicine_success_screen.dart';
import '../../utils/snackbar_helper.dart';

class AddMedicineStep3Screen extends StatefulWidget {
  const AddMedicineStep3Screen({super.key});

  @override
  State<AddMedicineStep3Screen> createState() => _AddMedicineStep3ScreenState();
}

class _AddMedicineStep3ScreenState extends State<AddMedicineStep3Screen> {
  int _selectedColumn = 1;
  final _pillsCountController = TextEditingController(text: '30');
  final _thresholdController = TextEditingController(text: '5');
  bool _isSaving = false;

  @override
  void dispose() {
    _pillsCountController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final authProvider = context.read<AuthProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();
    final uid = authProvider.currentUid;

    if (uid == null) {
      SnackbarHelper.showError(context, 'You are not signed in.');
      return;
    }

    final pills = int.tryParse(_pillsCountController.text) ?? 30;
    final threshold = int.tryParse(_thresholdController.text) ?? 5;

    scheduleProvider.updateStep3(
      matBoxColumn: _selectedColumn,
      pillsRemaining: pills,
      lowStockThreshold: threshold,
    );

    setState(() => _isSaving = true);
    // A caregiver authoring for a patient saves to that patient's uid, not
    // their own.
    final success = await scheduleProvider.saveNewMedication(
      scheduleProvider.resolveSaveUid(uid),
    );
    setState(() => _isSaving = false);

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AddMedicineSuccessScreen(
            medicineName: scheduleProvider.medicationName,
            columnNumber: _selectedColumn,
            scheduledTimes: scheduleProvider.scheduledTimes,
          ),
          settings: const RouteSettings(name: addMedicineFlowRoute),
        ),
      );
    } else if (mounted) {
      SnackbarHelper.showError(
        context,
        scheduleProvider.errorMessage ?? 'Could not save this medication.',
      );
    }
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
          'Add Medicine · Step 3 of 3',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Bar
              Row(
                children: [
                  _StepBar(active: true),
                  const SizedBox(width: 8),
                  _StepBar(active: true),
                  const SizedBox(width: 8),
                  _StepBar(active: true),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'Box Compartment & Stock',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Assign this medicine to a Smart Medicine Box compartment (1 to 8) to enable automatic LED indicators.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'SELECT COMPARTMENT (1 - 8)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 12),

              // 8-Compartment Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: 8,
                itemBuilder: (ctx, index) {
                  final col = index + 1;
                  final isSelected = _selectedColumn == col;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedColumn = col),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.patientBlue : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.patientBlue : AppColors.borderGray,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: AppColors.patientBlue.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Col $col',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),

              // Inventory inputs
              TextFormField(
                controller: _pillsCountController,
                keyboardType: TextInputType.number,
                decoration: AppStyles.inputDecoration(
                  'Initial Pills Count',
                  hint: '30',
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _thresholdController,
                keyboardType: TextInputType.number,
                decoration: AppStyles.inputDecoration(
                  'Low-Stock Alert Threshold',
                  hint: '5',
                ),
              ),
              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.patientBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Medication & Finish',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
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
