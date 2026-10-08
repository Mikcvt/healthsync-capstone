import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';

/// Shared by the patient settings and profile screens so the two "About"
/// entries cannot drift apart.
///
/// Replaces Flutter's `showAboutDialog`, whose "View licenses" button opened
/// the engine's full license list — hundreds of entries for packages a reader
/// of this app never chose. The summary below names what HealthSync itself
/// depends on.
void showAboutHealthSync(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AboutSheet(),
  );
}

class _AboutSheet extends StatelessWidget {
  const _AboutSheet();

  static const _version = '1.0.0';

  static const _team = [
    'Martin, Merry Siemonne O.',
    'Cervantes, Miko D.',
    'Fernandez, Adia Charlotte',
    'General, Feonna Anne D.',
    'San Luis, Christian D.',
  ];

  static const _licenses = [
    ('Flutter SDK', 'BSD 3-Clause'),
    ('Firebase plugins (Core, Auth, Firestore, Messaging)', 'BSD 3-Clause'),
    ('Firebase Android SDKs', 'Apache 2.0'),
    ('flutter_local_notifications, shared_preferences, http', 'BSD 3-Clause'),
    ('provider', 'MIT'),
    ('timezone', 'BSD 2-Clause'),
    ('Plus Jakarta Sans font', 'SIL Open Font License 1.1'),
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.medication_liquid_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HealthSync',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontFamily: AppStyles.fontFamily,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Version $_version',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFamily: AppStyles.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'An IoT-Based LED-Guided Smart Medicine Box with Mobile '
              'Integration for Medication Adherence',
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: AppStyles.fontFamily,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'BSIT Capstone Project 2025–2026\n'
              'National Teachers College, Quiapo, Manila',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.55,
                color: AppColors.textSecondary,
                fontFamily: AppStyles.fontFamily,
              ),
            ),
            const SizedBox(height: 22),
            const _Heading('DEVELOPMENT TEAM'),
            const SizedBox(height: 8),
            for (final name in _team)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontFamily: AppStyles.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 22),
            const _Heading('OPEN-SOURCE LICENSES'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderGray),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (final (component, license) in _licenses)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              component,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textPrimary,
                                fontFamily: AppStyles.fontFamily,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            license,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              fontFamily: AppStyles.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'These components are used under their respective licenses. '
              'HealthSync is an academic project and is not a substitute for '
              'professional medical advice.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: AppColors.textMuted,
                fontFamily: AppStyles.fontFamily,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.patientBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String label;

  const _Heading(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11.5,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        fontFamily: AppStyles.fontFamily,
      ),
    );
  }
}
