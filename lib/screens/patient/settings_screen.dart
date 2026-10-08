import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/auth_provider.dart';
import '../../services/preferences_service.dart';
import 'notifications_screen.dart';

/// App preferences for a patient.
///
/// The reminder toggles are device-local and persisted through
/// [PreferencesService] — they used to be plain `setState` fields that reset
/// every time the screen closed. Caregiver-facing alerts are deliberately
/// absent: the Worker sends those from the caregiver's own preferences, so a
/// switch here could never have affected them. An "SMS fallback" toggle was
/// also removed — there is no SMS gateway anywhere in this stack.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _preferences = PreferencesService();
  PatientPreferences _prefs = const PatientPreferences();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await _preferences.load();
    if (!mounted) return;
    setState(() {
      _prefs = loaded;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isManaged = context.select<AuthProvider, bool>((a) => a.isManaged);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.patientBlue),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontFamily: AppStyles.fontFamily,
          ),
        ),
      ),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(label: 'REMINDERS ON THIS PHONE'),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      children: [
                        _SettingsToggleRow(
                          label: 'Dose reminders',
                          subtitle: 'Notify me when a dose is due',
                          value: _prefs.doseReminders,
                          onChanged: (value) {
                            setState(() => _prefs =
                                _prefs.copyWith(doseReminders: value));
                            _preferences.setDoseReminders(value);
                          },
                        ),
                        const Divider(color: AppColors.borderGray, height: 24),
                        _SettingsToggleRow(
                          label: 'Reminder sound',
                          subtitle: 'Play a sound with each reminder',
                          value: _prefs.reminderSound,
                          onChanged: (value) {
                            setState(() => _prefs =
                                _prefs.copyWith(reminderSound: value));
                            _preferences.setReminderSound(value);
                          },
                        ),
                        const Divider(color: AppColors.borderGray, height: 24),
                        _SettingsToggleRow(
                          label: 'Full-screen alert',
                          subtitle:
                              'Open the dose screen, not just a notification',
                          value: _prefs.fullScreenAlert,
                          onChanged: (value) {
                            setState(() => _prefs =
                                _prefs.copyWith(fullScreenAlert: value));
                            _preferences.setFullScreenAlert(value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // A managed patient's caregiver controls their alerts, so
                    // say so rather than offering a switch that does nothing.
                    if (isManaged) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.blueLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 20, color: AppColors.blueDark),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Your caregiver manages which alerts they '
                                'receive about your doses.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.5,
                                  color: AppColors.blueDark,
                                  fontFamily: AppStyles.fontFamily,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    const _SectionHeader(label: 'ABOUT'),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      children: [
                        _SettingsActionRow(
                          label: 'Notification history',
                          subtitle: 'Every alert you have received',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          ),
                        ),
                        const Divider(color: AppColors.borderGray, height: 24),
                        _SettingsActionRow(
                          label: 'About HealthSync',
                          subtitle: 'Version 1.0.0',
                          onTap: () => showAboutHealthSync(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Shared by the settings and profile screens so the two "About" entries cannot
/// drift apart.
void showAboutHealthSync(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: 'HealthSync',
    applicationVersion: '1.0.0',
    applicationIcon: const Icon(
      Icons.medication_liquid_rounded,
      color: AppColors.patientBlue,
      size: 34,
    ),
    children: const [
      SizedBox(height: 8),
      Text(
        'An IoT-based LED-guided smart medicine box with mobile integration '
        'for medication adherence.',
        style: TextStyle(fontSize: 13, height: 1.6),
      ),
      SizedBox(height: 12),
      Text(
        'BSIT Capstone Project 2025-2026\n'
        'The National Teachers College, Quiapo, Manila',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          height: 1.6,
        ),
      ),
    ],
  );
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 1.5,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        fontFamily: AppStyles.fontFamily,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: AppStyles.cardDecoration,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.patientBlue,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsActionRow({
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
