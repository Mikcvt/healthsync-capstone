import 'dart:async';
import '../../widgets/shared/floating_nav_bar.dart';
import '../../widgets/shared/medicine_badge.dart';
import '../../widgets/patient/dose_actions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_strings.dart';
import '../../models/dose_slot.dart';
import '../../utils/date_formatter.dart';
import '../../utils/dose_status_display.dart';
import '../../utils/dose_timing.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import 'analytics_screen.dart';
import 'medicine_box_status_screen.dart';
import 'medicine_detail_screen.dart';

/// The patient's home screen: today's doses only, grouped so what needs doing
/// sits at the top (DOSE_LOGIC_PROPOSAL.md, section 6).
///
/// ```
/// NEEDS ACTION      Late, then Due now — Done / Skip
/// UPCOMING          by time — Done / Skip, locked until 30 min before
/// ▸ DONE TODAY (3)  taken, skipped, missed — collapsed
/// ▸ VIEW TOMORROW   read-only, except within the early-logging window
/// ```
///
/// Snooze is not offered here; it lives on the alarm screen only.
class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  // Groups, badges and countdowns depend on the clock as well as on data, so
  // the screen rebuilds on its own as doses come due.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final patientProvider = context.watch<PatientProvider>();
    final user = authProvider.currentUserModel;
    final firstName = user?.firstName.isNotEmpty == true ? user!.firstName : 'Patient';

    final now = DateTime.now();
    final today = patientProvider.slotsForDay(now);
    final tomorrow =
        patientProvider.slotsForDay(now.add(const Duration(days: 1)));

    bool past(DoseSlot s) =>
        DoseTiming.phaseOf(s.scheduledAt, now) == DosePhase.missed;
    final needsAction = today.where((s) {
      if (!s.isOpen) return false;
      final phase = DoseTiming.phaseOf(s.scheduledAt, now);
      return phase == DosePhase.dueNow || phase == DosePhase.late;
    }).toList();
    final upcoming = today.where((s) {
      if (!s.isOpen) return false;
      final phase = DoseTiming.phaseOf(s.scheduledAt, now);
      return phase == DosePhase.upcomingLocked ||
          phase == DosePhase.upcomingUnlocked;
    }).toList();
    final done = today.where((s) => !s.isOpen || past(s)).toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    final takenCount = today.where((s) => s.log?.isTaken ?? false).length;
    final remaining = needsAction.length + upcoming.length;
    final isLinked = patientProvider.isLinkedToCaregiver;
    final caregiver = patientProvider.caregiverUser;
    final hasSchedules = patientProvider.schedules.isNotEmpty;

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
        // No bell here: the Alerts tab, with its unread badge, is the one
        // way to notifications.
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
                            '$takenCount/${today.length} Taken',
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
                      today.isEmpty
                          ? 'No doses scheduled today'
                          : remaining == 0
                              ? 'All done for today!'
                              : '$remaining dose${remaining == 1 ? '' : 's'} still to take today',
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
                        _Pill(
                          label: '${today.length} dose${today.length == 1 ? '' : 's'} today',
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
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
                Container(
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
                const SizedBox(height: 18),
              ],

              // ==========================================
              // TODAY'S DOSES
              // ==========================================
              Text(
                'Today · ${DateFormatter.weekdayShort(now.weekday)}, ${DateFormatter.toShortDate(now)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 10),

              if (!hasSchedules)
                const _EmptyCard(
                  icon: Icons.medication_outlined,
                  title: 'No medications scheduled yet',
                  message: 'Your caregiver has not added any medicines yet. '
                      'They will appear here as soon as they do.',
                )
              else if (today.isEmpty)
                const _EmptyCard(
                  icon: Icons.event_available_rounded,
                  title: AppStrings.noSchedulesToday,
                  message: 'Check "View tomorrow" below for what is next.',
                )
              else ...[
                if (needsAction.isEmpty && upcoming.isEmpty) const _AllDone(),
                if (needsAction.isNotEmpty) ...[
                  _GroupLabel('NEEDS ACTION', color: AppColors.missedRed),
                  for (final slot in needsAction) _DoseCard(slot: slot, now: now),
                ],
                if (upcoming.isNotEmpty) ...[
                  _GroupLabel('UPCOMING'),
                  for (final slot in upcoming) _DoseCard(slot: slot, now: now),
                ],
                if (done.isNotEmpty)
                  _CollapsibleGroup(
                    title: 'DONE TODAY',
                    count: done.length,
                    flag: _needingReason(done, now),
                    children: [
                      for (final slot in done) _DoseCard(slot: slot, now: now),
                    ],
                  ),
              ],
              if (tomorrow.isNotEmpty)
                _CollapsibleGroup(
                  title: 'VIEW TOMORROW',
                  count: tomorrow.length,
                  children: [
                    for (final slot in tomorrow)
                      _DoseCard(slot: slot, now: now, tomorrow: true),
                  ],
                ),

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

  /// Missed doses still waiting for a reason, so the collapsed group can say
  /// so rather than hide them at the bottom.
  static int _needingReason(List<DoseSlot> slots, DateTime now) =>
      slots.where((s) => _needsReason(s, now)).length;
}

/// A missed dose without a reason: either the Worker marked it missed and
/// nobody has explained it, or it is past its missed window and not swept yet.
bool _needsReason(DoseSlot slot, DateTime now) {
  final log = slot.log;
  if (log != null && log.isMissed) return log.skippedReason.trim().isEmpty;
  return slot.isOpen &&
      DoseTiming.phaseOf(slot.scheduledAt, now) == DosePhase.missed;
}

class _GroupLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _GroupLabel(this.label, {this.color = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w800,
          color: color,
          fontFamily: AppStyles.fontFamily,
        ),
      ),
    );
  }
}

/// A group that starts collapsed, with its count in the header.
class _CollapsibleGroup extends StatefulWidget {
  final String title;
  final int count;

  /// Missed doses still needing a reason; shown on the header when > 0.
  final int flag;
  final List<Widget> children;

  const _CollapsibleGroup({
    required this.title,
    required this.count,
    required this.children,
    this.flag = 0,
  });

  @override
  State<_CollapsibleGroup> createState() => _CollapsibleGroupState();
}

class _CollapsibleGroupState extends State<_CollapsibleGroup> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Icon(
                  _open
                      ? Icons.expand_more_rounded
                      : Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.title} (${widget.count})',
                  style: const TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
                if (widget.flag > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.missedRedBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.flag} need${widget.flag == 1 ? 's' : ''} a reason',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.missedRed,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_open) ...widget.children,
      ],
    );
  }
}

/// One dose: name, date and time, status, and — while it is still open — the
/// Done and Skip buttons.
class _DoseCard extends StatelessWidget {
  final DoseSlot slot;
  final DateTime now;

  /// Tomorrow's doses are read-only except inside the early-logging window.
  final bool tomorrow;

  const _DoseCard({
    required this.slot,
    required this.now,
    this.tomorrow = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PatientProvider>();
    final schedule = slot.schedule;
    final med = provider.medicationFor(schedule.patMedRef);
    final medName = med?.medicationName.isNotEmpty == true
        ? med!.medicationName
        : 'Scheduled medication';
    final phase = DoseTiming.phaseOf(slot.scheduledAt, now);
    final badge = DoseStatusDisplay.badgeFor(slot.log, slot.scheduledAt, now);
    final open = slot.isOpen && phase != DosePhase.missed;
    final missed = (slot.log?.isMissed ?? false) ||
        (slot.isOpen && phase == DosePhase.missed);
    final needsReason = _needsReason(slot, now);
    final showsCol = provider.showsCompartment(schedule);

    final detail = [
      DateFormatter.doseDayTime(slot.scheduledAt, now: now),
      provider.doseInstructionFor(schedule),
      if (open) '${schedule.pillsRemaining} left',
    ].join(' · ');

    // Tomorrow: Done only, and only once the early window has opened.
    final earlyCheck = DoseTiming.checkEarly(
      slot.scheduledAt,
      now,
      previousDoseAt: tomorrow ? provider.previousDoseAt(slot) : null,
    );
    final showActions = open && (!tomorrow || earlyCheck.allowed);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MedicineDetailScreen(
            schedule: schedule,
            fallbackName: medName,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: AppStyles.cardDecoration.copyWith(
          border: Border.all(
            color: missed
                ? AppColors.missedRed.withValues(alpha: 0.3)
                : AppColors.borderGray,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MedicineBadge(
                  column: showsCol ? schedule.matBoxColumn : null,
                  dosageForm: med?.dosageForm ?? 'Tablet',
                  size: 46,
                  foreground: missed ? AppColors.missedRed : AppColors.patientBlue,
                  background: missed ? AppColors.missedRedBg : AppColors.blueLight,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medName,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _BadgeChip(badge),
                          if (slot.isOpen && phase != DosePhase.missed)
                            Text(
                              DoseTiming.countdown(slot.scheduledAt, now),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!open && slot.log != null && slot.log!.isResolved) ...[
              const SizedBox(height: 10),
              Text(
                DoseStatusDisplay.detailFor(slot.log!),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            if (needsReason) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => DoseActions.openMissed(context, slot),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text(
                    'Add reason',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.missedRed,
                    side: const BorderSide(color: AppColors.missedRed),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            if (showActions) ...[
              const SizedBox(height: 12),
              _DoseButtons(
                slot: slot,
                locked: phase == DosePhase.upcomingLocked,
                doneOnly: tomorrow,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final DoseBadge badge;

  const _BadgeChip(this.badge);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: badge.background,
        borderRadius: BorderRadius.circular(7),
        border: badge.outlined ? Border.all(color: badge.foreground) : null,
      ),
      child: Text(
        badge.label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: badge.foreground,
        ),
      ),
    );
  }
}

/// Done and Skip. Before the 30-minute window they look disabled with a lock
/// and "Actions unlock at …", but stay tappable: a tap asks whether the
/// patient is logging early (DOSE_LOGIC_PROPOSAL.md, 3.1).
class _DoseButtons extends StatelessWidget {
  final DoseSlot slot;
  final bool locked;
  final bool doneOnly;

  const _DoseButtons({
    required this.slot,
    required this.locked,
    this.doneOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final doneColor = locked ? AppColors.textMuted : AppColors.caregiverGreen;
    final skipColor = locked ? AppColors.textMuted : AppColors.missedRed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => DoseActions.take(context, slot),
                icon: Icon(
                  locked ? Icons.lock_outline_rounded : Icons.check_rounded,
                  size: 18,
                ),
                label: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      locked ? AppColors.background : AppColors.caregiverGreen,
                  foregroundColor: locked ? doneColor : Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 44),
                  side: locked
                      ? const BorderSide(color: AppColors.borderGray)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (!doneOnly) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => DoseActions.skip(context, slot),
                  icon: Icon(
                    locked ? Icons.lock_outline_rounded : Icons.close_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Skip',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: skipColor,
                    minimumSize: const Size(0, 44),
                    side: BorderSide(
                      color: locked ? AppColors.borderGray : AppColors.missedRed,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (locked) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                AppStrings.actionsUnlockAt(DateFormatter.toClockLabel(
                  DoseTiming.unlockAt(slot.scheduledAt),
                )),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(28),
      decoration: AppStyles.cardDecoration,
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
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

/// Shown once everything today has been dealt with.
class _AllDone extends StatelessWidget {
  const _AllDone();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(24),
      decoration: AppStyles.cardDecoration,
      child: const Column(
        children: [
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
            'Every dose has been dealt with. "Done today" below has the details.',
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
