import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../models/otp_code_model.dart';
import '../../providers/caregiver_provider.dart';
import '../../utils/snackbar_helper.dart';
import 'setup_medications_screen.dart';

/// Shows the one-time code the patient types to open their app.
///
/// Reopening this screen reuses the outstanding code rather than minting a new
/// one — issuing a second would silently invalidate the code the caregiver has
/// already sent, which is a confusing failure for both of them.
class GenerateOtpScreen extends StatefulWidget {
  final String patientUid;
  final String patientName;
  final bool isNewPatient;

  const GenerateOtpScreen({
    super.key,
    required this.patientUid,
    required this.patientName,
    this.isNewPatient = false,
  });

  @override
  State<GenerateOtpScreen> createState() => _GenerateOtpScreenState();
}

class _GenerateOtpScreenState extends State<GenerateOtpScreen> {
  OtpCodeModel? _otp;
  bool _loading = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    // Drives the expiry countdown.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final caregiver = context.read<CaregiverProvider>();
    final otp = await caregiver.getOrCreateOtp(widget.patientUid);
    if (!mounted) return;
    setState(() {
      _otp = otp;
      _loading = false;
    });
    if (otp == null) {
      SnackbarHelper.showError(
        context,
        caregiver.errorMessage ?? 'Could not create a code. Please try again.',
      );
    }
  }

  Future<void> _regenerate() async {
    final current = _otp;
    if (current == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Replace this code?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'PlusJakartaSans',
            fontSize: 18,
          ),
        ),
        content: Text(
          'The code ${current.displayCode} will stop working immediately. '
          'If you already sent it to ${widget.patientName}, they will need the '
          'new one instead.',
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Replace',
              style: TextStyle(color: AppColors.missedRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    final caregiver = context.read<CaregiverProvider>();
    final fresh = await caregiver.regenerateOtp(
      patientUid: widget.patientUid,
      currentCode: current.code,
    );
    if (!mounted) return;
    setState(() {
      if (fresh != null) _otp = fresh;
      _loading = false;
    });
    if (fresh == null) {
      SnackbarHelper.showError(
        context,
        caregiver.errorMessage ?? 'Could not replace the code.',
      );
    }
  }

  void _copy() {
    final otp = _otp;
    if (otp == null) return;
    Clipboard.setData(ClipboardData(text: otp.code));
    SnackbarHelper.showSuccess(context, 'Code copied');
  }

  String _remainingLabel(OtpCodeModel otp) {
    final remaining = otp.timeRemaining;
    if (remaining == Duration.zero) return 'Expired';
    final hours = remaining.inHours;
    if (hours >= 1) {
      return 'Expires in $hours hour${hours == 1 ? '' : 's'}';
    }
    final minutes = remaining.inMinutes;
    return 'Expires in $minutes minute${minutes == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final otp = _otp;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  if (widget.isNewPatient) ...[
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.takenGreenBg,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: AppColors.takenGreen, size: 32),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Text(
                    widget.isNewPatient
                        ? '${widget.patientName} is ready'
                        : 'Code for ${widget.patientName}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Send this code to them by text or email. They enter it on '
                    'the welcome screen — there is nothing else for them to set up.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontFamily: 'PlusJakartaSans',
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 26),

                  if (otp == null)
                    _CouldNotCreate(onRetry: _load)
                  else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.caregiverGreen,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            otp.displayCode,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                              color: AppColors.textPrimary,
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 15,
                                color: otp.isExpired
                                    ? AppColors.missedRed
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _remainingLabel(otp),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: otp.isExpired
                                      ? AppColors.missedRed
                                      : AppColors.textSecondary,
                                  fontFamily: 'PlusJakartaSans',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _copy,
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(
                                  color: AppColors.borderGray, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            label: const Text(
                              'Copy',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _regenerate,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(
                                  color: AppColors.borderGray, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            label: const Text(
                              'New code',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.pendingAmberBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 19, color: AppColors.pendingAmber),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This code opens their medical records. Send it '
                              'directly to them, and only once — it stops '
                              'working after the first use.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.pendingAmber,
                                fontFamily: 'PlusJakartaSans',
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => SetupMedicationsScreen(
                              patientUid: widget.patientUid,
                              patientName: widget.patientName,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.medication_outlined, size: 20),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.caregiverGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      label: Text(
                        widget.isNewPatient
                            ? 'Set up their medicines'
                            : 'Manage medicines',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CouldNotCreate extends StatelessWidget {
  final VoidCallback onRetry;
  const _CouldNotCreate({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppStyles.cardDecoration,
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 36, color: AppColors.missedRed),
          const SizedBox(height: 12),
          const Text(
            'Could not create a code',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check your connection and try again. The patient account was '
            'still created.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontFamily: 'PlusJakartaSans',
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.caregiverGreen,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
