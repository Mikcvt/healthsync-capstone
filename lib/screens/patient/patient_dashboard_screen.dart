import '../../widgets/shared/floating_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dose_log_model.dart';
import '../../models/schedule_model.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/date_formatter.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import 'analytics_screen.dart';
import 'medicine_box_status_screen.dart';
import 'notifications_screen.dart';
import 'dose_alert_screen.dart';

class PatientDashboardScreen extends StatelessWidget {
  const PatientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final patientProvider = context.watch<PatientProvider>();
    final user = authProvider.currentUserModel;
    final firstName = user?.firstName.isNotEmpty == true ? user!.firstName : 'Patient';

    final schedules = patientProvider.schedules;
    final todayLogs = patientProvider.todayLogs;
    final takenCount = todayLogs.where((l) => l.isTaken).length;
    final totalDoses = schedules.length;
    final isLinked = patientProvider.isLinkedToCaregiver;
    final caregiver = patientProvider.caregiverUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Hello, $firstName!',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, FloatingNavBar.contentPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Adherence Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: AppStyles.gradientDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TODAY\'S MEDICATION PLAN',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$takenCount/$totalDoses Taken',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      totalDoses == 0
                          ? 'No medications scheduled'
                          : (takenCount >= totalDoses
                              ? 'All doses completed today!'
                              : '${totalDoses - takenCount} dose(s) pending today'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _Pill(label: '$totalDoses daily doses', color: Colors.white.withValues(alpha: 0.18)),
                        const SizedBox(width: 10),
                        _Pill(
                          label: '${patientProvider.todayAdherencePercentage.toStringAsFixed(0)}% adherence',
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ==========================================
              // CAREGIVER LINKING BANNER
              // ==========================================
              if (!isLinked) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade300, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shield_outlined, color: Colors.amber.shade900, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No Caregiver Linked',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.amber.shade900,
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Connect accounts to share reminders & alerts.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade900.withValues(alpha: 0.8),
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),
                          ],
                        ),
                      ),
                      // No "Link" action: a patient cannot attach a caregiver
                      // themselves. Every patient is created by their caregiver
                      // already linked, so this only shows if that link was
                      // removed.
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ] else ...[
                // Informational only — there is nothing for the patient to
                // change about their caregiver link.
                Builder(
                  builder: (context) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.ledDoneBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.caregiverGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.caregiverGreen, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Caregiver ${caregiver != null ? caregiver.firstName : "Connected"} is monitoring',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.caregiverGreen,
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // ==========================================
              // TODAY'S DOSES LIST
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Today\'s Schedule',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (schedules.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: AppStyles.cardDecoration,
                  child: Column(
                    children: [
                      const Icon(Icons.medication_outlined, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      const Text(
                        'No medications scheduled yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your caregiver has not added any medicines yet. They will appear here as soon as they do.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                // Only what still needs attention. Doses taken, and misses the
                // patient has already acknowledged, drop off — the list should
                // shrink as the day progresses, not grow.
                ...() {
                  // Driven by the schedule, not the dose log.
                  //
                  // Logs are materialised by a cron that can be up to five
                  // minutes behind, so keying the list on them hid a dose the
                  // patient could already see on the caregiver's screen. The
                  // schedule is the intent and always exists; the log only
                  // supplies status.
                  final today = DateTime.now();

                  final due = schedules.where((s) {
                    if (s.daysOfWeek.isNotEmpty &&
                        !s.daysOfWeek.contains(today.weekday)) {
                      return false;
                    }
                    final log =
                        patientProvider.todayLogForSchedule(s.scheduleId);
                    // Nothing logged yet means it has not happened yet, so it
                    // belongs on the list.
                    if (log == null) return true;
                    return !log.isTaken && log.acknowledgedAt == null;
                  }).toList()
                    ..sort((a, b) {
                      final x = DateFormatter.parseScheduleTime(a.scheduledTime);
                      final y = DateFormatter.parseScheduleTime(b.scheduledTime);
                      if (x == null || y == null) return 0;
                      return x.compareTo(y);
                    });

                  if (due.isEmpty) return <Widget>[const _AllDone()];

                  return due.asMap().entries.map<Widget>((entry) {
                    return _buildDoseRow(
                      context,
                      patientProvider,
                      entry.value,
                      // Only the nearest dose gets full prominence; the ones
                      // after it step down so the eye lands on what is next.
                      compact: entry.key > 0,
                    );
                  }).toList();
                }(),

              const SizedBox(height: 20),

              // ==========================================
              // QUICK ACTIONS
              // ==========================================
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _QuickCard(
                      title: 'Smart Box',
                      subtitle: 'Status & LED test',
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.patientBlue,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MedicineBoxStatusScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickCard(
                      title: 'Dose History',
                      subtitle: 'Past intake logs',
                      icon: Icons.history_rounded,
                      color: AppColors.caregiverGreen,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: 'PlusJakartaSans',
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppStyles.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Says plainly what happened to one dose today.
///
/// Without this the dashboard showed every dose with the same outline tick, so
/// "not taken yet", "taken" and "missed" were visually identical — the caregiver
/// screen said 4 missed while this one said 4/4 taken.
class _DoseStatusChip extends StatelessWidget {
  final DoseLogModel? log;

  const _DoseStatusChip({required this.log});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color fg;
    late final Color bg;

    if (log == null) {
      // No log yet: the Worker materialises these a little ahead of time, so a
      // gap means "not due yet", not "missed".
      label = 'Upcoming';
      fg = AppColors.upcomingBlue;
      bg = AppColors.upcomingBlueBg;
    } else if (log!.isTaken) {
      final at = log!.takenAt;
      label = at == null ? 'Taken' : 'Taken ${DateFormatter.toTimeLabel(at)}';
      fg = AppColors.takenGreen;
      bg = AppColors.takenGreenBg;
    } else if (log!.isMissed) {
      label = 'Missed';
      fg = AppColors.missedRed;
      bg = AppColors.missedRedBg;
    } else if (log!.isSnoozed) {
      label = 'Snoozed (${log!.snoozeCount}/3)';
      fg = AppColors.pendingAmber;
      bg = AppColors.pendingAmberBg;
    } else {
      label = 'Due now';
      fg = AppColors.pendingAmber;
      bg = AppColors.pendingAmberBg;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

/// One outstanding dose.
///
/// [compact] shrinks every dose after the nearest one, so the next thing to
/// take reads as the primary item rather than one of a uniform stack.
Widget _buildDoseRow(
  BuildContext context,
  PatientProvider provider,
  ScheduleModel sch, {
  required bool compact,
}) {
  final med = provider.medications
      .where((m) => m.patMedId == sch.patMedRef)
      .firstOrNull;
  final medName = med?.medicationName.isNotEmpty == true
      ? med!.medicationName
      : 'Scheduled medication';
  final log = provider.todayLogForSchedule(sch.scheduleId);
  final missed = log?.isMissed == true;

  return Container(
    margin: EdgeInsets.only(bottom: compact ? 8 : 12),
    padding: EdgeInsets.symmetric(
      horizontal: 16,
      vertical: compact ? 12 : 18,
    ),
    decoration: AppStyles.cardDecoration.copyWith(
      border: Border.all(
        color: missed ? AppColors.missedRed.withValues(alpha: 0.3)
                      : AppColors.borderGray,
      ),
    ),
    child: Row(
      children: [
        Container(
          width: compact ? 40 : 48,
          height: compact ? 40 : 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: missed ? AppColors.missedRedBg : AppColors.blueLight,
            borderRadius: BorderRadius.circular(compact ? 11 : 13),
          ),
          child: Text(
            'Col ${sch.matBoxColumn}',
            style: TextStyle(
              fontSize: compact ? 9.5 : 10.5,
              fontWeight: FontWeight.w800,
              color: missed ? AppColors.missedRed : AppColors.patientBlue,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                medName,
                style: TextStyle(
                  fontSize: compact ? 14.5 : 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                '${sch.scheduledTime} · ${sch.pillsRemaining} pills left',
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  color: AppColors.textSecondary,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 6),
                _DoseStatusChip(log: log),
              ],
            ],
          ),
        ),

        // A missed dose offers the honest pair of actions: record it late, or
        // acknowledge it and clear it from the list.
        if (missed)
          IconButton(
            tooltip: 'Dismiss this missed dose',
            icon: Icon(Icons.close_rounded,
                color: AppColors.missedRed, size: compact ? 22 : 26),
            onPressed: () async {
              final id = log?.doseLogId;
              if (id == null || id.isEmpty) return;
              final ok = await provider.acknowledgeMissedDose(id);
              if (!context.mounted) return;
              if (ok) {
                SnackbarHelper.showInfo(
                  context,
                  'Moved to history. It still counts as missed.',
                );
              } else {
                SnackbarHelper.showError(
                  context,
                  provider.errorMessage ?? 'Could not dismiss this dose.',
                );
              }
            },
          )
        else
          IconButton(
            tooltip: 'Confirm this dose',
            // Blue, not a tick: an unticked checkbox reads as "done" at a
            // glance, which is the opposite of what a pending dose means.
            icon: Icon(
              Icons.radio_button_unchecked_rounded,
              color: AppColors.patientBlue,
              size: compact ? 24 : 28,
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DoseAlertScreen(
                  schedule: sch,
                  medicineName: medName,
                  doseTime: sch.scheduledTime,
                  columnNumber: sch.matBoxColumn,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Shown once everything today has been dealt with.
class _AllDone extends StatelessWidget {
  const _AllDone();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppStyles.cardDecoration,
      child: Column(
        children: const [
          Icon(Icons.task_alt_rounded, size: 38, color: AppColors.takenGreen),
          SizedBox(height: 12),
          Text(
            'Nothing left today',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Every dose has been dealt with. See History for the full record.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
