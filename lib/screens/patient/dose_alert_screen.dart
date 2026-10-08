import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_styles.dart';
import '../../models/dose_slot.dart';
import '../../providers/patient_provider.dart';
import '../../utils/date_formatter.dart';
import '../../utils/dose_status_display.dart';
import '../../utils/dose_timing.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/patient/dose_actions.dart';
import 'dose_confirmed_screen.dart';

/// The alarm screen for a dose that is due — opened by tapping its reminder.
///
/// It is the only place Snooze is offered (DOSE_LOGIC_PROPOSAL.md, 5.3). Done
/// and Skip go through [DoseActions], so they follow the same early-logging,
/// reason and Undo rules as the dashboard.
class DoseAlertScreen extends StatefulWidget {
  final String scheduleId;

  const DoseAlertScreen({super.key, required this.scheduleId});

  @override
  State<DoseAlertScreen> createState() => _DoseAlertScreenState();
}

class _DoseAlertScreenState extends State<DoseAlertScreen> {
  bool _isBusy = false;

  // The phase and a running snooze both change with the clock, not only with
  // provider data, so the screen refreshes on its own.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _onTake(DoseSlot slot, String medicineName) async {
    setState(() => _isBusy = true);
    final navigator = Navigator.of(context);
    final confirmedRoute = MaterialPageRoute<void>(
      builder: (_) => DoseConfirmedScreen(
        medicineName: medicineName,
        timeTaken: 'Just now',
      ),
    );
    final ok = await DoseActions.take(
      context,
      slot,
      // Undo removes the confirmation screen — the dose is no longer
      // confirmed — but only that screen, wherever the patient has gone.
      onUndone: () {
        if (confirmedRoute.isActive) navigator.removeRoute(confirmedRoute);
      },
    );
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (ok) navigator.pushReplacement(confirmedRoute);
  }

  Future<void> _onSkip(DoseSlot slot) async {
    setState(() => _isBusy = true);
    final ok = await DoseActions.skip(context, slot);
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _onSnooze(DoseSlot slot) async {
    setState(() => _isBusy = true);
    final patient = context.read<PatientProvider>();
    final result = await patient.snoozeDose(slot);
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

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<PatientProvider>();
    final slot = patient.todaySlotFor(widget.scheduleId);
    final now = DateTime.now();

    if (slot == null) {
      return _Shell(
        title: 'Dose reminder',
        message: 'This dose is no longer on your schedule today.',
        onClose: () => Navigator.of(context).pop(),
      );
    }

    final schedule = slot.schedule;
    final medicineName = _capitalise(patient.medicationNameFor(schedule));

    if (!slot.isOpen) {
      final badge = DoseStatusDisplay.resolvedBadge(slot.log!);
      return _Shell(
        title: medicineName,
        message: '${badge.label} · ${DoseStatusDisplay.detailFor(slot.log!)}',
        onClose: () => Navigator.of(context).pop(),
      );
    }

    final phase = DoseTiming.phaseOf(slot.scheduledAt, now);
    if (phase == DosePhase.missed) {
      return _Shell(
        title: medicineName,
        message: 'This dose was due ${DateFormatter.doseDayTime(slot.scheduledAt)} '
            'and is now missed.',
        actionLabel: 'Tell us what happened',
        onAction: () async {
          final navigator = Navigator.of(context);
          await DoseActions.openMissed(context, slot);
          if (mounted) navigator.pop();
        },
        onClose: () => Navigator.of(context).pop(),
      );
    }

    // A compartment is named only when there is one AND a box is paired.
    final activeCol =
        patient.showsCompartment(schedule) ? schedule.matBoxColumn : null;
    final med = patient.medicationFor(schedule.patMedRef);
    final instruction = activeCol != null
        ? 'Please take your dose from compartment $activeCol of your smart '
            'medicine box.'
        : med == null
            ? 'Please take your dose now.'
            : 'Take ${med.doseDescription}'
                '${med.prescribedDosage.isEmpty ? '' : ' (${med.prescribedDosage})'}'
                '${med.instructions.isEmpty ? '' : ' · ${med.instructions}'}.';
    final log = slot.log;
    final snoozeCount = log?.snoozeCount ?? 0;
    final snoozeActive = log?.isSnoozeActive ?? false;
    final canSnooze = !snoozeActive &&
        (phase == DosePhase.dueNow || phase == DosePhase.late);
    final outOfStock = schedule.pillsRemaining <= 0;
    final badge = DoseStatusDisplay.badgeFor(log, slot.scheduledAt, now);

    return Scaffold(
      backgroundColor: AppColors.textPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.patientBlue.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${badge.label.toUpperCase()} · '
                  '${DateFormatter.doseDayTime(slot.scheduledAt, now: now).toUpperCase()}',
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
                medicineName,
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
                instruction,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.5,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
              const SizedBox(height: 28),

              // Only when something is actually lit. A phone-only medicine
              // has nothing to point at, and the line above says what to take.
              if (activeCol != null)
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
                      const Icon(Icons.lightbulb,
                          color: Colors.amberAccent, size: 24),
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

              if (outOfStock) ...[
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.missedRed.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    AppStrings.outOfStockBadge,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                ),
              ],

              if (snoozeCount > 0) ...[
                const SizedBox(height: 14),
                Text(
                  snoozeActive
                      ? '${AppStrings.snoozeActiveUntil(DateFormatter.toClockLabel(log!.snoozedUntil!))} '
                          '($snoozeCount of 3)'
                      : snoozeCount >= 3
                          ? 'Snoozed 3 times — the next snooze marks this missed'
                          : 'Snoozed $snoozeCount of 3 times',
                  textAlign: TextAlign.center,
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
                  onPressed: _isBusy || outOfStock
                      ? null
                      : () => _onTake(slot, medicineName),
                  icon: _isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded,
                          color: Colors.white),
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
                    disabledBackgroundColor:
                        outOfStock ? Colors.white12 : AppColors.greenDark,
                    disabledForegroundColor: Colors.white38,
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
                      onPressed:
                          _isBusy || !canSnooze ? null : () => _onSnooze(slot),
                      icon: Icon(
                        Icons.snooze_rounded,
                        color: canSnooze ? Colors.white70 : Colors.white30,
                        size: 18,
                      ),
                      label: Text(
                        snoozeActive ? 'Snoozed' : 'Snooze 10m',
                        style: TextStyle(
                          color: canSnooze ? Colors.white70 : Colors.white30,
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
                      onPressed: _isBusy ? null : () => _onSkip(slot),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.redAccent, size: 18),
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

  static String _capitalise(String name) =>
      name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);
}

/// The alarm screen when there is nothing to take: the dose is already
/// recorded, missed, or no longer scheduled.
class _Shell extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onClose;

  const _Shell({
    required this.title,
    required this.message,
    required this.onClose,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.textPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.alarm_off_rounded, color: Colors.white54, size: 64),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.5,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
              const Spacer(),
              if (actionLabel != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.missedRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
