import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthsync/screens/auth/welcome_screen.dart';

void main() {
  runApp(const HealthSyncApp());
}

class HealthSyncApp extends StatelessWidget {
  const HealthSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5FD4)),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}
