// Generated from android/app/src/dev/google-services.json (project
// healthsyncapp-dev, the DEV environment). Used only by the `dev` flavor; see
// lib/config/environment.dart. The Play app uses firebase_options.dart.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DevFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError(
      'HealthSync is configured for Android only.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC-ej6DQiH-htWiWL-2JLU_OVbw5Ga3HVQ',
    appId: '1:969565387954:android:d91691f6d299183f6a5dab',
    messagingSenderId: '969565387954',
    projectId: 'healthsyncapp-dev',
    storageBucket: 'healthsyncapp-dev.firebasestorage.app',
  );
}
