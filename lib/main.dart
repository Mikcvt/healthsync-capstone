import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'config/environment.dart';
import 'constants/app_colors.dart';
import 'constants/app_styles.dart';
import 'providers/auth_provider.dart';
import 'providers/box_provider.dart';
import 'providers/patient_provider.dart';
import 'providers/caregiver_provider.dart';
import 'providers/schedule_provider.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/pending_deletion_screen.dart';
import 'screens/patient/patient_main_screen.dart';
import 'screens/caregiver/caregiver_main_screen.dart';
import 'services/connectivity_service.dart';
import 'services/dose_reminder_scheduler.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: AppEnvironment.firebaseOptions,
    );
    // Before any screen: dose actions decide from this whether to wait for the
    // server.
    await ConnectivityService().initialize();
    await NotificationService().initialize();
    // Load the timezone database before any screen can schedule a dose.
    await DoseReminderScheduler().initialize();
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
        // The patient's Bluetooth link to their box; built on PatientProvider.
        ChangeNotifierProvider(
          create: (context) => BoxProvider(context.read<PatientProvider>()),
        ),
        ChangeNotifierProvider(create: (_) => CaregiverProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
      ],
      child: MaterialApp(
        title: 'HealthSync',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: AppStyles.fontFamily,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.patientBlue,
            primary: AppColors.patientBlue,
          ),
          scaffoldBackgroundColor: AppColors.background,
          useMaterial3: true,
        ),
        // The phone's font size still applies, up to [maxTextScale]. Past
        // that, fixed-height buttons and the compartment grid cut text off
        // (BUG-026); the welcome screen did at the largest setting.
        builder: (context, child) {
          final app = MediaQuery.withClampedTextScaling(
            maxScaleFactor: maxTextScale,
            child: child!,
          );
          // A dev build talks to the dev project; the corner banner keeps it
          // from being mistaken for the Play app.
          return AppEnvironment.isDev
              ? Banner(
                  message: 'DEV',
                  location: BannerLocation.topEnd,
                  child: app,
                )
              : app;
        },
        home: const AuthGate(),
      ),
    );
  }

  /// Raise only after retesting every screen at the new size.
  static const maxTextScale = 1.3;
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().status;
    final loading =
        status == AuthStatus.checking || status == AuthStatus.loadingProfile;

    // At launch the animated splash covers this while it loads, and hands
    // over to whatever it resolves to (see StartupSplash).
    return StartupSplash(
      ready: !loading,
      toWelcome: status == AuthStatus.signedOut,
      child: _route(context),
    );
  }

  Widget _route(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    switch (authProvider.status) {
      // Firebase restores a session asynchronously, so the first frame knows
      // nothing yet. Showing WelcomeScreen here made the login flow flash on
      // every launch, and stranded a signed-in user there when offline.
      case AuthStatus.checking:
      case AuthStatus.loadingProfile:
        return const _LoadingScreen();

      case AuthStatus.signedOut:
        return const WelcomeScreen();

      case AuthStatus.profileMissing:
        return const _ProfileUnavailableScreen();

      case AuthStatus.pendingDeletion:
        return const PendingDeletionScreen();

      case AuthStatus.ready:
        final user = authProvider.currentUserModel!;

        // Managed patients have no real email address — their account was
        // created by a caregiver and they signed in with an OTP-minted custom
        // token, so there is nothing to verify and no inbox to check.
        if (user.requiresEmailVerification && !authProvider.isEmailVerified) {
          return const EmailVerificationScreen();
        }

        // Routing is driven by account_type, not role, so a document whose
        // role predates the current scheme still lands in the right place.
        if (user.isCaregiver) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<CaregiverProvider>().initForCaregiver(user.uid);
          });
          return const CaregiverMainScreen();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<PatientProvider>().initForPatient(user.uid);
        });
        return const PatientMainScreen();
    }
  }
}

/// Shown while the profile loads after the first time, e.g. right after
/// signing in. At launch the animated StartupSplash covers it instead.
/// Deliberately plain: it is on screen for a few hundred milliseconds.
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication_liquid_rounded,
                size: 56, color: AppColors.patientBlue),
            SizedBox(height: 20),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// A signed-in session whose users/{uid} document could not be read — almost
/// always a dropped connection on a cold start. Offering a retry and a sign-out
/// is the difference between a recoverable state and an app that looks broken.
class _ProfileUnavailableScreen extends StatelessWidget {
  const _ProfileUnavailableScreen();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 52, color: AppColors.textMuted),
              const SizedBox(height: 18),
              const Text(
                'We could not load your profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Check your internet connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: auth.retryProfileLoad,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.patientBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Try again',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: auth.signOut,
                child: const Text('Sign out',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
