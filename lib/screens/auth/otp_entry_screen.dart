import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../utils/snackbar_helper.dart';
import 'otp_success_screen.dart';

/// Where a managed patient starts and finishes signing in.
///
/// There is deliberately no email field, no password field and no "forgot
/// password" link: the code their caregiver sent them *is* the credential.
class OtpEntryScreen extends StatefulWidget {
  const OtpEntryScreen({super.key});

  @override
  State<OtpEntryScreen> createState() => _OtpEntryScreenState();
}

class _OtpEntryScreenState extends State<OtpEntryScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// 'HS' + 6 characters, as issued by OtpCodeModel.generate().
  static const int _codeLength = 8;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Patients here are often older and unfamiliar with the app; open the
    // keyboard for them rather than making them find the field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _code => _controller.text.replaceAll('-', '').toUpperCase();
  bool get _isComplete => _code.length == _codeLength;

  Future<void> _submit() async {
    if (!_isComplete || _submitting) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    final auth = context.read<AuthProvider>();
    final redemption = await auth.signInWithOtp(_code);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (redemption != null) {
      // pushReplacement, NOT pushAndRemoveUntil: AuthGate must stay at the
      // root of the stack. It is what calls PatientProvider.initForPatient,
      // so tearing it down leaves the dashboard subscribed to nothing and the
      // patient sees an empty schedule.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OtpSuccessScreen(patientName: redemption.fullName),
        ),
      );
      return;
    }

    // Each failure means something different to the patient: a typo is worth
    // retrying, an expired or spent code means going back to their caregiver.
    final code = auth.lastOtpErrorCode;
    if (code == 'code_used' || code == 'code_expired') {
      _controller.clear();
      setState(() {});
    }
    SnackbarHelper.showError(
      context,
      auth.errorMessage ?? 'That code did not work. Please try again.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.key_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Enter your code',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your caregiver sent you an 8-character code by text or email. '
                'Enter it below and your medicines will already be set up.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontFamily: 'PlusJakartaSans',
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 30),

              TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !_submitting,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                maxLength: _codeLength,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                  _UpperCaseFormatter(),
                ],
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'HS••••••',
                  hintStyle: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                    color: AppColors.textMuted.withValues(alpha: 0.5),
                    fontFamily: 'PlusJakartaSans',
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.borderGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.patientBlue,
                      width: 1.8,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.borderGray),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isComplete && !_submitting ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.patientBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.borderGray,
                    disabledForegroundColor: AppColors.textMuted,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 22),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.upcomingBlueBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: AppColors.upcomingBlue,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Codes expire 48 hours after your caregiver creates them '
                        'and can only be used once. If yours has stopped working, '
                        'ask them to send a new one.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.upcomingBlue,
                          fontFamily: 'PlusJakartaSans',
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Codes are issued uppercase; accepting lowercase and converting avoids a
/// pointless "invalid code" for someone whose keyboard autocapitalises oddly.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
