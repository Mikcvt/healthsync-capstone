import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../models/dose_log_model.dart';
import '../../providers/caregiver_provider.dart';
import '../../utils/adherence.dart';
import '../../utils/date_formatter.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/shared/floating_nav_bar.dart';

/// Adherence for the selected patient (DOSE_LOGIC_PROPOSAL.md, section 10).
///
/// - **Adherence**: taken ÷ (taken + missed + skipped). Cancelled doses and
///   medicines archived as "entered by mistake" are left out.
/// - **On time**: share of taken doses that were early or on time — so a
///   patient who always takes doses 50 minutes late shows 100% adherence but
///   a low on-time rate, and both are true.
/// - **Logged late**: doses the patient corrected with "I took it but forgot
///   to log it".
/// - **Reasons**: why doses were skipped or missed.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final caregiver = context.watch<CaregiverProvider>();
    final cutoff = DateFormatter.startOfDay(
      DateTime.now().subtract(Duration(days: _days - 1)),
    );
    final logs = caregiver.selectedPatientLogs.where((log) {
      final date = DateTime.tryParse(log.scheduledDate) ?? log.scheduledAt;
      return date != null && !date.isBefore(cutoff);
    }).toList();
    final stats = AdherenceStats.of(logs);
    final pending = logs.where((log) => log.isOpen).length;
    final patientName =
        caregiver.selectedPatientUser?.fullName ?? 'No patient selected';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Reports',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            8,
            20,
            FloatingNavBar.contentPadding,
          ),
          children: [
            Text(
              patientName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Live adherence from dose logs',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 days')),
                ButtonSegment(value: 30, label: Text('30 days')),
                ButtonSegment(value: 90, label: Text('90 days')),
              ],
              selected: {_days},
              onSelectionChanged: (value) =>
                  setState(() => _days = value.first),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppStyles.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Overall adherence',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stats.resolved == 0
                        ? '—'
                        : '${(stats.adherence * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${stats.taken} of ${stats.resolved} doses taken',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: stats.resolved == 0 ? 0 : stats.adherence,
                      minHeight: 10,
                      backgroundColor: AppColors.borderGray,
                      color: AppColors.caregiverGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _MetricCard(
                  label: 'Taken',
                  value: '${stats.taken}',
                  color: AppColors.caregiverGreen,
                ),
                const SizedBox(width: 10),
                _MetricCard(
                  label: 'Missed',
                  value: '${stats.missed}',
                  color: AppColors.missedRed,
                ),
                const SizedBox(width: 10),
                _MetricCard(
                  label: 'Skipped',
                  value: '${stats.skipped}',
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _MetricCard(
                  label: 'On time',
                  value: stats.taken == 0
                      ? '—'
                      : '${(stats.onTimeRate * 100).round()}%',
                  color: AppColors.patientBlue,
                ),
                const SizedBox(width: 10),
                _MetricCard(
                  label: 'Logged late',
                  value: '${stats.loggedLate}',
                  color: AppColors.pendingAmber,
                ),
                const SizedBox(width: 10),
                _MetricCard(
                  label: 'Pending',
                  value: '$pending',
                  color: AppColors.upcomingBlue,
                ),
              ],
            ),
            if (stats.reasons.isNotEmpty) ...[
              const SizedBox(height: 22),
              const Text(
                'Reasons for skipped and missed doses',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: AppStyles.cardDecoration,
                child: Column(
                  children: [
                    for (final entry in stats.reasons.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '${entry.value}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            const Text(
              'Daily trend',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: AppStyles.cardDecoration,
              child: Column(children: _trendRows(logs)),
            ),
            const SizedBox(height: 22),
            if (logs.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppStyles.cardDecoration,
                child: const Text(
                  'No dose logs are available for this period.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: () => _copyReport(patientName, stats, pending),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy report summary'),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _trendRows(List<DoseLogModel> logs) {
    final now = DateTime.now();
    return List.generate(_days > 7 ? 7 : _days, (index) {
      final date = DateFormatter.startOfDay(now).subtract(Duration(days: index));
      final key = DateFormatter.toDateKey(date);
      final day = AdherenceStats.of(
        logs.where((log) => log.scheduledDate == key),
      );
      final ratio = day.resolved == 0 ? 0.0 : day.adherence;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(
                index == 0 ? 'Today' : '${date.month}/${date.day}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 14,
                  backgroundColor: AppColors.borderGray,
                  color: ratio >= 0.8
                      ? AppColors.caregiverGreen
                      : AppColors.missedRed,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 40,
              child: Text(
                day.resolved == 0 ? '—' : '${(ratio * 100).round()}%',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  void _copyReport(String patientName, AdherenceStats stats, int pending) {
    final reasons = stats.reasons.entries
        .map((e) => '  ${e.key}: ${e.value}')
        .join('\n');
    final summary = [
      'HealthSync report',
      'Patient: $patientName',
      'Period: $_days days',
      'Adherence: ${(stats.adherence * 100).round()}% '
          '(${stats.taken} of ${stats.resolved} taken)',
      'On time: ${(stats.onTimeRate * 100).round()}% of taken doses',
      'Taken: ${stats.taken} (logged late: ${stats.loggedLate})',
      'Missed: ${stats.missed}',
      'Skipped: ${stats.skipped}',
      'Pending: $pending',
      if (reasons.isNotEmpty) 'Reasons:\n$reasons',
    ].join('\n');
    Clipboard.setData(ClipboardData(text: summary));
    SnackbarHelper.showSuccess(context, 'Report summary copied to clipboard.');
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: AppStyles.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
}
