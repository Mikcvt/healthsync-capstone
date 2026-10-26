import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/auth_provider.dart';
import '../caregiver/caregiver_welcome_screen.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/validators.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _pollTimer;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  /// True only while a check the user tapped for is running. The 4-second
  /// background check is silent: it used to share this flag, so the button
  /// flashed a spinner on its own, and stayed on one on a slow network.
  bool _isManualCheck = false;

  /// The check now running, tapped or background, so two never overlap.
  Future<void>? _inFlight;

  /// Set once the screen moves on, so a check that finishes late does not
  /// navigate a second time.
  bool _leaving = false;

  /// A corrected address awaiting confirmation, shown instead of the old one.
  String? _pendingEmail;

  /// Whether the secondary options (resend, change email, other account) are
  /// shown. Closed at first so the main button stands alone.
  bool _showMoreOptions = false;

  bool get _moreOptionsOpen => _showMoreOptions || _resendSeconds > 0;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkVerification(showErrors: false);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  /// Signs out and returns to the welcome screen.
  ///
  /// Signing out alone looked like a dead button: Register and Login push this
  /// screen on top of AuthGate, so AuthGate switched to WelcomeScreen
  /// underneath while this screen stayed in front. Popping back to the first
  /// route reveals it. When AuthGate itself shows this screen, there is
  /// nothing to pop and AuthGate rebuilds on its own.
  Future<void> _useDifferentAccount() async {
    _leaving = true;
    _pollTimer?.cancel();
    _resendTimer?.cancel();
    final navigator = Navigator.of(context);
    await context.read<AuthProvider>().signOut();
    if (!mounted) return;
    navigator.popUntil((route) => route.isFirst);
  }

  /// For a caregiver who registered with a mistyped address: sends the link
  /// to the corrected one. Opening it changes and verifies the email at once,
  /// and the 4-second check above then moves on by itself.
  Future<void> _changeEmail() async {
    final newEmail = await showDialog<String>(
      context: context,
      builder: (_) => const _ChangeEmailDialog(),
    );
    if (newEmail == null || !mounted) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.changeEmailBeforeVerification(newEmail);
    if (!mounted) return;
    if (ok) {
      setState(() => _pendingEmail = newEmail);
      SnackbarHelper.showSuccess(
        context,
        'We sent a link to $newEmail. Open it to confirm your new email.',
      );
    } else {
      SnackbarHelper.showError(
        context,
        auth.errorMessage ?? 'Could not change your email. Try again.',
      );
    }
  }

  /// [showErrors] is true for a tap on the button and false for the
  /// background check. Only a tap shows the spinner and the messages.
  Future<void> _checkVerification({required bool showErrors}) async {
    if (_leaving) return;
    if (!showErrors) {
      if (_inFlight != null) return;
      await _track(_runCheck(showErrors: false));
      return;
    }

    if (_isManualCheck) return;
    setState(() => _isManualCheck = true);
    try {
      // A background check may be running: let it finish, then check once
      // more so the tap gets its own answer.
      final running = _inFlight;
      if (running != null) await running;
      if (!mounted || _leaving) return;
      await _track(_runCheck(showErrors: true));
    } finally {
      if (mounted) setState(() => _isManualCheck = false);
    }
  }

  Future<void> _track(Future<void> check) async {
    _inFlight = check;
    try {
      await check;
    } finally {
      if (identical(_inFlight, check)) _inFlight = null;
    }
  }

  Future<void> _runCheck({required bool showErrors}) async {
    try {
      final navigator = Navigator.of(context);
      // A stuck reload must not hold the button: give up after 10 s.
      final verified = await context
          .read<AuthProvider>()
          .reloadAndCheckEmailVerification()
          .timeout(const Duration(seconds: 10));
      if (!mounted || _leaving) return;
      if (verified == null) {
        // Confirming a changed email ended this session: sign in again with
        // the new address, from the welcome screen.
        _leaving = true;
        _pollTimer?.cancel();
        _resendTimer?.cancel();
        _showMessage('Your email was changed. Sign in with your new email address.');
        navigator.popUntil((route) => route.isFirst);
        return;
      }
      if (verified) {
        _leaving = true;
        _pollTimer?.cancel();
        _continueToOnboarding();
      } else if (showErrors) {
        _showMessage('Email is not verified yet. Open the link in your inbox first.');
      }
    } catch (_) {
      if (showErrors && mounted) {
        _showMessage('We could not check verification status. Please try again.');
      }
    }
  }

  Future<void> _resendVerification() async {
    if (_resendSeconds > 0) return;
    final authProvider = context.read<AuthProvider>();
    final sent = await authProvider.sendEmailVerification();
    if (!mounted) return;
    if (!sent) {
      _showMessage(authProvider.errorMessage ?? 'Could not send the verification email.');
      return;
    }
    setState(() => _resendSeconds = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
    _showMessage('Verification email sent. Check your inbox and spam folder.');
  }

  // Only caregivers self-register, so only caregivers ever verify an email.
  void _continueToOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CaregiverWelcomeScreen()),
    );
  }

  void _showMessage(String message) =>
      SnackbarHelper.showInfo(context, message);

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final email = _pendingEmail ??
        authProvider.currentUserModel?.email ??
        'your email address';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.ledDoneBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.mark_email_read_outlined, color: AppColors.caregiverGreen, size: 44),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verify your email',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'PlusJakartaSans'),
                ),
                const SizedBox(height: 10),
                Text(
                  'We sent a verification link to $email. Open it, then return here to continue.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'PlusJakartaSans', height: 1.6),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isManualCheck ? null : () => _checkVerification(showErrors: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.patientBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isManualCheck
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('I verified my email'),
                  ),
                ),
                // One quiet toggle instead of three links competing with the
                // main button. It stays open while a resend countdown runs,
                // so the countdown is not hidden.
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _showMoreOptions = !_showMoreOptions),
                  iconAlignment: IconAlignment.end,
                  icon: AnimatedRotation(
                    turns: _moreOptionsOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more_rounded),
                  ),
                  label: const Text("Didn't get it? More options"),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: !_moreOptionsOpen
                      ? const SizedBox(width: double.infinity)
                      : Column(
                          children: [
                            TextButton(
                              onPressed: _resendSeconds == 0 ? _resendVerification : null,
                              child: Text(_resendSeconds == 0 ? 'Resend verification email' : 'Resend in ${_resendSeconds}s'),
                            ),
                            TextButton(
                              onPressed: _changeEmail,
                              child: const Text('Wrong email? Change it'),
                            ),
                            TextButton(
                              onPressed: _useDifferentAccount,
                              child: const Text('Use a different account'),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChangeEmailDialog extends StatefulWidget {
  const _ChangeEmailDialog();

  @override
  State<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<_ChangeEmailDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _email.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Change your email',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'We will send a new verification link to this address. Your '
                'email changes when you open it.',
                style: TextStyle(height: 1.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: AppStyles.inputDecoration('New email address'),
                validator: Validators.email,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.caregiverGreen,
            ),
            child: const Text('Send link'),
          ),
        ],
      );
}
