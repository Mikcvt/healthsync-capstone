import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Whether this phone has a network connection.
///
/// Used to decide how long a dose action waits for the server (not at all when
/// offline) and to show the offline banner. "Connected" means a network is
/// up, not that the internet answers: on Wi-Fi with no internet, writes simply
/// wait their short time and are then saved for later, like being offline.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;
  ConnectivityService._();

  /// Starts true so a failed check never shows "offline" by mistake.
  final ValueNotifier<bool> online = ValueNotifier<bool>(true);

  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> initialize() async {
    final connectivity = Connectivity();
    try {
      _apply(await connectivity.checkConnectivity());
    } catch (e) {
      debugPrint('ConnectivityService check failed: $e');
    }
    _sub ??= connectivity.onConnectivityChanged.listen(
      _apply,
      onError: (Object e) => debugPrint('ConnectivityService stream: $e'),
    );
  }

  void _apply(List<ConnectivityResult> results) {
    online.value = results.any((r) => r != ConnectivityResult.none);
  }
}
