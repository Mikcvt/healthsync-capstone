import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _smsFallback = false;
  bool _notifyGuardianOnMiss = true;
  bool _missedDoseAlert = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: AppColors.patientBlue),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(label: 'TODAY'),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _SettingsToggleRow(
                    label: 'Push Notifications',
                    subtitle: 'Send reminders on your phone',
                    value: _pushNotifications,
                    onChanged: (value) => setState(() {
                      _pushNotifications = value;
                    }),
                  ),
                  const Divider(color: AppColors.borderGray, height: 24),
                  _SettingsToggleRow(
                    label: 'SMS fallback',
                    subtitle: 'Send SMS if app is unreachable',
                    value: _smsFallback,
                    onChanged: (value) => setState(() {
                      _smsFallback = value;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _SectionHeader(label: 'TODAY'),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _SettingsToggleRow(
                    label: 'Notify guardian on miss',
                    subtitle: 'Share missed dose alerts',
                    value: _notifyGuardianOnMiss,
                    onChanged: (value) => setState(() {
                      _notifyGuardianOnMiss = value;
                    }),
                  ),
                  const Divider(color: AppColors.borderGray, height: 24),
                  _SettingsToggleRow(
                    label: 'Missed dose alert',
                    subtitle: 'Notify after 30 mins overdue',
                    value: _missedDoseAlert,
                    onChanged: (value) => setState(() {
                      _missedDoseAlert = value;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _SectionHeader(label: 'TODAY'),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _SettingsActionRow(
                    label: 'Privacy policy',
                    subtitle: 'View our privacy terms',
                    onTap: () {},
                  ),
                  const Divider(color: AppColors.borderGray, height: 24),
                  _SettingsActionRow(
                    label: 'About HealthSync',
                    subtitle: 'Version 1.0.0',
                    onTap: () {},
                  ),
                ],
              ),
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
        fontFamily: 'PlusJakartaSans',
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
        crossAxisAlignment: CrossAxisAlignment.center,
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
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                const SizedBox(height: 4),
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
          Switch(
            value: value,
            activeColor: AppColors.patientBlue,
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
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                  const SizedBox(height: 4),
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
