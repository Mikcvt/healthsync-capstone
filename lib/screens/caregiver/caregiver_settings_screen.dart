import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/caregiver_provider.dart';
import '../../services/firestore_service.dart';
import '../patient/change_password_screen.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/shared/confirm_dialog.dart';
import '../../widgets/shared/legal_links.dart';
import '../../widgets/shared/reminder_check_card.dart';
import '../../widgets/shared/warning_line.dart';

class CaregiverSettingsScreen extends StatefulWidget {
  const CaregiverSettingsScreen({super.key});

  @override
  State<CaregiverSettingsScreen> createState() =>
      _CaregiverSettingsScreenState();
}

class _CaregiverSettingsScreenState extends State<CaregiverSettingsScreen> {
  Future<void> _editProfile() async {
    if (context.read<AuthProvider>().currentUserModel == null) return;
    // The dialog saves and reports its own errors, so only success comes back.
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _EditProfileDialog(),
    );
    if (saved == true && mounted) {
      SnackbarHelper.showSuccess(context, 'Profile updated.');
    }
  }

  Future<void> _deleteAccount() async {
    // The dialog deletes and reports its own errors, so only success comes back.
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (deleted != true || !mounted) return;
    // AuthGate renders WelcomeScreen once the account is gone; replacing the
    // root here would leave later sign-ins with nothing to route them.
    Navigator.of(context).popUntil((route) => route.isFirst);
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
                          user?.fullName ?? 'Care Partner',
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
            const ReminderCheckCard(forCaregiverAlerts: true),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _ToggleRow(
                  label: 'Missed dose alerts',
                  subtitle: 'Running late, missed and skipped doses, and doses logged late',
                  value: caregiver.profile?.alertPrefMissed ?? true,
                  onChanged: (value) =>
                      caregiver.updateAlertPreferences(alertPrefMissed: value),
                ),
                const Divider(height: 1, color: AppColors.borderGray),
                _ToggleRow(
                  label: 'Low stock alerts',
                  subtitle: 'Notify me when a compartment is running low',
                  value: caregiver.profile?.alertPrefLowStock ?? true,
                  onChanged: (value) =>
                      caregiver.updateAlertPreferences(alertPrefLowStock: value),
                ),
                // No "Daily summary" switch: nothing sends one, so it could
                // only ever look like it worked. Reports covers the recap.
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
            const _SectionLabel('LEGAL'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _ActionRow(
                  icon: Icons.description_outlined,
                  label: 'Terms of Service',
                  subtitle: 'The rules for using HealthSync',
                  onTap: () => openLegalPage(context, privacy: false),
                ),
                const Divider(height: 1, color: AppColors.borderGray),
                _ActionRow(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  subtitle: 'What we collect and how it is used',
                  onTap: () => openLegalPage(context, privacy: true),
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
                    final confirmed = await showConfirmDialog(
                      context,
                      title: 'Sign out?',
                      message: 'Are you sure you want to sign out of '
                          'HealthSync? Alerts about your patients will stop '
                          'on this phone until you sign in again.',
                      confirmLabel: 'Sign out',
                    );
                    if (!confirmed || !context.mounted) return;
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

/// Owns its controllers so they outlive the dialog's closing animation.
/// Disposing them right after `showDialog` returns crashed with
/// `_dependents.isEmpty` while the fields were still mounted.
/// Spells out everything a caregiver's account deletion takes with it, and
/// asks for the password before doing it.
///
/// The old dialog said only "deactivates your account". Deleting a caregiver
/// now deletes every patient they manage too, and a caregiver must not find
/// that out afterwards.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _understood = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  bool get _canDelete =>
      !_deleting && _understood && _password.text.isNotEmpty;

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final success = await auth.deleteAccount(password: _password.text);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _deleting = false;
        _error = auth.errorMessage ?? 'Account deletion failed. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientUids = context
        .watch<CaregiverProvider>()
        .patientLinks
        .where((link) => link.isActive)
        .map((link) => link.patientRef)
        .toSet()
        .toList();
    final count = patientUids.length;

    return AlertDialog(
      title: const Text('Delete your account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.missedRedBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WarningLine(
                    count == 0
                        ? 'Any patient accounts you created will be permanently deleted.'
                        : 'Your ${count == 1 ? 'patient\'s account' : '$count patients\' accounts'} '
                            'will be permanently deleted:',
                  ),
                  for (final uid in patientUids) _PatientNameLine(uid),
                  const WarningLine(
                    'All medication schedules, reminders, dose history and '
                    'alerts, yours and your patients\', will be erased.',
                  ),
                  const WarningLine(
                    'Your patients\' phones will be signed out and stop '
                    'reminding them. Paired medicine boxes are unlinked and '
                    'unused patient codes stop working.',
                  ),
                  const WarningLine(
                    'This cannot be undone. Nothing can be recovered.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              enabled: !_deleting,
              obscureText: true,
              decoration:
                  AppStyles.inputDecoration('Enter your password to confirm'),
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              value: _understood,
              onChanged: _deleting
                  ? null
                  : (value) => setState(() => _understood = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.missedRed,
              title: const Text(
                'I understand my patients\' accounts and data will be deleted.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.missedRed,
                  fontSize: 12.5,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canDelete ? _delete : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.missedRed),
          child: _deleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Delete everything'),
        ),
      ],
    );
  }
}

/// One patient's name under the warning, so the caregiver sees exactly who.
class _PatientNameLine extends StatelessWidget {
  final String patientUid;
  const _PatientNameLine(this.patientUid);

  @override
  Widget build(BuildContext context) => StreamBuilder<UserModel?>(
        stream: FirestoreService().streamUser(patientUid),
        builder: (context, snapshot) {
          final name = snapshot.data?.fullName.trim();
          return Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 2),
            child: Text(
              '• ${name == null || name.isEmpty ? 'Patient' : name}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        },
      );
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog();

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _phone;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUserModel;
    _first = TextEditingController(text: user?.firstName ?? '');
    _last = TextEditingController(text: user?.lastName ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final success = await auth.updateProfile(
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      phone: _phone.text.trim(),
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = auth.errorMessage ?? 'Profile update failed. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _first,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              decoration: AppStyles.inputDecoration('First name'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _last,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              decoration: AppStyles.inputDecoration('Last name'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              enabled: !_saving,
              decoration: AppStyles.inputDecoration('Phone number'),
              keyboardType: TextInputType.phone,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.missedRed,
                  fontSize: 12.5,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.caregiverGreen,
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
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
