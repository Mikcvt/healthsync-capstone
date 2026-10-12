import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Talks to MainActivity for the reminder-reliability hint
/// (DOSE_LOGIC_PROPOSAL.md, 5.2 step 3).
///
/// Xiaomi, Oppo, Vivo and their sub-brands ship battery savers that can stop
/// scheduled reminders from firing at all unless the app is allowed to run in
/// the background — a bigger risk than how the reminder looks.
class DeviceSettingsService {
  static final DeviceSettingsService _instance = DeviceSettingsService._();
  factory DeviceSettingsService() => _instance;
  DeviceSettingsService._();

  static const MethodChannel _channel = MethodChannel('healthsync/device');

  static const List<String> _aggressiveBrands = [
    'xiaomi',
    'redmi',
    'poco',
    'oppo',
    'realme',
    'oneplus',
    'vivo',
    'iqoo',
  ];

  String? _manufacturer;

  Future<String> manufacturer() async {
    if (_manufacturer != null) return _manufacturer!;
    try {
      _manufacturer =
          (await _channel.invokeMethod<String>('getManufacturer') ?? '')
              .toLowerCase();
    } catch (e) {
      debugPrint('DeviceSettingsService.manufacturer failed: $e');
      _manufacturer = '';
    }
    return _manufacturer!;
  }

  /// Whether this phone's brand is known to stop background reminders.
  Future<bool> needsBackgroundHint() async {
    final brand = await manufacturer();
    return _aggressiveBrands.any(brand.contains);
  }

  /// Opens the brand's "run in background" screen, or this app's settings.
  Future<bool> openBackgroundSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openBackgroundSettings') ??
          false;
    } catch (e) {
      debugPrint('DeviceSettingsService.openBackgroundSettings failed: $e');
      return false;
    }
  }

  /// Whether battery optimisation is off for HealthSync. Unknown counts as
  /// fine, so a failed check never nags the user.
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          true;
    } catch (e) {
      debugPrint('DeviceSettingsService.isIgnoringBatteryOptimizations: $e');
      return true;
    }
  }

  /// Opens the system list for turning battery optimisation off.
  Future<bool> openBatteryOptimizationSettings() => _invoke(
        'openBatteryOptimizationSettings',
      );

  /// Opens this app's system settings page.
  Future<bool> openAppSettings() => _invoke('openAppSettings');

  Future<bool> _invoke(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } catch (e) {
      debugPrint('DeviceSettingsService.$method failed: $e');
      return false;
    }
  }
}
