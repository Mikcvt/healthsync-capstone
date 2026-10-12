import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/caregiver_provider.dart';
import '../shared/warning_line.dart';

/// Confirms and carries out the permanent deletion of one patient.
///
/// Shared by "Remove patient" and by approving the patient's own deletion
/// request, which used to delete on a single tap with no confirmation at all.
/// Pops true once the patient is deleted; failures are shown in the dialog.
class DeletePatientDialog extends StatefulWidget {
  final String patientUid;
  final String patientName;

  /// The patient asked for this, so the wording says so.
  final bool requestedByPatient;

  const DeletePatientDialog({
    super.key,
    required this.patientUid,
    required this.patientName,
    this.requestedByPatient = false,
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
      title: Text(
        widget.requestedByPatient
            ? 'Approve $name\'s request?'
            : 'Delete $name permanently?',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.requestedByPatient)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '$name asked for their account to be deleted. Approving '
                  'deletes it now.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.missedRedBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WarningLine('$name\'s account will be permanently deleted.'),
                  const WarningLine(
                    'All their medicines, schedules, reminders, dose history '
                    'and alerts will be erased, including adherence reports.',
                  ),
                  const WarningLine(
                    'Their phone will be signed out and stop reminding them. '
                    'Their medicine box is unlinked and their codes stop '
                    'working.',
                  ),
                  const WarningLine(
                    'This cannot be undone. If they only finished their '
                    'medicines, use "Mark treatment complete" instead to keep '
                    'their history.',
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
              : const Text('Delete permanently'),
        ),
      ],
    );
  }
}
