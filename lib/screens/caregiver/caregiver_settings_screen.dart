import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/caregiver_provider.dart';
import '../patient/change_password_screen.dart';

class CaregiverSettingsScreen extends StatefulWidget {
  const CaregiverSettingsScreen({super.key});

  @override
  State<CaregiverSettingsScreen> createState() =>
      _CaregiverSettingsScreenState();
}

class _CaregiverSettingsScreenState extends State<CaregiverSettingsScreen> {
  Future<void> _editProfile() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUserModel;
    if (user == null) return;
    final first = TextEditingController(text: user.firstName);
    final last = TextEditingController(text: user.lastName);
    final phone = TextEditingController(text: user.phone);
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit profile'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: first,
                decoration: AppStyles.inputDecoration('First name'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: last,
                decoration: AppStyles.inputDecoration('Last name'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                decoration: AppStyles.inputDecoration('Phone number'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final success = await auth.updateProfile(
                firstName: first.text,
                lastName: last.text,
                phone: phone.text,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext, success);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    first.dispose();
    last.dispose();
    phone.dispose();
    if (saved == false && mounted) {
      _showMessage(auth.errorMessage ?? 'Profile update failed.');
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This signs you out and deactivates your account. This action cannot be undone from the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.missedRed),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.deleteAccount();
    if (!mounted) return;
    if (success) {
      // AuthGate renders WelcomeScreen once the account is gone; replacing the
      // root here would leave later sign-ins with nothing to route them.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _showMessage(
        auth.errorMessage ??
            'Account deletion failed. Sign in again and retry.',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final caregiver = context.watch<CaregiverProvider>();
    final user = auth.currentUserModel;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Profile & Settings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: AppStyles.cardDecoration,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.caregiverGreen,
                    child: Text(
                      _initials(user?.firstName ?? '', user?.lastName ?? ''),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Caregiver',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if ((user?.phone ?? '').isNotEmpty)
                          Text(
                            user!.phone,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit profile',
                    onPressed: _editProfile,
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.caregiverGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('NOTIFICATIONS'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _ToggleRow(
                  label: 'Missed dose alerts',
                  subtitle: 'Notify me when a patient misses a dose',
                  value: caregiver.profile?.alertPrefMissed ?? true,
                  onChanged: (value) =>
                      caregiver.updateAlertPreferences(alertPrefMissed: value),
                ),
                const Divider(height: 1, color: AppColors.borderGray),
                _ToggleRow(
                  label: 'Vitals alerts',
                  subtitle: 'Receive patient health updates',
                  value: caregiver.profile?.alertPrefVitals ?? true,
                  onChanged: (value) =>
                      caregiver.updateAlertPreferences(alertPrefVitals: value),
                ),
                const Divider(height: 1, color: AppColors.borderGray),
                _ToggleRow(
                  label: 'Daily summary',
                  subtitle: 'Receive an end-of-day adherence recap',
                  value: caregiver.profile?.alertPrefDaily ?? true,
                  onChanged: (value) =>
                      caregiver.updateAlertPreferences(alertPrefDaily: value),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('SECURITY'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _ActionRow(
                  icon: Icons.lock_outline,
                  label: 'Change password',
                  subtitle: 'Update your sign-in password',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('ACCOUNT'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _ActionRow(
                  icon: Icons.logout_rounded,
                  label: 'Sign out',
                  subtitle: 'Sign out of this device',
                  onTap: () async {
                    // Capture the navigator before awaiting: `context` must
                    // not be read after the gap, and signOut tears down the
                    // widget tree this row lives in.
                    final navigator = Navigator.of(context);
                    await auth.signOut();
                    if (!context.mounted) return;
                    // Back to AuthGate, which shows WelcomeScreen when signed
                    // out. Removing it would break the next sign-in.
                    navigator.popUntil((route) => route.isFirst);
                  },
                ),
                const Divider(height: 1, color: AppColors.borderGray),
                _ActionRow(
                  icon: Icons.delete_outline,
                  label: 'Delete account',
                  subtitle: 'Deactivate your HealthSync account',
                  color: AppColors.missedRed,
                  onTap: _deleteAccount,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String first, String last) =>
      '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}'
          .toUpperCase();
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(
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

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: AppStyles.cardDecoration,
    child: Column(children: children),
  );
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(
      children: [
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
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
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

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color? color;
  final VoidCallback onTap;
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.color,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: ListTile(
      leading: Icon(icon, color: color ?? AppColors.caregiverGreen),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: color ?? AppColors.textPrimary,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
