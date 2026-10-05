import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  bool _doseReminders = true;
  bool _guardianAlerts = true;
  bool _missedDoseAlerts = true;
  final bool _smartwatchConnected = true;
  final bool _medicineBoxOnline = true;

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
                      doseReminders: _doseReminders,
                      guardianAlerts: _guardianAlerts,
                      missedDoseAlerts: _missedDoseAlerts,
                      onToggleDoseReminders: (value) => setState(() {
                        _doseReminders = value;
                      }),
                      onToggleGuardianAlerts: (value) => setState(() {
                        _guardianAlerts = value;
                      }),
                      onToggleMissedDoseAlerts: (value) => setState(() {
                        _missedDoseAlerts = value;
                      }),
                    ),
                    const SizedBox(height: 16),
                    _DeviceStatusCard(
                      smartwatchConnected: _smartwatchConnected,
                      medicineBoxOnline: _medicineBoxOnline,
                    ),
                    const SizedBox(height: 16),
                    Text('Quick actions', style: AppStyles.heading3),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionPill(
                            icon: Icons.sync,
                            label: 'Sync devices',
                            color: AppColors.patientBlue,
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionPill(
                            icon: Icons.history_rounded,
                            label: 'Reminder log',
                            color: AppColors.caregiverGreen,
                            onTap: () {},
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
                      onTap: () {},
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
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Patient profile and device status',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final bool doseReminders;
  final bool guardianAlerts;
  final bool missedDoseAlerts;
  final ValueChanged<bool> onToggleDoseReminders;
  final ValueChanged<bool> onToggleGuardianAlerts;
  final ValueChanged<bool> onToggleMissedDoseAlerts;

  const _ProfileCard({
    required this.doseReminders,
    required this.guardianAlerts,
    required this.missedDoseAlerts,
    required this.onToggleDoseReminders,
    required this.onToggleGuardianAlerts,
    required this.onToggleMissedDoseAlerts,
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
                    fontFamily: 'PlusJakartaSans',
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
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _contactLine(user),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _roleLabel(user),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.patientBlue,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'PlusJakartaSans',
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
            subtitle: 'Mobile push notifications',
            value: doseReminders,
            onChanged: onToggleDoseReminders,
          ),
          const Divider(height: 24, thickness: 1, color: AppColors.borderGray),
          _ToggleRow(
            label: 'Guardian alerts',
            subtitle: 'Allow caregiver monitoring',
            value: guardianAlerts,
            onChanged: onToggleGuardianAlerts,
          ),
          const Divider(height: 24, thickness: 1, color: AppColors.borderGray),
          _ToggleRow(
            label: 'Missed dose alerts',
            subtitle: 'Alert after 30 min overdue',
            value: missedDoseAlerts,
            onChanged: onToggleMissedDoseAlerts,
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
          activeThumbColor: AppColors.patientBlue,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _DeviceStatusCard extends StatelessWidget {
  final bool smartwatchConnected;
  final bool medicineBoxOnline;

  const _DeviceStatusCard({
    required this.smartwatchConnected,
    required this.medicineBoxOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: AppStyles.cardDecoration,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          _StatusRow(
            label: 'Smartwatch',
            value: smartwatchConnected ? 'WearOS · Connected' : 'Disconnected',
            active: smartwatchConnected,
          ),
          const Divider(height: 26, thickness: 1, color: AppColors.borderGray),
          _StatusRow(
            label: 'Medicine Box',
            value: medicineBoxOnline ? 'HSD-00142 · Online' : 'Offline',
            active: medicineBoxOnline,
          ),
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
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontFamily: 'PlusJakartaSans',
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
                  fontFamily: 'PlusJakartaSans',
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
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFamily: 'PlusJakartaSans',
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
