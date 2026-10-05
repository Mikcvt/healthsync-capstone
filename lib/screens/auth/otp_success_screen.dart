import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/schedule_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

/// Confirms to a managed patient that they are in, and shows the schedule their
/// caregiver already built for them.
///
/// Seeing their real medicines here is the proof that the "no setup" promise
/// held — landing on an empty dashboard would feel like the code failed.
class OtpSuccessScreen extends StatelessWidget {
  final String patientName;

  const OtpSuccessScreen({super.key, required this.patientName});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().currentUid;
    final firstName = patientName.split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.takenGreenBg,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.takenGreen,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                firstName.isEmpty ? "You're all set" : "You're all set, $firstName",
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your caregiver has already set up your medicines. '
                'You just need to confirm each dose when the box lights up.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontFamily: 'PlusJakartaSans',
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                'Your schedule',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: uid == null
                    ? const SizedBox.shrink()
                    : StreamBuilder<List<ScheduleModel>>(
                        stream:
                            FirestoreService().streamPatientSchedules(uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            );
                          }

                          final schedules = snapshot.data ?? const [];
                          if (schedules.isEmpty) {
                            return _EmptySchedule();
                          }

                          return ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: schedules.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) =>
                                _ScheduleRow(schedule: schedules[index]),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    // Return to AuthGate rather than pushing the dashboard
                    // directly. AuthGate owns provider initialisation, so
                    // going through it is what makes the schedule appear.
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.patientBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Go to my dashboard',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final ScheduleModel schedule;

  const _ScheduleRow({required this.schedule});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.ledActiveBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${schedule.matBoxColumn}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.ledActive,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.scheduledTime,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Compartment ${schedule.matBoxColumn}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 32,
            color: AppColors.textMuted,
          ),
          SizedBox(height: 12),
          Text(
            'No medicines added yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Your caregiver will add them shortly. '
            'You will get a reminder when it is time for a dose.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontFamily: 'PlusJakartaSans',
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
