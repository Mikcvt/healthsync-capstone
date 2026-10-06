import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_styles.dart';
import '../../models/device_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../../services/preferences_service.dart';
import '../../utils/date_formatter.dart';
import 'change_password_screen.dart';
import 'device_pairing_screen.dart';
import 'edit_profile_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _preferences = PreferencesService();
  PatientPreferences _prefs = const PatientPreferences();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  /// Reminder toggles are persisted on the device. They were plain setState
  /// fields, so every switch reset itself as soon as the screen closed.
  Future<void> _loadPreferences() async {
    final loaded = await _preferences.load();
    if (!mounted) return;
    setState(() => _prefs = loaded);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _ProfileHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _ProfileCard(
                      doseReminders: _prefs.doseReminders,
                      reminderSound: _prefs.reminderSound,
                      fullScreenAlert: _prefs.fullScreenAlert,
                      onToggleDoseReminders: (value) {
                        setState(() =>
                            _prefs = _prefs.copyWith(doseReminders: value));
                        _preferences.setDoseReminders(value);
                      },
                      onToggleReminderSound: (value) {
                        setState(() =>
                            _prefs = _prefs.copyWith(reminderSound: value));
                        _preferences.setReminderSound(value);
                      },
                      onToggleFullScreenAlert: (value) {
                        setState(() =>
                            _prefs = _prefs.copyWith(fullScreenAlert: value));
                        _preferences.setFullScreenAlert(value);
                      },
                    ),
                    const SizedBox(height: 16),
                    _DeviceStatusCard(
                      device: context.watch<PatientProvider>().device,
                    ),
                    const SizedBox(height: 16),
                    Text('Quick actions', style: AppStyles.heading3),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionPill(
                            icon: Icons.sync,
                            label: 'Medicine box',
                            color: AppColors.patientBlue,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DevicePairingScreen(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionPill(
                            icon: Icons.history_rounded,
                            label: 'Reminder log',
                            color: AppColors.caregiverGreen,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Account', style: AppStyles.heading3),
                    const SizedBox(height: 12),
                    _ProfileOption(
                      label: 'Edit profile',
                      subtitle: 'Name, email, phone',
                      icon: Icons.person_outline,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ProfileOption(
                      label: 'Change password',
                      subtitle: 'Secure your account',
                      icon: Icons.lock_outline,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ProfileOption(
                      label: 'Settings',
                      subtitle: 'App preferences',
                      icon: Icons.settings,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ProfileOption(
                      label: 'About HealthSync',
                      subtitle: 'Version 1.0.0',
                      icon: Icons.info_outline,
                      onTap: () => showAboutHealthSync(context),
                    ),
                    const SizedBox(height: 12),
                    _ProfileOption(
                      label: 'Sign out',
                      subtitle: '',
                      icon: Icons.logout,
                      dangerous: true,
                      onTap: _handleSignOut,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Are you sure you want to sign out of HealthSync?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.missedRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<AuthProvider>().signOut();
    if (!mounted) return;
    // Pop back to AuthGate rather than pushing WelcomeScreen over it.
    // pushAndRemoveUntil((route) => false) would destroy AuthGate, and every
    // later sign-in would then have nothing to route it to the dashboard.
    // AuthGate already renders WelcomeScreen when signed out.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SizedBox(height: 8),
          Text(
            'HealthSync',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              fontFamily: AppStyles.fontFamily,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Patient profile and device status',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontFamily: AppStyles.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final bool doseReminders;
  final bool reminderSound;
  final bool fullScreenAlert;
  final ValueChanged<bool> onToggleDoseReminders;
  final ValueChanged<bool> onToggleReminderSound;
  final ValueChanged<bool> onToggleFullScreenAlert;

  const _ProfileCard({
    required this.doseReminders,
    required this.reminderSound,
    required this.fullScreenAlert,
    required this.onToggleDoseReminders,
    required this.onToggleReminderSound,
    required this.onToggleFullScreenAlert,
  });

  /// A managed patient has no email of their own, so show whatever identifies
  /// them — phone if the caregiver recorded one, otherwise nothing rather than
  /// a fabricated address.
  static String _contactLine(UserModel? user) {
    final parts = [
      if (user?.email.trim().isNotEmpty == true) user!.email.trim(),
      if (user?.phone.trim().isNotEmpty == true) user!.phone.trim(),
    ];
    return parts.isEmpty ? 'Managed by your caregiver' : parts.join(' · ');
  }

  static String _roleLabel(UserModel? user) {
    if (user == null) return 'Patient';
    if (user.isSolo) return 'Managing my own medicines';
    if (user.isManaged) return 'Patient · managed by caregiver';
    return 'Patient';
  }

  static String _initials(String name) {
    final parts = name.split(' ').where((p) => p.isNotEmpty).take(2);
    if (parts.isEmpty) return '?';
    return parts.map((p) => p[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUserModel;

    return Container(
      width: double.infinity,
      decoration: AppStyles.cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: AppColors.blueGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(user?.fullName ?? ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName.trim().isNotEmpty == true
                          ? user!.fullName
                          : 'Your profile',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        fontFamily: AppStyles.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _contactLine(user),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontFamily: AppStyles.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _roleLabel(user),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.patientBlue,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppStyles.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ToggleRow(
            label: 'Dose reminders',
            subtitle: 'Notify me when a dose is due',
            value: doseReminders,
            onChanged: onToggleDoseReminders,
          ),
          const Divider(height: 24, thickness: 1, color: AppColors.borderGray),
          _ToggleRow(
            label: 'Reminder sound',
            subtitle: 'Play a sound with each reminder',
            value: reminderSound,
            onChanged: onToggleReminderSound,
          ),
          const Divider(height: 24, thickness: 1, color: AppColors.borderGray),
          _ToggleRow(
            label: 'Full-screen alert',
            subtitle: 'Open the dose screen, not just a notification',
            value: fullScreenAlert,
            onChanged: onToggleFullScreenAlert,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

class _DeviceStatusCard extends StatelessWidget {
  final DeviceModel? device;

  const _DeviceStatusCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final paired = device != null;
    return Container(
      width: double.infinity,
      decoration: AppStyles.cardDecoration,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          _StatusRow(
            label: 'Medicine box',
            value: !paired
                ? 'Not paired'
                : '${device!.serialNumber} · '
                    '${device!.isOnline ? AppStrings.deviceOnline : AppStrings.deviceOffline}',
            active: paired && device!.isOnline,
          ),
          if (paired) ...[
            const Divider(height: 26, thickness: 1, color: AppColors.borderGray),
            _StatusRow(
              label: 'Last sync',
              value: DateFormatter.toRelativeTime(device!.lastSync),
              active: device!.isOnline,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final bool active;

  const _StatusRow({
    required this.label,
    required this.value,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: active ? AppColors.caregiverGreen : AppColors.missedRed,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool dangerous;
  final VoidCallback onTap;

  const _ProfileOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.dangerous = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: dangerous ? AppColors.missedRed : AppColors.patientBlue,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: dangerous
                            ? AppColors.missedRed
                            : AppColors.textPrimary,
                        fontFamily: AppStyles.fontFamily,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFamily: AppStyles.fontFamily,
                        ),
                      ),
                    ],
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
      ),
    );
  }
}
