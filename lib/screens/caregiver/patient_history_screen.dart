import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_styles.dart';
import '../../utils/dose_status_display.dart';
import '../../utils/adherence.dart';
import '../../models/dose_log_model.dart';
import '../../providers/caregiver_provider.dart';
import '../../utils/date_formatter.dart';

/// The selected patient's intake record, grouped by day.
///
/// Reads `dose_logs` through [CaregiverProvider]. The previous version listed
/// two invented days and reported a heart rate for each dose — there is no
/// heart-rate sensor anywhere in this build.
class PatientHistoryScreen extends StatelessWidget {
  final String patientName;

  const PatientHistoryScreen({super.key, this.patientName = 'Patient'});

  @override
  Widget build(BuildContext context) {
    final caregiver = context.watch<CaregiverProvider>();
    final logs = caregiver.selectedPatientLogs;
    final grouped = _groupByDay(logs);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          patientName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontFamily: AppStyles.fontFamily,
          ),
        ),
      ),
      body: SafeArea(
        child: logs.isEmpty
            ? const _EmptyHistory()
            : ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  const Text(
                    'Intake record',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last 90 days · ${logs.length} '
                    '${logs.length == 1 ? 'dose' : 'doses'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (final entry in grouped.entries) ...[
                    _DayGroup(
                      label: entry.key,
                      logs: entry.value,
                      caregiver: caregiver,
                    ),
                    const SizedBox(height: 18),
                  ],
                ],
              ),
      ),
    );
  }

  /// Groups logs into day buckets, preserving the newest-first order the
  /// provider already sorted them into.
  Map<String, List<DoseLogModel>> _groupByDay(List<DoseLogModel> logs) {
    final grouped = <String, List<DoseLogModel>>{};
    for (final log in logs) {
      final day = log.scheduledAt ??
          DateTime.tryParse(log.scheduledDate) ??
          log.createdAt;
      grouped.putIfAbsent(DateFormatter.toRelativeDay(day), () => []).add(log);
    }
    return grouped;
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded,
                size: 52, color: AppColors.textMuted),
            SizedBox(height: 14),
            Text(
              AppStrings.noDoseHistory,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
                fontFamily: AppStyles.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayGroup extends StatelessWidget {
  final String label;
  final List<DoseLogModel> logs;
  final CaregiverProvider caregiver;

  const _DayGroup({
    required this.label,
    required this.logs,
    required this.caregiver,
  });

  @override
  Widget build(BuildContext context) {
    // The shared adherence rules: skipped counts as not taken, and doses of a
    // medicine entered by mistake are not counted.
    final stats = AdherenceStats.of(logs);
    final taken = stats.taken;
    final resolved = stats.resolved;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.textSecondary,
                fontFamily: AppStyles.fontFamily,
              ),
            ),
            const SizedBox(width: 8),
            if (resolved > 0)
              Text(
                '$taken of $resolved taken',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: AppStyles.cardDecoration,
          child: Column(
            children: [
              for (var i = 0; i < logs.length; i++) ...[
                if (i > 0)
                  const Divider(
                      height: 1, thickness: 1, color: AppColors.borderGray),
                _HistoryRow(
                  log: logs[i],
                  medicineName: caregiver.medicationNameForLog(logs[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final DoseLogModel log;
  final String medicineName;

  const _HistoryRow({required this.log, required this.medicineName});

  /// Status drives the row's appearance, with the same labels the patient
  /// sees. The detail line explains why: how early or late, the reason for a
  /// skip or miss, and for a correction both when it was logged and when the
  /// patient says it was taken (DOSE_LOGIC_PROPOSAL.md, section 11).
  (String, Color, Color, IconData) get _status {
    final now = DateTime.now();
    final badge = DoseStatusDisplay.badgeFor(log, log.scheduledAt ?? now, now);
    final icon = switch (log.status) {
      'taken' => Icons.check_circle_outline_rounded,
      'missed' => Icons.error_outline_rounded,
      'skipped' => Icons.do_not_disturb_on_outlined,
      'snoozed' => Icons.snooze_rounded,
      _ => Icons.schedule_rounded,
    };
    return (
      badge.label,
      badge.foreground,
      badge.outlined ? AppColors.missedRedBg : badge.background,
      icon,
    );
  }

  String get _detail {
    final text = DoseStatusDisplay.detailFor(log);
    return log.excludedFromAdherence ? '$text · not counted' : text;
  }

  @override
  Widget build(BuildContext context) {
    final (label, accent, background, icon) = _status;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$medicineName · $label',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          Text(
            log.scheduledTime,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              fontFamily: AppStyles.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
