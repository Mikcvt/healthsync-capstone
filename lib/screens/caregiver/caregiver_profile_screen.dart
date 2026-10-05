import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/caregiver_provider.dart';
import 'caregiver_alerts_screen.dart';

class CaregiverProfileScreen extends StatefulWidget {
  const CaregiverProfileScreen({super.key});

  @override
  State<CaregiverProfileScreen> createState() => _CaregiverProfileScreenState();
}

class _CaregiverProfileScreenState extends State<CaregiverProfileScreen> {
  bool _alertMissed = true;
  bool _alertVitals = true;
  bool _alertDaily = true;
  bool _prefsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prefsLoaded) {
      final profile = context.read<CaregiverProvider>().profile;
      if (profile != null) {
        _alertMissed = profile.alertPrefMissed;
        _alertVitals = profile.alertPrefVitals;
        _alertDaily = profile.alertPrefDaily;
        _prefsLoaded = true;
      }
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign Out',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
        content: const Text(
          'Are you sure you want to sign out? You will stop receiving patient alerts until you sign back in.',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.missedRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().signOut();
      if (mounted) {
        // Back to AuthGate — it renders WelcomeScreen when signed out, and
        // destroying it here would break every subsequent sign-in.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final caregiverProvider = context.watch<CaregiverProvider>();
    final user = authProvider.currentUserModel;
    final patientCount = caregiverProvider.patientLinks.length;
    final firstName = user?.firstName ?? 'Caregiver';
    final lastName = user?.lastName ?? '';
    final email = user?.email ?? '';
    final phone = user?.phone ?? '';
    final initials = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                decoration: BoxDecoration(
                  gradient: AppColors.greenGradient,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '$firstName $lastName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        phone,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.groups_2_outlined, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '$patientCount ${patientCount == 1 ? 'patient' : 'patients'} linked',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Alert Preferences
                    const _SectionLabel(label: 'ALERT PREFERENCES'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: AppStyles.cardDecoration,
                      child: Column(
                        children: [
                          _ToggleRow(
                            icon: Icons.notification_important_outlined,
                            label: 'Missed dose alerts',
                            subtitle: 'Get notified when patient misses a dose',
                            value: _alertMissed,
                            color: AppColors.missedRed,
                            onChanged: (val) {
                              setState(() => _alertMissed = val);
                              caregiverProvider.updateAlertPreferences(alertPrefMissed: val);
                            },
                          ),
                          const Divider(color: AppColors.borderGray, height: 1),
                          _ToggleRow(
                            icon: Icons.monitor_heart_outlined,
                            label: 'Vitals alerts',
                            subtitle: 'Heart rate & health data updates',
                            value: _alertVitals,
                            color: AppColors.patientBlue,
                            onChanged: (val) {
                              setState(() => _alertVitals = val);
                              caregiverProvider.updateAlertPreferences(alertPrefVitals: val);
                            },
                          ),
                          const Divider(color: AppColors.borderGray, height: 1),
                          _ToggleRow(
                            icon: Icons.summarize_outlined,
                            label: 'Daily summary',
                            subtitle: 'End-of-day adherence recap',
                            value: _alertDaily,
                            color: AppColors.caregiverGreen,
                            onChanged: (val) {
                              setState(() => _alertDaily = val);
                              caregiverProvider.updateAlertPreferences(alertPrefDaily: val);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Account Section
                    const _SectionLabel(label: 'ACCOUNT'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: AppStyles.cardDecoration,
                      child: Column(
                        children: [
                          _ActionRow(
                            icon: Icons.notifications_none_rounded,
                            label: 'Alert history',
                            subtitle: 'View past notifications',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CaregiverAlertsScreen(),
                                ),
                              );
                            },
                          ),
                          const Divider(color: AppColors.borderGray, height: 1),
                          _ActionRow(
                            icon: Icons.info_outline,
                            label: 'About HealthSync',
                            subtitle: 'Version 1.0.0',
                            onTap: () {
                              showAboutDialog(
                                context: context,
                                applicationName: 'HealthSync',
                                applicationVersion: '1.0.0',
                                applicationLegalese: '© 2026 HealthSync Capstone',
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Sign Out
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _handleSignOut,
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.missedRed,
                          side: const BorderSide(color: AppColors.missedRed),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

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

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                const SizedBox(height: 2),
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
            activeThumbColor: AppColors.caregiverGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.caregiverGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.caregiverGreen, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                  const SizedBox(height: 2),
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
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
