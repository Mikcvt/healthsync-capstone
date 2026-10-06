import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../models/schedule_model.dart';
import '../../providers/patient_provider.dart';
import '../../utils/snackbar_helper.dart';

class DeleteMedicineScreen extends StatefulWidget {
  final ScheduleModel? schedule;

  const DeleteMedicineScreen({super.key, this.schedule});

  @override
  State<DeleteMedicineScreen> createState() => _DeleteMedicineScreenState();
}

class _DeleteMedicineScreenState extends State<DeleteMedicineScreen> {
  bool _isDeleting = false;

  /// Retires the medication **and** its schedules.
  ///
  /// The previous version deactivated only this one schedule, leaving the
  /// `patient_medications` document active — so the medicine stayed in the
  /// patient's list with its dose times gone. It also wrote through a
  /// FirestoreService built inside the widget, with no error handling.
  Future<void> _onDelete() async {
    final schedule = widget.schedule;
    if (schedule == null) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isDeleting = true);
    final patient = context.read<PatientProvider>();
    final deleted = await patient.deleteMedication(schedule.patMedRef);

    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (deleted) {
      SnackbarHelper.showSuccess(context, 'Medication removed.');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      SnackbarHelper.showError(
        context,
        patient.errorMessage ?? AppStrings.genericError,
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
          'Remove Medication',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.redAccent,
                  size: 44,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Are you sure?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This will remove this scheduled dose (${widget.schedule?.scheduledTime ?? "dose"}) from your daily reminders and disable its smart box LED indicator.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isDeleting ? null : _onDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isDeleting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Yes, Remove Medication',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: const BorderSide(color: AppColors.borderGray),
                  ),
                  child: const Text(
                    'Cancel · Keep in Schedule',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
