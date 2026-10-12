import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../utils/date_formatter.dart';
import '../../utils/snackbar_helper.dart';

/// What a care partner sees on signing in to an account they deleted, while
/// it can still be restored. Restoring brings back their patients too; the
/// profile stream then routes to the dashboard on its own.
class PendingDeletionScreen extends StatelessWidget {
  const PendingDeletionScreen({super.key});

  Future<void> _restore(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.restoreAccount();
    if (!context.mounted) return;
    ok
        ? SnackbarHelper.showSuccess(context, 'Welcome back. Your account is restored.')
        : SnackbarHelper.showError(
            context, auth.errorMessage ?? 'Could not restore your account.');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final purgeOn = auth.currentUserModel?.deletionScheduledFor;
    final when = purgeOn == null ? 'soon' : 'on ${DateFormatter.toShortDate(purgeOn)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.restore_rounded,
                    size: 56, color: AppColors.caregiverGreen),
                const SizedBox(height: 18),
                const Text(
                  'Your account is being deleted',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'It will be permanently deleted $when, together with the '
                  'patient accounts you manage. Until then you can restore '
                  'everything exactly as it was.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'After restoring, send each patient a new code: their '
                  'phones were signed out.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : () => _restore(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.caregiverGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Restore my account',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: auth.isLoading ? null : auth.signOut,
                  child: const Text('Sign out',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
