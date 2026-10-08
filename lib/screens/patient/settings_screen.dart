import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../services/preferences_service.dart';

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
                        // No "Full-screen alert" switch: a reminder over the
                        // lock screen is deferred until after Play Store
                        // approval (DOSE_LOGIC_PROPOSAL.md, decision 4).
                        // Tapping any reminder opens the dose screen.
                      ],
                    ),
                    const SizedBox(height: 20),

                    // The caregiver controls which alerts they receive, so
                    // say so rather than offering a switch that does nothing.
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
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }
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
