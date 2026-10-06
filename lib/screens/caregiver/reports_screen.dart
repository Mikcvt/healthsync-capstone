import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/caregiver_provider.dart';
import '../../utils/snackbar_helper.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _days = 7;

  String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final caregiver = context.watch<CaregiverProvider>();
    final cutoff = DateTime.now().subtract(Duration(days: _days - 1));
    final logs = caregiver.selectedPatientLogs.where((log) {
      final date = DateTime.tryParse(log.scheduledDate);
      return date != null && !date.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day));
    }).toList();
    final resolved = logs.where((log) => log.isTaken || log.isMissed).toList();
    final taken = resolved.where((log) => log.isTaken).length;
    final missed = resolved.where((log) => log.isMissed).length;
    final pending = logs.where((log) => log.isPending || log.isSnoozed).length;
    final adherence = resolved.isEmpty ? 0.0 : taken / resolved.length;
    final patientName = caregiver.selectedPatientUser?.fullName ?? 'No patient selected';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text('Reports', style: TextStyle(color: AppColors.textPrimary, fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w800))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(patientName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Live adherence from dose logs', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            SegmentedButton<int>(segments: const [ButtonSegment(value: 7, label: Text('7 days')), ButtonSegment(value: 30, label: Text('30 days')), ButtonSegment(value: 90, label: Text('90 days'))], selected: {_days}, onSelectionChanged: (value) => setState(() => _days = value.first)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppStyles.cardDecoration,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Overall adherence', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('${(adherence * 100).round()}%', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Text('$taken of ${resolved.length} resolved doses taken', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: adherence, minHeight: 10, backgroundColor: AppColors.borderGray, color: AppColors.caregiverGreen)),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [_MetricCard(label: 'Taken', value: '$taken', color: AppColors.caregiverGreen), const SizedBox(width: 10), _MetricCard(label: 'Missed', value: '$missed', color: AppColors.missedRed), const SizedBox(width: 10), _MetricCard(label: 'Pending', value: '$pending', color: AppColors.patientBlue)]),
            const SizedBox(height: 22),
            const Text('Daily trend', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(18), decoration: AppStyles.cardDecoration, child: Column(children: _trendRows(logs))),
            const SizedBox(height: 22),
            if (logs.isEmpty)
              Container(padding: const EdgeInsets.all(20), decoration: AppStyles.cardDecoration, child: const Text('No dose logs are available for this period.', style: TextStyle(color: AppColors.textSecondary)))
            else
              OutlinedButton.icon(onPressed: () => _copyReport(patientName, taken, missed, pending, adherence), icon: const Icon(Icons.copy_outlined), label: const Text('Copy report summary')),
          ],
        ),
      ),
    );
  }

  List<Widget> _trendRows(List<dynamic> logs) {
    final now = DateTime.now();
    return List.generate(_days > 7 ? 7 : _days, (index) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: index));
      final key = _dateKey(date);
      final dayLogs = logs.where((log) => log.scheduledDate == key).toList();
      final resolved = dayLogs.where((log) => log.isTaken || log.isMissed).toList();
      final ratio = resolved.isEmpty ? 0.0 : resolved.where((log) => log.isTaken).length / resolved.length;
      return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [SizedBox(width: 48, child: Text(index == 0 ? 'Today' : '${date.month}/${date.day}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))), const SizedBox(width: 10), Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: ratio, minHeight: 14, backgroundColor: AppColors.borderGray, color: ratio >= 0.8 ? AppColors.caregiverGreen : AppColors.missedRed))), const SizedBox(width: 10), SizedBox(width: 40, child: Text('${(ratio * 100).round()}%', textAlign: TextAlign.end, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)))]));
    });
  }

  void _copyReport(String patientName, int taken, int missed, int pending, double adherence) {
    final summary = 'HealthSync report\nPatient: $patientName\nPeriod: $_days days\nAdherence: ${(adherence * 100).round()}%\nTaken: $taken\nMissed: $missed\nPending: $pending';
    Clipboard.setData(ClipboardData(text: summary));
    SnackbarHelper.showSuccess(context, 'Report summary copied to clipboard.');
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricCard({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(padding: const EdgeInsets.all(14), decoration: AppStyles.cardDecoration, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)), const SizedBox(height: 8), Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color))])));
}
