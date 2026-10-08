import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local preferences, stored with `shared_preferences`.
///
/// These are deliberately **not** in Firestore. They control what this phone
/// does with a reminder — whether it rings, and whether it shows a full-screen
/// alert — so they belong to the device, not the account. A patient with the
/// app on two phones should be able to silence one of them.
///
/// Anything that changes what the *server* does lives in Firestore instead:
/// the caregiver's missed-dose and low-stock alerts are driven by
/// `caregiver_profile`, because the Worker is what sends them and it cannot
/// read a phone's local storage.
class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  static const String _keyDoseReminders = 'pref_dose_reminders';
  static const String _keyReminderSound = 'pref_reminder_sound';
  static const String _keyFullScreenAlert = 'pref_fullscreen_alert';
  static const String _keyBackgroundHintShown = 'pref_background_hint_shown';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Reads every preference in one pass, so a screen can populate its initial
  /// toggle states without a round trip per switch.
  Future<PatientPreferences> load() async {
    try {
      final store = await _store;
      return PatientPreferences(
        doseReminders: store.getBool(_keyDoseReminders) ?? true,
        reminderSound: store.getBool(_keyReminderSound) ?? true,
        fullScreenAlert: store.getBool(_keyFullScreenAlert) ?? true,
      );
    } catch (e) {
      // Storage can be unavailable; defaults are the safe direction to fail —
      // a patient who gets a reminder they did not want is better off than one
      // who silently gets none.
      debugPrint('PreferencesService.load failed: $e');
      return const PatientPreferences();
    }
  }

  Future<void> setDoseReminders(bool value) => _setBool(_keyDoseReminders, value);
  Future<void> setReminderSound(bool value) => _setBool(_keyReminderSound, value);
  Future<void> setFullScreenAlert(bool value) =>
      _setBool(_keyFullScreenAlert, value);

  /// Whether the one-time "let HealthSync run in the background" hint has
  /// been shown on this phone.
  Future<bool> backgroundHintShown() async {
    try {
      final store = await _store;
      return store.getBool(_keyBackgroundHintShown) ?? false;
    } catch (e) {
      debugPrint('PreferencesService.backgroundHintShown failed: $e');
      // Treat as shown: a hint that cannot remember it was shown would
      // appear on every launch.
      return true;
    }
  }

  Future<void> setBackgroundHintShown() =>
      _setBool(_keyBackgroundHintShown, true);

  Future<void> _setBool(String key, bool value) async {
    try {
      final store = await _store;
      await store.setBool(key, value);
    } catch (e) {
      debugPrint('PreferencesService.$key write failed: $e');
    }
  }
}

@immutable
class PatientPreferences {
  /// Whether this phone schedules local dose reminders at all.
  final bool doseReminders;

  /// Whether a reminder makes a sound, as opposed to arriving silently.
  final bool reminderSound;

  /// Whether a due dose opens the full-screen alert rather than only a
  /// notification in the tray.
  final bool fullScreenAlert;

  const PatientPreferences({
    this.doseReminders = true,
    this.reminderSound = true,
    this.fullScreenAlert = true,
  });

  PatientPreferences copyWith({
    bool? doseReminders,
    bool? reminderSound,
    bool? fullScreenAlert,
  }) {
    return PatientPreferences(
      doseReminders: doseReminders ?? this.doseReminders,
      reminderSound: reminderSound ?? this.reminderSound,
      fullScreenAlert: fullScreenAlert ?? this.fullScreenAlert,
    );
  }
}
