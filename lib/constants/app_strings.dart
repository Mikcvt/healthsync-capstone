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
  static const String appTagline = 'Never miss a dose';

  // Empty states — patient
  static const String noMedications =
      'No medications yet. Your caregiver will add them for you.';
  static const String noSchedulesToday = 'Nothing scheduled for today.';
  static const String noDoseHistory =
      'No dose history yet. Your record builds as you confirm doses.';
  static const String noNotifications = 'No alerts yet.';
  static const String noDevicePaired =
      'That is fine. HealthSync reminds you on this phone at every dose '
      'time, and you confirm each dose here. When you get a HealthSync box, '
      'pair it and your caregiver will choose a compartment for each medicine.';
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
  static const String doseConfirmFailed =
      'Could not record this dose. Please try again.';
  static const String doseOutOfStock =
      'No pills remaining. Please refill the compartment.';
  static const String outOfStockBadge = 'Out of stock · Refill required';
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
      'Only your caregiver can change your medications.';

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
  static const String deviceOnline = 'Online';
  static const String deviceOffline = 'Offline';

  // OTP
  static const String otpInvalid = 'That code is not valid. Check it and try again.';
  static const String otpUsed =
      'That code has already been used. Ask your caregiver for a new one.';
  static const String otpExpired =
      'That code has expired. Ask your caregiver for a new one.';
  static const String otpRateLimited =
      'Too many attempts. Please wait a few minutes and try again.';
}

/// Route name shared by every screen in the add-medicine wizard.
///
/// The success screen pops until it leaves routes carrying this name, so
/// finishing returns to whatever launched the flow — the caregiver's medicine
/// list or the patient's dashboard — instead of an intermediate step.
const String addMedicineFlowRoute = 'add_medicine_flow';
