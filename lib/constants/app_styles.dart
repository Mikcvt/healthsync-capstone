import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppStyles {
  /// The bundled family declared in `pubspec.yaml`. Bundled rather than fetched
  /// through `google_fonts` so the app renders correctly on first launch and
  /// offline, per coding standard 7.
  static const String fontFamily = 'PlusJakartaSans';

  // Card decoration
  static BoxDecoration cardDecoration = BoxDecoration(
    color: AppColors.cardWhite,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.borderGray, width: 1),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF1B5FD4).withValues(alpha: 0.06),
        blurRadius: 12,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // Gradient box decoration
  static BoxDecoration gradientDecoration = BoxDecoration(
    gradient: AppColors.primaryGradient,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF1B5FD4).withValues(alpha: 0.28),
        blurRadius: 20,
        offset: const Offset(0, 6),
      ),
    ],
  );

  // Input field decoration
  static InputDecoration inputDecoration(
    String label, {
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.background,
      labelStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderGray),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.patientBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.missedRed),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // Text styles
  static TextStyle heading1 = const TextStyle(
    fontFamily: AppStyles.fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );
  static TextStyle heading2 = const TextStyle(
    fontFamily: AppStyles.fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );
  static TextStyle heading3 = const TextStyle(
    fontFamily: AppStyles.fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static TextStyle bodyLarge = const TextStyle(
    fontFamily: AppStyles.fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  static TextStyle bodySmall = const TextStyle(
    fontFamily: AppStyles.fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static TextStyle caption = const TextStyle(
    fontFamily: AppStyles.fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    letterSpacing: 0.08,
  );
}
