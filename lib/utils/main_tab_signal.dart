import 'package:flutter/foundation.dart';

/// Lets a screen opened on top of the tabbed main screen send the user back to
/// the Home tab, e.g. "Done" after adding a medicine, which may have started
/// from the Patients tab. The main screens listen and switch tabs; the caller
/// pops its own routes.
class MainTabSignal {
  MainTabSignal._();

  /// Incremented on every request, so two requests in a row both fire.
  static final ValueNotifier<int> homeRequests = ValueNotifier<int>(0);

  static void goHome() => homeRequests.value++;
}
