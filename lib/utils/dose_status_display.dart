import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/dose_log_model.dart';
import 'adherence.dart';
import 'date_formatter.dart';
import 'dose_timing.dart';

/// The badge for one dose: label and colours.
class DoseBadge {
  final String label;
  final Color foreground;
  final Color background;

  /// An outlined badge (Late) rather than a filled one (Missed), so the two
  /// red states read differently.
  final bool outlined;

  const DoseBadge(
    this.label,
    this.foreground,
    this.background, {
    this.outlined = false,
  });
}

/// One mapping from a dose to what it is called and how it is coloured, used
/// by the patient's and the caregiver's screens alike
/// (DOSE_LOGIC_PROPOSAL.md, sections 2.2 and 11).
class DoseStatusDisplay {
  DoseStatusDisplay._();

  /// The badge for a dose scheduled at [scheduledAt] with log [log] (null when
  /// not yet materialised), seen at [now].
  static DoseBadge badgeFor(
    DoseLogModel? log,
    DateTime scheduledAt,
    DateTime now,
  ) {
    if (log != null && !log.isOpen) return resolvedBadge(log);

    if (log != null && log.isSnoozeActive) {
      return DoseBadge(
        'Snoozed until ${DateFormatter.toClockLabel(log.snoozedUntil!)}',
        AppColors.pendingAmber,
        AppColors.pendingAmberBg,
      );
    }

    return switch (DoseTiming.phaseOf(scheduledAt, now)) {
      DosePhase.upcomingLocked || DosePhase.upcomingUnlocked =>
        const DoseBadge(
          'Upcoming',
          AppColors.upcomingBlue,
          AppColors.upcomingBlueBg,
        ),
      DosePhase.dueNow =>
        const DoseBadge('Due now', AppColors.pendingAmber, AppColors.pendingAmberBg),
      DosePhase.late => const DoseBadge(
          'Late',
          AppColors.missedRed,
          AppColors.cardWhite,
          outlined: true,
        ),
      DosePhase.missed =>
        const DoseBadge('Missed', AppColors.missedRed, AppColors.missedRedBg),
    };
  }

  /// The badge for a dose with a final status.
  static DoseBadge resolvedBadge(DoseLogModel log) {
    if (log.isTaken) {
      final label = switch (AdherenceStats.effectiveTiming(log)) {
        'early' => 'Taken early',
        'late' => 'Taken late',
        'logged_late' => 'Logged late',
        _ => 'Taken',
      };
      return DoseBadge(label, AppColors.takenGreen, AppColors.takenGreenBg);
    }
    if (log.isSkipped) {
      return const DoseBadge(
        'Skipped',
        AppColors.textSecondary,
        AppColors.background,
      );
    }
    if (log.isMissed) {
      return const DoseBadge('Missed', AppColors.missedRed, AppColors.missedRedBg);
    }
    if (log.isCancelled) {
      return const DoseBadge(
        'Cancelled',
        AppColors.textMuted,
        AppColors.background,
      );
    }
    return const DoseBadge(
      'Upcoming',
      AppColors.upcomingBlue,
      AppColors.upcomingBlueBg,
    );
  }

  /// A one-line description of what happened, for history rows: "Taken at
  /// 8:04 AM", "Logged late at 9:40 PM, says taken at 8:10 AM", "Skipped ·
  /// Felt sick", "Missed · Forgot to take".
  static String detailFor(DoseLogModel log) {
    final reason = log.skippedReason.trim();
    if (log.isTaken) {
      final takenAt = log.takenAt;
      final timing = AdherenceStats.effectiveTiming(log);
      if (timing == 'logged_late' && takenAt != null) {
        final loggedAt = log.loggedAt;
        return loggedAt == null
            ? 'Logged late, says taken at ${DateFormatter.toClockLabel(takenAt)}'
            : 'Logged late at ${DateFormatter.toClockLabel(loggedAt)}, '
                'says taken at ${DateFormatter.toClockLabel(takenAt)}';
      }
      if (takenAt == null) return 'Taken';
      final scheduledAt = log.scheduledAt;
      if (scheduledAt != null && timing != 'on_time') {
        final span = DoseTiming.spanInWords(takenAt.difference(scheduledAt));
        final side = takenAt.isBefore(scheduledAt) ? 'early' : 'late';
        return 'Taken at ${DateFormatter.toClockLabel(takenAt)} ($span $side)';
      }
      return 'Taken at ${DateFormatter.toClockLabel(takenAt)}';
    }
    if (log.isSkipped) return reason.isEmpty ? 'Skipped' : 'Skipped · $reason';
    if (log.isMissed) return reason.isEmpty ? 'Missed' : 'Missed · $reason';
    if (log.isSnoozed) {
      return 'Snoozed ${log.snoozeCount} time${log.snoozeCount == 1 ? '' : 's'}';
    }
    return 'Scheduled ${log.scheduledTime}';
  }
}
