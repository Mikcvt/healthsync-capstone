import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'constants/app_colors.dart';
import 'providers/auth_provider.dart';
import 'providers/patient_provider.dart';
import 'providers/caregiver_provider.dart';
import 'providers/schedule_provider.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/patient/patient_main_screen.dart';
import 'screens/caregiver/caregiver_main_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  runApp(const HealthSyncApp());
}

class HealthSyncApp extends StatelessWidget {
  const HealthSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PatientProvider()),
        ChangeNotifierProvider(create: (_) => CaregiverProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
      ],
      child: MaterialApp(
        title: 'HealthSync',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.patientBlue,
            primary: AppColors.patientBlue,
          ),
          scaffoldBackgroundColor: AppColors.background,
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // If user is authenticated with a profile loaded
    if (authProvider.isAuthenticated) {
      if (!authProvider.isEmailVerified) {
        return const EmailVerificationScreen();
      }
      final user = authProvider.currentUserModel;
      if (user != null) {
        if (user.isCaregiver) {
          // Initialize CaregiverProvider with uid
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<CaregiverProvider>().initForCaregiver(user.uid);
          });
          return const CaregiverMainScreen();
        } else {
          // Initialize PatientProvider with uid
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<PatientProvider>().initForPatient(user.uid);
          });
          return const PatientMainScreen();
        }
      }
    }

    // Default to Welcome Screen
    return const WelcomeScreen();
  }
}
