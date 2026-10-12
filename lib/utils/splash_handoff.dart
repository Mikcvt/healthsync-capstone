import 'package:flutter/widgets.dart';

/// How the start-up splash hands its mascot over to the welcome screen.
///
/// The splash covers the first screen while it loads. When that screen is the
/// welcome screen, the splash measures the welcome mascot ([welcomeMascotKey])
/// and glides its own mascot into exactly that spot. Until it lands
/// ([covering] turns false) the welcome screen keeps its mascot hidden and
/// holds back its title and buttons, so the two mascots never show at once.
class SplashHandoff {
  SplashHandoff._();

  /// On the welcome screen's mascot.
  static final GlobalKey welcomeMascotKey = GlobalKey(
    debugLabel: 'welcomeMascot',
  );

  /// True while the splash is on top of the first screen.
  static final ValueNotifier<bool> covering = ValueNotifier<bool>(false);
}
