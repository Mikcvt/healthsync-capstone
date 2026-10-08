import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../models/dose_slot.dart';
import '../../providers/patient_provider.dart';
import '../../screens/patient/missed_dose_screen.dart';
import '../../utils/date_formatter.dart';
import '../../utils/dose_timing.dart';
import '../../utils/snackbar_helper.dart';
import 'dose_reason_picker.dart';

enum _Gate { cancel, normal, early }

/// Done and Skip, the same way from every screen (DOSE_LOGIC_PROPOSAL.md,
/// sections 3 and 4): the early-logging prompt and its cap, the skip reason,
/// the Undo toast, and telling the caregiver only once Undo has passed.
class DoseActions {
  DoseActions._();

  /// Marks [slot] taken. Returns true when it was recorded. [onUndone] runs if
  /// the patient then taps Undo — the alarm screen uses it to leave the
  /// confirmation screen.
  static Future<bool> take(
    BuildContext context,
    DoseSlot slot, {
    VoidCallback? onUndone,
  }) async {
    final patient = context.read<PatientProvider>();
    if (await _openMissedIfPast(context, slot, patient)) return false;
    if (!context.mounted) return false;

    final gate = await _earlyGate(context, slot, patient, skipping: false);
    if (gate == _Gate.cancel || !context.mounted) return false;

    final outcome = await patient.takeDose(slot, early: gate == _Gate.early);
    if (!context.mounted) return _settleUnseen(patient, outcome);
    final name = patient.medicationNameFor(slot.schedule);
    return _afterAction(
      context,
      patient,
      outcome,
      successMessage: AppStrings.doseTakenUndo(_capitalise(name)),
      onUndone: onUndone,
    );
  }

  /// Skips [slot] after asking why. Returns true when it was recorded.
  static Future<bool> skip(
    BuildContext context,
    DoseSlot slot, {
    VoidCallback? onUndone,
  }) async {
    final patient = context.read<PatientProvider>();
    if (await _openMissedIfPast(context, slot, patient)) return false;
    if (!context.mounted) return false;

    final gate = await _earlyGate(context, slot, patient, skipping: true);
    if (gate == _Gate.cancel || !context.mounted) return false;

    final name = patient.medicationNameFor(slot.schedule);
    final reason = await showSkipReasonSheet(context, name);
    if (reason == null || !context.mounted) return false;

    final outcome = await patient.skipDose(slot, reason);
    if (!context.mounted) return _settleUnseen(patient, outcome);
    return _afterAction(
      context,
      patient,
      outcome,
      successMessage: AppStrings.doseSkippedUndo(_capitalise(name)),
      onUndone: onUndone,
    );
  }

  /// A dose an hour past its time is missed: Done and Skip no longer apply,
  /// the missed-dose screen does.
  static Future<bool> _openMissedIfPast(
    BuildContext context,
    DoseSlot slot,
    PatientProvider patient,
  ) async {
    final phase = DoseTiming.phaseOf(slot.scheduledAt, DateTime.now());
    if (phase != DosePhase.missed) return false;
    await openMissed(context, slot);
    return true;
  }

  /// Opens the missed-dose screen for [slot].
  static Future<void> openMissed(BuildContext context, DoseSlot slot) {
    final patient = context.read<PatientProvider>();
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MissedDoseScreen(
          slot: slot,
          medicineName: _capitalise(patient.medicationNameFor(slot.schedule)),
        ),
      ),
    );
  }

  /// Before the 30-minute unlock, a tap asks "logging early?" — or, beyond
  /// the early cap, says it is too early and offers nothing to confirm.
  static Future<_Gate> _earlyGate(
    BuildContext context,
    DoseSlot slot,
    PatientProvider patient, {
    required bool skipping,
  }) async {
    final now = DateTime.now();
    if (DoseTiming.phaseOf(slot.scheduledAt, now) != DosePhase.upcomingLocked) {
      return _Gate.normal;
    }

    final check = DoseTiming.checkEarly(
      slot.scheduledAt,
      now,
      previousDoseAt: patient.previousDoseAt(slot),
    );
    if (!check.allowed) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text(AppStrings.tooEarlyTitle),
          content: Text(
            AppStrings.tooEarlyBody(DateFormatter.toClockLabel(check.earliest)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return _Gate.cancel;
    }

    final time = DateFormatter.toClockLabel(slot.scheduledAt);
    final span = DoseTiming.spanInWords(slot.scheduledAt.difference(now));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.loggingEarlyTitle),
        content: Text(
          skipping
              ? AppStrings.skippingEarlyBody(time, span)
              : AppStrings.loggingEarlyBody(time, span),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              skipping ? 'Yes, skip it now' : 'Yes, I took it now',
              style: const TextStyle(
                color: AppColors.caregiverGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return confirmed == true ? _Gate.early : _Gate.cancel;
  }

  /// The screen closed while the action was saving, so there is nowhere to
  /// offer Undo: the action stands and the caregiver is told now.
  static bool _settleUnseen(PatientProvider patient, DoseOutcome outcome) {
    final undo = outcome.undo;
    if (undo != null) patient.finalizeDoseAction(undo);
    return outcome.result == DoseActionResult.success;
  }

  static bool _afterAction(
    BuildContext context,
    PatientProvider patient,
    DoseOutcome outcome, {
    required String successMessage,
    VoidCallback? onUndone,
  }) {
    final undo = outcome.undo;
    switch (outcome.result) {
      case DoseActionResult.success:
        if (undo == null) return true;
        SnackbarHelper.showUndo(
          context,
          message: successMessage,
          duration: DoseTiming.undoWindow,
          onUndo: () async {
            final ok = await patient.undoDoseAction(undo);
            if (ok) onUndone?.call();
            if (!context.mounted) return;
            if (ok) {
              SnackbarHelper.showInfo(context, AppStrings.doseUndone);
            } else {
              SnackbarHelper.showError(
                context,
                patient.errorMessage ?? AppStrings.undoFailed,
              );
            }
          },
          onCommit: () => patient.finalizeDoseAction(undo),
        );
        return true;
      case DoseActionResult.alreadyConfirmed:
        if (context.mounted) {
          SnackbarHelper.showInfo(context, AppStrings.doseAlreadyTaken);
        }
        return false;
      case DoseActionResult.failed:
      case DoseActionResult.snoozeLimitReached:
        if (context.mounted) {
          SnackbarHelper.showError(
            context,
            patient.errorMessage ?? AppStrings.doseConfirmFailed,
          );
        }
        return false;
    }
  }

  static String _capitalise(String name) =>
      name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);
}
