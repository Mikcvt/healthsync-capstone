import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../models/dose_log_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/caregiver_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/shared/floating_nav_bar.dart';
import 'add_patient_screen.dart';
import 'patient_detail_screen.dart';

/// What the caregiver sees first: every patient, and what each of them still
/// has to take today.
///
/// This used to show one aggregate card for whichever patient happened to be
/// selected, so a caregiver monitoring two people saw nothing about the second
/// and no way to reach either.
class CaregiverDashboardScreen extends StatelessWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CaregiverProvider>();
    final user = context.watch<AuthProvider>().currentUserModel;
    final links = provider.patientLinks;
    final firstName = user?.firstName.isNotEmpty == true
        ? user!.firstName
        : 'Caregiver';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          // Clears the floating nav bar so the last card is not hidden by it.
          padding: const EdgeInsets.fromLTRB(
              20, 16, 20, FloatingNavBar.contentPadding),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Guardian Dashboard',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hello, $firstName',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        links.isEmpty
                            ? 'No patients yet'
                            : 'Monitoring ${links.length} '
                                '${links.length == 1 ? 'patient' : 'patients'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (links.isNotEmpty) ...[
              _OverviewCard(links: links),
              const SizedBox(height: 18),
            ],

            if (links.isEmpty)
              _NoPatients(
                onAdd: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddPatientScreen()),
                ),
              )
            else
              ...links.map(
                (link) => _PatientTodayCard(patientUid: link.patientRef),
              ),
          ],
        ),
      ),
    );
  }
}

/// One patient's day, read straight from their dose logs.
class _PatientTodayCard extends StatelessWidget {
  final String patientUid;

  const _PatientTodayCard({required this.patientUid});

  Future<void> _open(BuildContext context, String name) async {
    await context.read<CaregiverProvider>().selectPatient(patientUid);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PatientDetailScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final today = DateFormatter.toDateKey(DateTime.now());

    return StreamBuilder<UserModel?>(
      stream: firestore.streamUser(patientUid),
      builder: (context, userSnapshot) {
        final name = userSnapshot.data?.fullName.trim();
        final displayName = (name == null || name.isEmpty) ? 'Loading…' : name;

        return StreamBuilder<List<DoseLogModel>>(
          stream: firestore.streamPatientDoseLogs(patientUid, dateStr: today),
          builder: (context, logSnapshot) {
            final logs = logSnapshot.data ?? const <DoseLogModel>[];
            final taken = logs.where((l) => l.isTaken).length;
            // Missed and skipped together: doses not taken today.
            final missed =
                logs.where((l) => l.isMissed || l.isSkipped).length;
            final outstanding =
                logs.where((l) => l.isOpen).toList()
                  ..sort((a, b) {
                    final x = a.scheduledAt, y = b.scheduledAt;
                    if (x == null || y == null) return 0;
                    return x.compareTo(y);
                  });

            return InkWell(
              onTap: () => _open(context, displayName),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: AppStyles.cardDecoration.copyWith(
                  border: Border.all(
                    color: missed > 0
                        ? AppColors.missedRed.withValues(alpha: 0.35)
                        : AppColors.borderGray,
                    width: missed > 0 ? 1.4 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.patientBlue,
                          child: Text(
                            _initials(displayName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                logs.isEmpty
                                    ? 'No doses scheduled today'
                                    : '$taken of ${logs.length} taken today',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (missed > 0)
                          _Pill(
                            label: '$missed not taken',
                            fg: AppColors.missedRed,
                            bg: AppColors.missedRedBg,
                          ),
                      ],
                    ),

                    // The point of the screen: what is still owed today, with
                    // times, rather than a single count that says nothing about
                    // what to chase.
                    if (outstanding.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: AppColors.borderGray),
                      const SizedBox(height: 12),
                      Text(
                        'Still to take',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: outstanding
                            .take(6)
                            .map(
                              (log) => _Pill(
                                label: log.scheduledTime.isEmpty
                                    ? 'Dose'
                                    : log.scheduledTime,
                                fg: AppColors.pendingAmber,
                                bg: AppColors.pendingAmberBg,
                              ),
                            )
                            .toList(),
                      ),
                    ] else if (logs.isNotEmpty && missed == 0) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: const [
                          Icon(Icons.check_circle_rounded,
                              size: 16, color: AppColors.takenGreen),
                          SizedBox(width: 6),
                          Text(
                            'All doses done for today',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.takenGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _initials(String value) => value
      .split(' ')
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0])
      .join()
      .toUpperCase();
}

class _Pill extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;

  const _Pill({required this.label, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      );
}

class _NoPatients extends StatelessWidget {
  final VoidCallback onAdd;
  const _NoPatients({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: AppStyles.cardDecoration,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.group_outlined,
                size: 30, color: AppColors.caregiverGreen),
          ),
          const SizedBox(height: 16),
          const Text(
            'No patients yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create an account for the person you care for, set up their '
            'medicines, then send them a code.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.caregiverGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              label: const Text(
                'Add your first patient',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The gradient hero from the original design, now driven by real data rather
/// than a hardcoded line.
class _OverviewCard extends StatelessWidget {
  final List<dynamic> links;

  const _OverviewCard({required this.links});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final today = DateFormatter.toDateKey(DateTime.now());
    final uids = links.map((l) => l.patientRef as String).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.greenGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.favorite_rounded,
                    color: Colors.white, size: 21),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "TODAY'S OVERVIEW",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // One stream per patient, folded into a single headline. Reusing the
          // same streams as the cards below costs nothing: Firestore dedupes
          // identical listeners.
          _AggregateCounts(uids: uids, firestore: firestore, today: today),
        ],
      ),
    );
  }
}

class _AggregateCounts extends StatelessWidget {
  final List<String> uids;
  final FirestoreService firestore;
  final String today;

  const _AggregateCounts({
    required this.uids,
    required this.firestore,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<List<DoseLogModel>>>(
      stream: _combine(),
      builder: (context, snapshot) {
        final all = (snapshot.data ?? const <List<DoseLogModel>>[])
            .expand((e) => e)
            .toList();
        final taken = all.where((l) => l.isTaken).length;
        final missed = all.where((l) => l.isMissed || l.isSkipped).length;
        final due = all.where((l) => l.isOpen).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              // Missed doses outrank pending ones. Saying "0 still to take"
              // while twelve were missed reads as "nothing to do" on the one
              // screen whose job is surfacing problems.
              _headline(total: all.length, due: due, missed: missed),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(label: 'Taken', value: taken),
                const SizedBox(width: 10),
                _Stat(label: 'Due', value: due),
                const SizedBox(width: 10),
                _Stat(label: 'Not taken', value: missed),
              ],
            ),
          ],
        );
      },
    );
  }

  static String _headline({
    required int total,
    required int due,
    required int missed,
  }) {
    if (total == 0) return 'No doses scheduled today';
    if (missed > 0 && due > 0) {
      return '$missed not taken · $due still due';
    }
    if (missed > 0) {
      return '$missed dose${missed == 1 ? '' : 's'} not taken today';
    }
    if (due > 0) return '$due still to take';
    return 'Everyone is on track';
  }

  /// Merges each patient's today-stream into one list-of-lists.
  Stream<List<List<DoseLogModel>>> _combine() {
    if (uids.isEmpty) return Stream.value(const []);
    final streams =
        uids.map((u) => firestore.streamPatientDoseLogs(u, dateStr: today));

    return streams.skip(1).fold<Stream<List<List<DoseLogModel>>>>(
      streams.first.map((logs) => [logs]),
      (acc, next) => acc.asyncMap((soFar) async {
        final latest = await next.first;
        return [...soFar, latest];
      }),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}
