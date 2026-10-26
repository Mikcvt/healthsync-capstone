import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../utils/phone_format.dart';
import '../../utils/validators.dart';

/// The one phone field used everywhere (BUG-016/017): a fixed `+63` in front,
/// digits only, at most 10, spaced as typed.
///
/// Fill [controller] with [PhPhone.forField] and save with [PhPhone.toStored].
/// Pass [hadUnreadable] when the saved number could not be read, so the user
/// is told why the field is empty.
class PhPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isRequired;
  final bool enabled;
  final bool hadUnreadable;
  final String? helper;
  final Color accent;

  const PhPhoneField({
    super.key,
    required this.controller,
    this.label = 'Phone number',
    this.isRequired = false,
    this.enabled = true,
    this.hadUnreadable = false,
    this.helper,
    this.accent = AppColors.patientBlue,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      inputFormatters: [PhPhoneInputFormatter()],
      validator: (v) => Validators.phPhone(v, isRequired: isRequired),
      decoration: AppStyles.inputDecoration(
        isRequired ? label : '$label (optional)',
        accent: accent,
      ).copyWith(
        // A prefix icon, not prefixText: prefixText is hidden until the
        // field is focused, and the tester expected +63 to be visible.
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 14, right: 6),
          child: Text(
            PhPhone.prefix,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFamily: AppStyles.fontFamily,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        helperText: hadUnreadable
            ? 'Your saved number was not valid. Re-enter it.'
            : helper,
        helperMaxLines: 2,
        helperStyle: TextStyle(
          fontSize: 12,
          color: hadUnreadable ? AppColors.pendingAmber : AppColors.textMuted,
          fontFamily: AppStyles.fontFamily,
        ),
      ),
    );
  }
}
