import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../providers/patient_provider.dart';
import '../../utils/snackbar_helper.dart';

/// Records why a dose was missed, into `dose_logs.skipped_reason`.
///
/// The reason picker was already here but the button only showed a SnackBar
/// reading "Missed dose reason recorded." and wrote nothing. The screen also
/// had no route into it from anywhere in the app.
class MissedDoseScreen extends StatefulWidget {
  final String medicineName;
  final String scheduledTime;

  /// The dose being explained. Without it there is nothing to write the reason
  /// to, and the screen says so rather than appearing to save.
  final String? doseLogId;
  final String? scheduleId;

  const MissedDoseScreen({
    super.key,
    this.medicineName = 'Your medication',
    this.scheduledTime = '',
    this.doseLogId,
    this.scheduleId,
  });

  @override
  State<MissedDoseScreen> createState() => _MissedDoseScreenState();
}

class _MissedDoseScreenState extends State<MissedDoseScreen> {
  bool _isSaving = false;
  String _selectedReason = 'Forgot to take';
  final List<String> _reasons = [
    'Forgot to take',
    'Felt sick / side effects',
    'Was away from medicine box',
    'Prescription ran out',
    'Other reason',
  ];

  /// Writes the reason onto the dose log, marking it missed.
  Future<void> _onLogReason() async {
    final doseLogId = widget.doseLogId;

    // Nothing to attach the reason to. The cron sweep will still mark the dose
    // missed on its own, so this is informational rather than an error.
    if (doseLogId == null || doseLogId.isEmpty) {
      SnackbarHelper.showInfo(
        context,
        'This dose has no record to update yet.',
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSaving = true);
    final patient = context.read<PatientProvider>();
    final result = await patient.markDoseMissed(
      doseLogId: doseLogId,
      reason: _selectedReason,
      scheduleId: widget.scheduleId,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result == DoseActionResult.success) {
      SnackbarHelper.showSuccess(context, 'Reason recorded.');
      Navigator.of(context).pop();
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
          'Missed Dose Alert',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.medicineName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scheduled for ${widget.scheduledTime}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Select Reason for Missing Dose',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'This will be shared with your caregiver so they can provide support if needed.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              ..._reasons.map((r) {
                final isSelected = _selectedReason == r;
                return GestureDetector(
                  onTap: () => setState(() => _selectedReason = r),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.patientBlue.withValues(alpha: 0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.patientBlue : AppColors.borderGray,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? AppColors.patientBlue : AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            r,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: isSelected ? AppColors.patientBlue : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _onLogReason,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.missedRed,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.borderGray,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text('Log Reason & Dismiss', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
