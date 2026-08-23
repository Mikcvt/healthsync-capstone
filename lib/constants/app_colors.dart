import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color patientBlue = Color(0xFF1B5FD4);
  static const Color caregiverGreen = Color(0xFF0D9B6B);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B5FD4), Color(0xFF0D9B6B)],
  );

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B5FD4), Color(0xFF2D7BF5)],
  );

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D9B6B), Color(0xFF2DBF8A)],
  );

  // Status colors
  static const Color takenGreen = Color(0xFF3B6D11);
  static const Color takenGreenBg = Color(0xFFEAF3DE);
  static const Color pendingAmber = Color(0xFF854F0B);
  static const Color pendingAmberBg = Color(0xFFFAEEDA);
  static const Color missedRed = Color(0xFF791F1F);
  static const Color missedRedBg = Color(0xFFFCEBEB);
  static const Color upcomingBlue = Color(0xFF0F3E9E);
  static const Color upcomingBlueBg = Color(0xFFEBF1FF);

  // Neutral
  static const Color background = Color(0xFFF5F7FB);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color borderGray = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // LED column status
  static const Color ledActive = Color(0xFFF59E0B);
  static const Color ledActiveBg = Color(0xFFFEF3C7);
  static const Color ledDone = Color(0xFF0D9B6B);
  static const Color ledDoneBg = Color(0xFFE4F7F0);
  static const Color ledPending = Color(0xFFE2E8F0);
  static const Color ledPendingBg = Color(0xFFFAEEDA);
  static const Color ledEmpty = Color(0xFFF1F5F9);
}
