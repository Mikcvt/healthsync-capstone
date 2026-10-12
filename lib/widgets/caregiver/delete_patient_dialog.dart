import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/caregiver_provider.dart';
import '../shared/warning_line.dart';

/// Confirms and carries out the deletion of one patient: paused at once,
/// permanently erased after 30 days unless restored from their card.
/// Pops true once the patient is deleted; failures are shown in the dialog.
class DeletePatientDialog extends StatefulWidget {
  final String patientUid;
  final String patientName;

  const DeletePatientDialog({
    super.key,
    required this.patientUid,
    required this.patientName,
  });

  @override
  State<DeletePatientDialog> createState() => _DeletePatientDialogState();
}

class _DeletePatientDialogState extends State<DeletePatientDialog> {
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
    final caregiver = context.read<CaregiverProvider>();
    final ok = await caregiver.deletePatient(
      widget.patientUid,
      password: _password.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _deleting = false;
        _error = caregiver.errorMessage ??
            'Could not delete ${widget.patientName}. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.patientName;
    return AlertDialog(
      title: Text('Delete $name?'),
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
                  const WarningLine(
                    'Their phone is signed out now and stops reminding them. '
                    'Their codes stop working.',
                  ),
                  WarningLine(
                    'After 30 days $name\'s account is permanently deleted, '
                    'with all their medicines, schedules, dose history, '
                    'alerts and adherence reports. Their medicine box is '
                    'unlinked.',
                  ),
                  const WarningLine(
                    'Until then you can restore them from My Patients. If '
                    'they only finished their medicines, use "Mark treatment '
                    'complete" instead to keep their history.',
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
              title: Text(
                'I understand $name\'s account and data will be deleted.',
                style: const TextStyle(fontSize: 13),
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
              : const Text('Delete'),
        ),
      ],
    );
  }
}
