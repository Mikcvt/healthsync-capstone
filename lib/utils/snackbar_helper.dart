import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// One place for user-facing messages, per the project's error-handling
/// standard. Screens should never build a raw SnackBar.
class SnackbarHelper {
  const SnackbarHelper._();

  static void _show(
    BuildContext context, {
    required String message,
    required Color background,
    required IconData icon,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    // Replace rather than queue: stacked snackbars make a failed action look
    // like several failures.
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'PlusJakartaSans',
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static void showError(BuildContext context, String message) => _show(
        context,
        message: message,
        background: AppColors.missedRed,
        icon: Icons.error_outline_rounded,
      );

  static void showSuccess(BuildContext context, String message) => _show(
        context,
        message: message,
        background: AppColors.takenGreen,
        icon: Icons.check_circle_outline_rounded,
      );

  static void showInfo(BuildContext context, String message) => _show(
        context,
        message: message,
        background: AppColors.textPrimary,
        icon: Icons.info_outline_rounded,
      );

  static void showWarning(BuildContext context, String message) => _show(
        context,
        message: message,
        background: AppColors.pendingAmber,
        icon: Icons.warning_amber_rounded,
      );
}
