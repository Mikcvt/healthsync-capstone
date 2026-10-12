import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// A yes/no confirmation for an action that cannot be taken back with a tap,
/// such as signing out. Resolves to true only when the confirm button is
/// pressed; dismissing the dialog counts as no.
///
/// Permanent deletes do not use this: they need the password and an
/// "I understand" checkbox (DeletePatientDialog, the account delete dialog).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      content: Text(
        message,
        style: const TextStyle(height: 1.5, color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(
            backgroundColor:
                destructive ? AppColors.missedRed : AppColors.caregiverGreen,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}
