import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_styles.dart';
import '../../models/schedule_model.dart';
import '../../providers/patient_provider.dart';
import '../../utils/snackbar_helper.dart';
import 'dose_confirmed_screen.dart';

/// The full-screen prompt for a dose that is due.
///
/// All three actions write to Firestore. Snooze in particular used to show a
/// SnackBar reading "Dose snoozed for 10 minutes" and write nothing at all — no
/// snooze count, no state change, no re-trigger — so the three-snooze cap in
/// the spec existed only in a provider method that nothing called.
class DoseAlertScreen extends StatefulWidget {
  final ScheduleModel? schedule;
  final String medicineName;
  final String doseTime;
  final int columnNumber;

  /// The dose log this alert belongs to, when one has been materialised. Needed
  /// to carry the snooze count — without it a snooze cannot be counted, and the
  /// cap cannot be enforced.
  final String? doseLogId;

  const DoseAlertScreen({
    super.key,
    this.schedule,
    this.medicineName = 'Your medication',
    this.doseTime = '',
    this.columnNumber = 1,
    this.doseLogId,
  });

  @override
  State<DoseAlertScreen> createState() => _DoseAlertScreenState();
}

class _DoseAlertScreenState extends State<DoseAlertScreen> {
  bool _isBusy = false;

  String? get _scheduleId => widget.schedule?.scheduleId;

  /// The log for this dose, preferring an explicit id and falling back to
  /// today's materialised log for the schedule.
  String? _resolveDoseLogId(PatientProvider patient) {
    if (widget.doseLogId != null && widget.doseLogId!.isNotEmpty) {
      return widget.doseLogId;
    }
    if (_scheduleId == null) return null;
    return patient.todayLogForSchedule(_scheduleId!)?.doseLogId;
  }

  Future<void> _onTake() async {
    final scheduleId = _scheduleId;
    if (scheduleId == null) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isBusy = true);
    final patient = context.read<PatientProvider>();
    final result = await patient.confirmDoseTaken(
      scheduleId: scheduleId,
      doseLogId: _resolveDoseLogId(patient),
    );

    if (!mounted) return;
    setState(() => _isBusy = false);

    switch (result) {
      case DoseActionResult.success:
      case DoseActionResult.alreadyConfirmed:
        if (result == DoseActionResult.alreadyConfirmed) {
          SnackbarHelper.showInfo(context, AppStrings.doseAlreadyTaken);
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DoseConfirmedScreen(
              medicineName: widget.medicineName,
              timeTaken: 'Just now',
            ),
          ),
        );
      case DoseActionResult.failed:
      case DoseActionResult.snoozeLimitReached:
        SnackbarHelper.showError(
          context,
          patient.errorMessage ?? AppStrings.doseConfirmFailed,
        );
    }
  }

  Future<void> _onSnooze() async {
    final patient = context.read<PatientProvider>();
    final doseLogId = _resolveDoseLogId(patient);

    // Without a dose log there is nothing to count a snooze against. Say so
    // rather than pretending the snooze was recorded.
    if (doseLogId == null) {
      SnackbarHelper.showInfo(
        context,
        'This dose cannot be snoozed yet. Confirm it when you take it.',
      );
      return;
    }

    final current = patient.todayLogForSchedule(_scheduleId ?? '');
    setState(() => _isBusy = true);
    final result = await patient.snoozeDose(
      doseLogId: doseLogId,
      currentSnoozeCount: current?.snoozeCount ?? 0,
      scheduleId: _scheduleId,
    );

    if (!mounted) return;
    setState(() => _isBusy = false);

    switch (result) {
      case DoseActionResult.success:
        SnackbarHelper.showInfo(context, AppStrings.doseSnoozed);
        Navigator.of(context).pop();
      case DoseActionResult.snoozeLimitReached:
        SnackbarHelper.showWarning(context, AppStrings.doseSnoozeLimit);
        Navigator.of(context).pop();
      case DoseActionResult.alreadyConfirmed:
        SnackbarHelper.showInfo(context, AppStrings.doseAlreadyTaken);
        Navigator.of(context).pop();
      case DoseActionResult.failed:
        SnackbarHelper.showError(
          context,
          patient.errorMessage ?? AppStrings.genericError,
        );
    }
  }

  Future<void> _onSkip() async {
    final patient = context.read<PatientProvider>();
    final doseLogId = _resolveDoseLogId(patient);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Skip this dose?'),
        content: const Text(
          'This will be recorded as a missed dose, and your caregiver may be '
          'notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Skip dose',
              style: TextStyle(color: AppColors.missedRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Dismissing without a log leaves nothing to mark — the cron sweep will
    // pick the dose up once it is 30 minutes overdue.
    if (doseLogId == null) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isBusy = true);
    final result = await patient.markDoseMissed(
      doseLogId: doseLogId,
      reason: 'Skipped by patient',
      scheduleId: _scheduleId,
    );

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result == DoseActionResult.success) {
      SnackbarHelper.showInfo(context, AppStrings.doseMissed);
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
    final activeCol = widget.schedule?.matBoxColumn ?? widget.columnNumber;
    final activeTime = widget.schedule?.scheduledTime ?? widget.doseTime;
    final snoozeCount =
        context
            .watch<PatientProvider>()
            .todayLogForSchedule(_scheduleId ?? '')
            ?.snoozeCount ??
        0;

    return Scaffold(
      backgroundColor: AppColors.textPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              const Spacer(),

              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: AppColors.patientBlue.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.patientBlue, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.patientBlue.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.alarm_on_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.patientBlue.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  activeTime.isEmpty
                      ? 'DOSE REMINDER'
                      : 'DOSE REMINDER · $activeTime',
                  style: const TextStyle(
                    color: Colors.lightBlueAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                widget.medicineName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'Please take your dose from compartment $activeCol of your '
                'smart medicine box.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.5,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lightbulb,
                      color: Colors.amberAccent,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Compartment $activeCol is lit',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppStyles.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),

              if (snoozeCount > 0) ...[
                const SizedBox(height: 14),
                Text(
                  snoozeCount >= 3
                      ? 'Snoozed 3 times — the next snooze marks this missed'
                      : 'Snoozed $snoozeCount of 3 times',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
              ],

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isBusy ? null : _onTake,
                  icon: _isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                        ),
                  label: const Text(
                    'I Took My Dose',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.caregiverGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.greenDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isBusy ? null : _onSnooze,
                      icon: const Icon(
                        Icons.snooze_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                      label: const Text(
                        'Snooze 10m',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontFamily: AppStyles.fontFamily,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isBusy ? null : _onSkip,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      label: const Text(
                        'Skip dose',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                          fontFamily: AppStyles.fontFamily,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
