import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../config/environment.dart';
import '../constants/app_strings.dart';

/// An Android foreground service that keeps the app running in the
/// background while a box dose is due, so BoxProvider can sync every minute
/// and a press of the box button reaches Firestore without the Sync button.
///
/// Dev builds only (Nov 3, 2026). The service and its permissions are
/// declared in android/app/src/dev/AndroidManifest.xml; the prod manifest
/// strips the plugin's parts, so the Play build has no foreground service and
/// needs no Play Console declaration.
///
/// The service only keeps the process awake and ticks once a minute; the
/// sync itself runs in the app's own isolate, with its Firestore and
/// Bluetooth state.
class BoxWatchService {
  BoxWatchService._();
  static final BoxWatchService instance = BoxWatchService._();

  static const int _serviceId = 4801;
  static const int _tickMs = 60 * 1000;

  bool get isSupported => AppEnvironment.isDev && Platform.isAndroid;

  VoidCallback? _onTick;
  bool _initialised = false;

  /// Before runApp: the tick reaches the app's isolate through this port.
  static void initCommunicationPort() {
    if (instance.isSupported) FlutterForegroundTask.initCommunicationPort();
  }

  void _init() {
    if (_initialised) return;
    _initialised = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'healthsync_box_watch',
        channelName: AppStrings.boxWatchChannelName,
        channelDescription: AppStrings.boxWatchChannelDescription,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(_tickMs),
        allowWakeLock: true,
        // Swiping the app away ends the app's isolate, and with it the sync:
        // the service goes too.
        stopWithTask: true,
      ),
    );
    FlutterForegroundTask.addTaskDataCallback((_) => _onTick?.call());
  }

  /// [onTick] runs in the app's isolate about once a minute while the service
  /// runs. Android only allows the start while the app is on screen or has
  /// just left it.
  Future<bool> start(String text, {required VoidCallback onTick}) async {
    if (!isSupported) return false;
    _init();
    _onTick = onTick;
    if (await FlutterForegroundTask.isRunningService) {
      await update(text);
      return true;
    }
    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.connectedDevice],
      notificationTitle: AppStrings.boxWatchTitle,
      notificationText: text,
      callback: boxWatchCallback,
    );
    if (result is ServiceRequestFailure) {
      debugPrint('Box watch did not start: ${result.error}');
      return false;
    }
    return true;
  }

  Future<void> update(String text) async {
    if (!isSupported || !await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.updateService(notificationText: text);
  }

  Future<void> stop() async {
    _onTick = null;
    if (!isSupported || !await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.stopService();
  }
}

@pragma('vm:entry-point')
void boxWatchCallback() {
  FlutterForegroundTask.setTaskHandler(_BoxWatchTaskHandler());
}

/// Runs in the service's own isolate: it only forwards the minute tick.
class _BoxWatchTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.sendDataToMain('tick');
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }
}
