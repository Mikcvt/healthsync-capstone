/// User-facing copy that appears in more than one place, plus every empty-state
/// message.
///
/// Screen-specific headings stay in their screen. What lives here is anything a
/// patient or caregiver might see twice and expect to read the same way, and the
/// empty states — a zero-medication patient should never meet a blank panel.
class AppStrings {
  const AppStrings._();

  // Identity
  static const String appName = 'HealthSync';

  // Legal pages (Cloudflare Pages). The permanent address, not a per-deploy
  // preview hash, so later policy edits show up and the links match the
  // privacy policy URL given to Play Console.
  static const String termsUrl = 'https://healthsync-site.pages.dev/terms/';
  static const String privacyUrl = 'https://healthsync-site.pages.dev/privacy/';
  static const String appTagline = 'Stay on top of every dose';

  // Empty states — patient
  static const String noMedications =
      'No medications yet. Your care partner will add them for you.';
  static const String noSchedulesToday = 'Nothing scheduled for today.';
  static const String noDoseHistory =
      'No dose history yet. Your record builds as you confirm doses.';
  static const String noNotifications = 'No alerts yet.';
  static const String noDevicePaired =
      'That is fine. HealthSync reminds you on this phone at every dose '
      'time, and you confirm each dose here. When you get a HealthSync box, '
      'pair it and your care partner will choose a compartment for each medicine.';
  static const String noAnalyticsYet =
      'Adherence appears here once you have confirmed or missed a dose.';

  // Empty states — caregiver
  static const String noPatients =
      'No patients yet. Add one to start building their schedule.';
  static const String noPatientSelected = 'Select a patient to see their details.';
  static const String noAlerts = 'No alerts. Everything is on track.';
  static const String noReportData =
      'No dose logs are available for this period.';
  static const String noPatientSchedule =
      'No medications scheduled for this patient yet.';

  // Dose loop
  static const String doseTaken = 'Dose confirmed.';
  static const String doseSnoozed = 'Reminder set for 10 minutes from now.';
  static const String doseSnoozeLimit =
      'That was your third snooze, so this dose is marked missed.';
  static const String doseMissed = 'Dose marked as missed.';
  static const String doseAlreadyTaken = 'This dose is already confirmed.';
  static const String savedOfflineSuffix = '(saved offline, will sync)';
  static const String offlineBanner = "You're offline. Doses you log are "
      'saved on this phone and sync when you are back online.';
  static const String waitingToSync = 'Waiting to sync';
  static const String doseConfirmFailed =
      'Could not record this dose. Please try again.';
  static String snoozeActiveUntil(String time) =>
      'Snooze active — reminding at $time.';
  static const String doseAlreadyResolved =
      'This dose has already been recorded.';
  static const String snoozeNotAvailable =
      'Snooze is only available once the dose is due.';
  static const String doseUndone = 'Undone.';
  static const String undoFailed = 'Could not undo. Please try again.';
  static String doseTakenUndo(String name) => '$name marked as taken.';
  static String doseSkippedUndo(String name) => '$name skipped.';

  // Early logging (DOSE_LOGIC_PROPOSAL.md, 3.2 and 3.3)
  static const String loggingEarlyTitle = 'Logging early';
  static String loggingEarlyBody(String time, String span) =>
      'This dose is due at $time (in $span). Are you taking it now?';
  static String skippingEarlyBody(String time, String span) =>
      'This dose is due at $time (in $span). Are you skipping it now?';
  static const String tooEarlyTitle = 'Too early';
  static String tooEarlyBody(String time) =>
      'Too early to log this dose. You can log it from $time.';
  static String actionsUnlockAt(String time) => 'Actions unlock at $time';

  // Missed-dose reasons (7.2). The first is only offered for a missed dose,
  // and only until the end of the next day.
  static const String reasonTookButForgot = 'I took it but forgot to log it';
  static const String reasonOther = 'Other reason';
  static const List<String> doseReasons = [
    'Forgot to take',
    'Felt sick / side effects',
    'Was away from the medicine',
    'Prescription ran out',
    reasonOther,
  ];
  static const String retroWindowClosed =
      'It is too late to change this dose. Missed doses can only be corrected '
      'until the end of the next day.';
  static const String retroTimeInFuture =
      'Choose a time that has already passed.';

  // Permissions — a managed patient is read-only by design, so this is a
  // normal state to explain rather than an error to apologise for.
  static const String readOnlyMedications =
      'Only your care partner can change your medications.';

  // Connectivity
  static const String offlineGeneric =
      'You appear to be offline. Changes will sync when you reconnect.';
  static const String networkError =
      'Could not reach HealthSync. Check your internet connection.';
  static const String genericError = 'Something went wrong. Please try again.';

  // Device
  static const String devicePaired = 'Medicine box paired.';
  static const String devicePairFailed =
      'Could not pair that box. Check the serial number and try again.';
  static const String devicePairedElsewhere =
      'This box is already paired to another account. A box can belong to '
      'one patient only.';
  static const String deviceOnline = 'Online';
  static const String deviceOffline = 'Offline';

  // Medicine box over Bluetooth (BLE_CONNECT_ON_DEMAND.md)
  static const String boxUnsupported =
      'This phone does not support Bluetooth Low Energy, so it cannot connect '
      'to the box. Reminders still work on this phone.';
  static const String boxBluetoothOff =
      'Bluetooth is off. Turn it on to connect to your box.';
  static const String boxPermissionDenied =
      'HealthSync needs the Nearby devices permission to find your box. Allow '
      'it in Settings, then try again. (On Android 11 or older, allow '
      'Location and turn Location on.)';
  static const String boxNotFound =
      'Box not found. Make sure it is switched on and within a few metres of '
      'this phone.';
  static const String boxPairingFailed =
      'Pairing did not finish. Hold the box button for 5 seconds until the '
      'lights run, then try again and type the 6-digit code from the label '
      'within 30 seconds.';
  static const String boxNotPaired =
      'This phone is no longer paired with the box. Pair the box again: hold '
      'its button for 5 seconds, then tap Pair again.';
  static const String boxConnectionLost =
      'The box stopped answering. Move closer and try again.';
  static const String boxProtocolError =
      'The box answered in a way this app does not understand. Its firmware '
      'may need an update.';
  static String boxWrongSerial(String paired, String account) =>
      'This phone is paired with box $paired, but your account now uses box '
      '$account. Pair this phone with $account.';
  static const String boxPairNeedsInternet =
      'Paired with the box, but could not save it to your account. Check your '
      'internet connection and try again.';
  static const String boxClockMissing =
      "The box's clock is not working, so it cannot light or ring at dose "
      'times. Check the DS3231 clock wiring (SDA to GPIO 21, SCL to GPIO 22). '
      'Reminders on this phone still work.';
  static const String boxStale =
      'The box has not answered for over a day. Check that it is charged and '
      'switched on, keep this phone near it, then tap Sync with box. Reminders '
      'on this phone still work.';
  static const String boxStaleCaregiver =
      "The patient's box has not synced for over a day. It may need charging, "
      'or the patient may not have opened the app near it.';
  static const String boxSynced = 'Box synced.';
  static String boxSyncedWithPresses(int count) => count == 1
      ? 'Box synced. 1 dose taken with the box button was saved.'
      : 'Box synced. $count doses taken with the box button were saved.';
  static String boxTooManyDoseTimes(int leftOut) =>
      'The box holds 24 dose times; $leftOut more are reminded on this '
      'phone only.';

  // OTP
  static const String otpInvalid = 'That code is not valid. Check it and try again.';
  static const String otpUsed =
      'That code has already been used. Ask your care partner for a new one.';
  static const String otpExpired =
      'That code has expired. Ask your care partner for a new one.';
  static const String otpRateLimited =
      'Too many attempts. Please wait a few minutes and try again.';
}

/// Route name shared by every screen in the add-medicine wizard.
///
/// The success screen pops until it leaves routes carrying this name, so
/// finishing returns to whatever launched the flow — the caregiver's medicine
/// list or the patient's dashboard — instead of an intermediate step.
const String addMedicineFlowRoute = 'add_medicine_flow';
