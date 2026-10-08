import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../models/dose_slot.dart';
import '../../providers/patient_provider.dart';
import '../../utils/date_formatter.dart';
import '../../utils/dose_timing.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/patient/dose_reason_picker.dart';

/// Asks why a dose was missed (DOSE_LOGIC_PROPOSAL.md, section 7).
///
/// Opened by tapping a missed dose on the dashboard — previously nothing led
/// here. "I took it but forgot to log it" is offered until the end of the
/// next day; it asks roughly when the dose was taken and records it as taken,
/// labelled "Logged late". Every other reason keeps the dose missed.
class MissedDoseScreen extends StatefulWidget {
  final DoseSlot slot;
  final String medicineName;

  const MissedDoseScreen({
    super.key,
    required this.slot,
    this.medicineName = 'Your medication',
  });

  @override
  State<MissedDoseScreen> createState() => _MissedDoseScreenState();
}

class _MissedDoseScreenState extends State<MissedDoseScreen> {
  bool _isSaving = false;
  String? _reason;

  bool get _retroAllowed =>
      DoseTiming.retroLogAllowed(widget.slot.scheduledAt, DateTime.now());

  /// "About what time did you take it?", defaulting to the dose time. The
  /// answer must already have passed and be no earlier than the dose could
  /// have been logged early.
  Future<DateTime?> _askTakenTime() async {
    final scheduled = widget.slot.scheduledAt;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(scheduled),
      helpText: 'About what time did you take it?',
    );
    if (picked == null || !mounted) return null;

    // The dose's own day, unless that would put the time before the earliest
    // it could be taken — then it was after midnight, on the next day.
    var takenAt = DateTime(
      scheduled.year,
      scheduled.month,
      scheduled.day,
      picked.hour,
      picked.minute,
    );
    final earliest = scheduled.subtract(DoseTiming.earlyCap);
    if (takenAt.isBefore(earliest)) {
      takenAt = takenAt.add(const Duration(days: 1));
    }
    if (takenAt.isAfter(DateTime.now())) {
      SnackbarHelper.showError(context, AppStrings.retroTimeInFuture);
      return null;
    }
    return takenAt;
  }

  Future<void> _onSave() async {
    final reason = _reason;
    if (reason == null) return;
    final patient = context.read<PatientProvider>();

    final DoseActionResult result;
    if (reason == AppStrings.reasonTookButForgot) {
      final takenAt = await _askTakenTime();
      if (takenAt == null || !mounted) return;
      setState(() => _isSaving = true);
      result = await patient.logTakenLate(widget.slot, takenAt);
    } else {
      setState(() => _isSaving = true);
      result = await patient.saveMissedReason(widget.slot, reason);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    switch (result) {
      case DoseActionResult.success:
        SnackbarHelper.showSuccess(
          context,
          reason == AppStrings.reasonTookButForgot
              ? 'Recorded as taken (logged late).'
              : 'Reason recorded.',
        );
        Navigator.of(context).pop();
      case DoseActionResult.alreadyConfirmed:
        SnackbarHelper.showInfo(context, AppStrings.doseAlreadyTaken);
        Navigator.of(context).pop();
      case DoseActionResult.failed:
      case DoseActionResult.snoozeLimitReached:
        SnackbarHelper.showError(
          context,
          patient.errorMessage ?? AppStrings.genericError,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasons = [
      if (_retroAllowed) AppStrings.reasonTookButForgot,
      ...AppStrings.doseReasons,
    ];

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
          'Missed dose',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.missedRedBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.missedRed.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.missedRed.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.warning_amber_rounded,
                                color: AppColors.missedRed),
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
                                  'Was due ${DateFormatter.doseDayTime(widget.slot.scheduledAt)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'What happened?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _retroAllowed
                          ? 'Your caregiver will see this. If you did take it, '
                              'choose the first option and it will count as '
                              'taken, marked "Logged late".'
                          : 'Your caregiver will see this. This dose is too '
                              'old to change to taken.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DoseReasonPicker(
                      reasons: reasons,
                      onChanged: (reason) => setState(() => _reason = reason),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving || _reason == null ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _reason == AppStrings.reasonTookButForgot
                        ? AppColors.caregiverGreen
                        : AppColors.missedRed,
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
                      : Text(
                          _reason == AppStrings.reasonTookButForgot
                              ? 'Choose the time I took it'
                              : 'Save reason',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
