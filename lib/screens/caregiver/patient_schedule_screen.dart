import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_styles.dart';
import '../../utils/dose_status_display.dart';
import '../../models/dose_log_model.dart';
import '../../models/schedule_model.dart';
import '../../providers/caregiver_provider.dart';
import '../../utils/date_formatter.dart';

/// The selected patient's medication timeline for a chosen day.
///
/// Both the day strip and the dose rows are derived from real data: the strip
/// from today's date, and each row from the `schedules` entry plus its
/// materialised `dose_logs` row. The previous version hardcoded "Tue 21" to
/// "Fri 23" and marked an 8:00 PM dose "Taken" with the mockup note
/// "LED should light at 8:00" still in the detail line.
class PatientScheduleScreen extends StatefulWidget {
  final String patientName;

  const PatientScheduleScreen({super.key, this.patientName = 'Patient'});

  @override
  State<PatientScheduleScreen> createState() => _PatientScheduleScreenState();
}

class _PatientScheduleScreenState extends State<PatientScheduleScreen> {
  /// Days offset from today. 0 is today; the strip shows today plus six days,
  /// because a caregiver plans forward and reviews the past in the history
  /// screen.
  int _dayOffset = 0;

  DateTime get _selectedDay =>
      DateFormatter.startOfDay(DateTime.now()).add(Duration(days: _dayOffset));

  @override
  Widget build(BuildContext context) {
    final caregiver = context.watch<CaregiverProvider>();
    final day = _selectedDay;

    // Only schedules that actually run on the selected weekday, and that have
    // started and not yet ended.
    final schedules = caregiver.selectedPatientSchedules
        .where((s) => _runsOn(s, day))
        .toList();
    final logs = caregiver.logsForDay(day);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.patientName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontFamily: AppStyles.fontFamily,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Medication timeline',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 68,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 7,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final date = DateFormatter.startOfDay(DateTime.now())
                            .add(Duration(days: index));
                        return _DatePill(
                          label: DateFormatter.weekdayShort(date.weekday),
                          value: '${date.day}',
                          selected: index == _dayOffset,
                          onTap: () => setState(() => _dayOffset = index),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            Expanded(
              child: schedules.isEmpty
                  ? _EmptyDay(
                      hasAnySchedules:
                          caregiver.selectedPatientSchedules.isNotEmpty,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                      itemCount: schedules.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final schedule = schedules[index];
                        return _DoseRow(
                          schedule: schedule,
                          medicineName:
                              caregiver.medicationNameFor(schedule),
                          log: _logFor(logs, schedule.scheduleId),
                          isFuture: _dayOffset > 0,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  DoseLogModel? _logFor(List<DoseLogModel> logs, String scheduleId) {
    for (final log in logs) {
      if (log.scheduleRef == scheduleId) return log;
    }
    return null;
  }

  /// Whether a schedule applies on [day], honouring days_of_week and the
  /// start/end dates.
  bool _runsOn(ScheduleModel schedule, DateTime day) {
    if (!schedule.daysOfWeek.contains(day.weekday)) return false;
    if (DateFormatter.startOfDay(schedule.startDate).isAfter(day)) return false;
    final end = schedule.endDate;
    if (end != null && DateFormatter.startOfDay(end).isBefore(day)) {
      return false;
    }
    return true;
  }
}

class _EmptyDay extends StatelessWidget {
  final bool hasAnySchedules;

  const _EmptyDay({required this.hasAnySchedules});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_available_outlined,
                size: 50, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(
              hasAnySchedules
                  ? 'Nothing scheduled on this day.'
                  : AppStrings.noPatientSchedule,
              textAlign: TextAlign.center,
              style: const TextStyle(
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

class _DatePill extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _DatePill({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 54,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.caregiverGreen : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.caregiverGreen : AppColors.borderGray,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white70 : AppColors.textSecondary,
                fontFamily: AppStyles.fontFamily,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : AppColors.textPrimary,
                fontFamily: AppStyles.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  final ScheduleModel schedule;
  final String medicineName;
  final DoseLogModel? log;

  /// A future day has no outcome yet, so it is labelled "Scheduled" rather than
  /// "Pending" — pending implies it is already due.
  final bool isFuture;

  const _DoseRow({
    required this.schedule,
    required this.medicineName,
    required this.log,
    required this.isFuture,
  });

  (String, Color, Color) get _status {
    if (log == null) {
      return isFuture
          ? ('Scheduled', AppColors.textSecondary, AppColors.ledEmpty)
          : ('Not logged', AppColors.textMuted, AppColors.ledEmpty);
    }
    // Same labels and colours as the patient sees: Upcoming / Due now / Late /
    // Missed / Taken early / Taken late / Logged late / Skipped.
    final now = DateTime.now();
    final badge =
        DoseStatusDisplay.badgeFor(log, log!.scheduledAt ?? now, now);
    return (
      badge.label,
      badge.foreground,
      badge.outlined ? AppColors.missedRedBg : badge.background,
    );
  }

  @override
  Widget build(BuildContext context) {
    final (label, accent, background) = _status;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.cardDecoration,
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              schedule.scheduledTime,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                fontFamily: AppStyles.fontFamily,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicineName,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${schedule.isInBox ? 'Compartment ${schedule.matBoxColumn}' : 'Not in the box'} · '
                  '${schedule.pillsRemaining} left',
                  style: TextStyle(
                    fontSize: 12,
                    color: schedule.isLowStock
                        ? AppColors.pendingAmber
                        : AppColors.textSecondary,
                    fontWeight: schedule.isLowStock
                        ? FontWeight.w700
                        : FontWeight.w400,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: accent,
                fontFamily: AppStyles.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
