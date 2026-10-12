// Generated from android/app/google-services.json (project healthsyncapp-b546b).
// HealthSync is Android-only, so no other platform is configured. Re-run
// `flutterfire configure --project=healthsyncapp-b546b` to regenerate.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError(
      'HealthSync is configured for Android only.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBMS57vUtwsph0L9tJVkzYR16AOK5NgS-k',
    appId: '1:325518833196:android:85d7979ff767d03184c389',
    messagingSenderId: '325518833196',
    projectId: 'healthsyncapp-b546b',
    storageBucket: 'healthsyncapp-b546b.firebasestorage.app',
  );
}
