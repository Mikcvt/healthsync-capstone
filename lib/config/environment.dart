import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/services.dart' show appFlavor;

import '../firebase_options.dart';
import '../firebase_options_dev.dart';

/// Which backend this build talks to, from the Android flavor it was built
/// with (`--flavor prod` or `--flavor dev`). The two share nothing: dev
/// changes can never reach the Play app's testers (CLAUDE.md,
/// "Environments").
///
/// Anything that is not explicitly the dev flavor is production, so a build
/// made without a flavor behaves exactly like the Play app always has.
class AppEnvironment {
  const AppEnvironment._();

  static bool get isDev => appFlavor == 'dev';

  static FirebaseOptions get firebaseOptions => isDev
      ? DevFirebaseOptions.currentPlatform
      : DefaultFirebaseOptions.currentPlatform;

  /// The Worker for this environment, unless `--dart-define=API_BASE_URL=...`
  /// overrides it (a local `wrangler dev`, for example).
  static String get workerUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    return isDev
        ? 'https://healthsync-api-dev.healthsync12.workers.dev'
        : 'https://healthsync-api.healthsync12.workers.dev';
  }
}
