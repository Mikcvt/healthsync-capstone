import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_strings.dart';
import '../models/patient_profile_model.dart';
import '../models/patient_medication_model.dart';
import '../models/schedule_model.dart';
import '../models/dose_log_model.dart';
import '../models/device_model.dart';
import '../models/notification_model.dart';
import '../models/caregiver_patient_link_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/dose_reminder_scheduler.dart';
import '../services/firestore_service.dart';
import '../utils/date_formatter.dart';

/// How far back the history stream reaches.
///
/// Bounded deliberately: an unbounded stream re-reads the patient's whole
/// history on every write, and the Spark plan allows 50k reads a day. Every
/// screen in the app asks for 90 days or less.
const Duration _historyWindow = Duration(days: 90);

/// The outcome of a dose action, so the screen can show the right message
/// without having to interpret a bool.
enum DoseActionResult {
  success,

  /// The dose was already confirmed. Not an error — usually a double tap — but
  /// nothing was written, so stock is not decremented twice.
  alreadyConfirmed,

  /// Snoozed past the cap, so the dose was marked missed instead.
  snoozeLimitReached,

  failed,
}

class PatientProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final ApiService _apiService = ApiService();

  String? _patientUid;
  PatientProfileModel? _profile;
  List<PatientMedicationModel> _medications = [];
  List<ScheduleModel> _schedules = [];
  List<DoseLogModel> _allLogs = [];
  List<NotificationModel> _notifications = [];
  DeviceModel? _device;
  CaregiverPatientLinkModel? _link;
  UserModel? _caregiverUser;

  bool _medicationsLoaded = false;
  bool _schedulesLoaded = false;
  bool _logsLoaded = false;
  String? _errorMessage;

  StreamSubscription? _profileSub;
  StreamSubscription? _medicationsSub;
  StreamSubscription? _schedulesSub;
  StreamSubscription? _allLogsSub;
  StreamSubscription? _notificationsSub;
  StreamSubscription? _deviceSub;
  StreamSubscription? _linksSub;

  // ==========================================
  // READS
  // ==========================================

  PatientProfileModel? get profile => _profile;
  List<PatientMedicationModel> get medications => _medications;
  List<NotificationModel> get notifications => _notifications;
  DeviceModel? get device => _device;
  CaregiverPatientLinkModel? get link => _link;
  UserModel? get caregiverUser => _caregiverUser;
  bool get isLinkedToCaregiver => _link != null && _link!.status == 'active';
  bool get isLinkPending => _link != null && _link!.status == 'pending';
  String? get errorMessage => _errorMessage;

  /// True until the three streams the dashboard needs have each emitted once.
  /// The previous flag was set true and false inside the same method body, so
  /// no spinner in the app ever rendered.
  bool get isLoading =>
      _patientUid != null &&
      !(_medicationsLoaded && _schedulesLoaded && _logsLoaded);

  /// Active schedules, earliest time of day first. Dose screens and the box
  /// view both rely on this order.
  List<ScheduleModel> get schedules {
    final sorted = [..._schedules];
    sorted.sort((a, b) => DateFormatter.minutesOfDay(a.scheduledTime)
        .compareTo(DateFormatter.minutesOfDay(b.scheduledTime)));
    return sorted;
  }

  List<DoseLogModel> get allLogs => _allLogs;

  /// Today's logs, derived from the history stream rather than fetched by a
  /// second dated query.
  ///
  /// The old dated stream captured "today" once when the provider initialised,
  /// so an app left open past midnight showed yesterday's doses forever.
  /// Deriving it means the list is correct whenever it is read, and costs one
  /// stream instead of two.
  /// Logs for a schedule that is still part of the regimen.
  ///
  /// `_schedules` only ever holds active ones, so a medicine that was deleted
  /// or finished drops out of here while its past doses stay in [allLogs] for
  /// history and reports. Without this, removing a medicine left its missed
  /// doses on the dashboard forever.
  bool _isLiveSchedule(DoseLogModel log) {
    if (log.scheduleRef.isEmpty) return true;
    return _schedules.any((s) => s.scheduleId == log.scheduleRef);
  }

  /// What the dashboard should still be showing.
  ///
  /// A dose the patient has dealt with — taken, or a miss they have seen —
  /// leaves the list. Keeping everything made the dashboard longer as the day
  /// went on, which is backwards: it should get shorter as things get done.
  List<DoseLogModel> get outstandingTodayLogs => todayLogs
      .where((log) => !log.isTaken && log.acknowledgedAt == null)
      .toList();

  /// Asks the caregiver to delete this account.
  Future<bool> requestAccountDeletion({String reason = ''}) async {
    final uid = _patientUid;
    if (uid == null) return false;
    _errorMessage = null;
    try {
      await _firestoreService.requestAccountDeletion(
        patientUid: uid,
        reason: reason,
      );
      return true;
    } catch (e) {
      debugPrint('requestAccountDeletion failed: $e');
      _errorMessage = AppStrings.genericError;
      notifyListeners();
      return false;
    }
  }

  /// Withdraws the request.
  Future<bool> cancelAccountDeletionRequest() async {
    final uid = _patientUid;
    if (uid == null) return false;
    try {
      await _firestoreService.cancelAccountDeletionRequest(uid);
      return true;
    } catch (e) {
      debugPrint('cancelAccountDeletionRequest failed: $e');
      return false;
    }
  }

  /// Dismisses a missed dose from the dashboard.
  Future<bool> acknowledgeMissedDose(String doseLogId) async {
    _errorMessage = null;
    try {
      await _firestoreService.acknowledgeDoseLog(doseLogId);
      return true;
    } catch (e) {
      debugPrint('acknowledgeMissedDose failed: $e');
      _errorMessage = AppStrings.genericError;
      notifyListeners();
      return false;
    }
  }

  List<DoseLogModel> get todayLogs {
    final today = DateTime.now();
    final key = DateFormatter.toDateKey(today);
    return _allLogs.where((log) {
      if (!_isLiveSchedule(log)) return false;
      if (log.scheduledDate.isNotEmpty) return log.scheduledDate == key;
      final at = log.scheduledAt;
      return at != null && DateFormatter.isSameDay(at, today);
    }).toList();
  }

  int get unreadNotificationCount =>
      _notifications.where((n) => n.readAt == null).length;

  /// Doses still awaiting a decision today, earliest first.
  List<DoseLogModel> get pendingTodayLogs {
    final pending = todayLogs
        .where((log) => log.isPending || log.isSnoozed)
        .toList();
    pending.sort((a, b) => DateFormatter.minutesOfDay(a.scheduledTime)
        .compareTo(DateFormatter.minutesOfDay(b.scheduledTime)));
    return pending;
  }

  double get todayAdherencePercentage => _adherenceOf(todayLogs);
  double get overallAdherencePercentage => _adherenceOf(_allLogs);

  /// Adherence counts only doses that have been resolved. Pending doses are
  /// excluded in both directions — counting them as missed would show a patient
  /// 0% at breakfast for a dose not yet due.
  double _adherenceOf(List<DoseLogModel> logs) {
    final resolved = logs.where((l) => l.isTaken || l.isMissed).length;
    if (resolved == 0) return 100.0;
    final taken = logs.where((l) => l.isTaken).length;
    return (taken / resolved) * 100.0;
  }

  /// The next dose due today, or the first of tomorrow's if today is done.
  ///
  /// Previously this returned `_schedules.first` from an unsorted stream, so
  /// the dashboard's "next dose" was whichever document Firestore happened to
  /// return first.
  ScheduleModel? get nextDueDose {
    final ordered = schedules;
    if (ordered.isEmpty) return null;

    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    for (final schedule in ordered) {
      if (DateFormatter.minutesOfDay(schedule.scheduledTime) >= nowMinutes) {
        return schedule;
      }
    }
    return ordered.first;
  }

  /// Schedules whose stock has fallen to the threshold.
  List<ScheduleModel> get lowStockSchedules =>
      _schedules.where((s) => s.isLowStock).toList();

  PatientMedicationModel? medicationFor(String patMedRef) {
    for (final med in _medications) {
      if (med.patMedId == patMedRef) return med;
    }
    return null;
  }

  /// A display name for a schedule's medicine, falling back to something
  /// readable rather than an empty string in a notification body.
  String medicationNameFor(ScheduleModel schedule) {
    final med = medicationFor(schedule.patMedRef);
    final name = med?.medicationName.trim() ?? '';
    return name.isEmpty ? 'your medication' : name;
  }

  ScheduleModel? scheduleById(String scheduleId) {
    for (final schedule in _schedules) {
      if (schedule.scheduleId == scheduleId) return schedule;
    }
    return null;
  }

  /// Today's log for [scheduleId], if one has been materialised.
  DoseLogModel? todayLogForSchedule(String scheduleId) {
    for (final log in todayLogs) {
      if (log.scheduleRef == scheduleId) return log;
    }
    return null;
  }

  // ==========================================
  // LIFECYCLE
  // ==========================================

  void initForPatient(String uid) {
    if (_patientUid == uid) return;
    _patientUid = uid;
    _cancelSubscriptions();

    _medicationsLoaded = false;
    _schedulesLoaded = false;
    _logsLoaded = false;
    notifyListeners();

    _profileSub = _firestoreService.streamPatientProfile(uid).listen((p) {
      _profile = p;
      notifyListeners();
    }, onError: _onStreamError);

    _medicationsSub =
        _firestoreService.streamPatientMedications(uid).listen((meds) {
      _medications = meds;
      _medicationsLoaded = true;
      notifyListeners();
    }, onError: (Object e) {
      _medicationsLoaded = true;
      _onStreamError(e);
    });

    _schedulesSub = _firestoreService.streamPatientSchedules(uid).listen((schs) {
      _schedules = schs;
      _schedulesLoaded = true;
      // Re-arm the on-device reminders whenever the regimen changes. The
      // caregiver edits from their own phone, so this stream is the only
      // signal the patient's device gets that a dose time moved.
      DoseReminderScheduler().syncReminders(schs);
      notifyListeners();
    }, onError: (Object e) {
      _schedulesLoaded = true;
      _onStreamError(e);
    });

    _allLogsSub = _firestoreService
        .streamPatientDoseLogs(uid, since: DateTime.now().subtract(_historyWindow))
        .listen((logs) {
      _allLogs = logs;
      _logsLoaded = true;
      notifyListeners();
    }, onError: (Object e) {
      _logsLoaded = true;
      _onStreamError(e);
    });

    _notificationsSub =
        _firestoreService.streamUserNotifications(uid).listen((items) {
      _notifications = items;
      notifyListeners();
    }, onError: _onStreamError);

    _deviceSub = _firestoreService.streamPatientDevice(uid).listen((dev) {
      _device = dev;
      notifyListeners();
    }, onError: _onStreamError);

    _linksSub = _firestoreService.streamPatientLinks(uid).listen((links) async {
      if (links.isEmpty) {
        _link = null;
        _caregiverUser = null;
      } else {
        final active = links.where((l) => l.status == 'active').firstOrNull;
        _link = active ?? links.first;
        _caregiverUser = _link!.caregiverRef.isEmpty
            ? null
            : await _firestoreService.getUser(_link!.caregiverRef);
      }
      notifyListeners();
    }, onError: _onStreamError);
  }

  void _onStreamError(Object e) {
    debugPrint('PatientProvider stream error: $e');
    _errorMessage = AppStrings.offlineGeneric;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ==========================================
  // THE DOSE LOOP
  // ==========================================

  /// Confirms a dose, from the app or the box button.
  ///
  /// Order matters. The dose log is written to Firestore **first** and the
  /// Worker is told **after**, fire-and-forget: a failed notification must never
  /// cost the patient their confirmation, and the cron sweep is the backstop if
  /// the call never lands.
  Future<DoseActionResult> confirmDoseTaken({
    required String scheduleId,
    String? doseLogId,
    String confirmedVia = 'app',
  }) async {
    _errorMessage = null;
    final uid = _patientUid;
    if (uid == null) return DoseActionResult.failed;

    try {
      final existing = doseLogId != null && doseLogId.isNotEmpty
          ? await _firestoreService.getDoseLog(doseLogId)
          : todayLogForSchedule(scheduleId);

      // Confirming twice must not decrement stock twice. A double tap on a
      // slow connection is the common case, not an edge case.
      if (existing != null && existing.isTaken) {
        return DoseActionResult.alreadyConfirmed;
      }

      final now = DateTime.now();
      final schedule = scheduleById(scheduleId);
      String resolvedLogId;

      if (existing != null) {
        await _firestoreService.updateDoseLogStatus(
          doseLogId: existing.doseLogId,
          status: 'taken',
          takenAt: now,
          confirmedVia: confirmedVia,
          // Left false on purpose. Only the Worker knows whether a push
          // actually left, and hardcoding true here disarmed the sweep's
          // backstop for every dropped notification.
          caregiverNotified: false,
        );
        resolvedLogId = existing.doseLogId;
      } else {
        // No materialised log — an off-schedule confirmation. scheduled_at is
        // always populated, or the sweep cannot see this row and history
        // cannot sort it.
        final scheduledAt = schedule != null
            ? DateFormatter.parseScheduleTime(schedule.scheduledTime, onDate: now)
            : null;
        resolvedLogId = await _firestoreService.recordDoseLog(
          DoseLogModel(
            doseLogId: '',
            scheduleRef: scheduleId,
            patientRef: uid,
            scheduledDate: DateFormatter.toDateKey(now),
            scheduledTime: schedule?.scheduledTime ??
                DateFormatter.toTimeLabel(now),
            scheduledAt: scheduledAt ?? now,
            status: 'taken',
            takenAt: now,
            confirmedVia: confirmedVia,
            caregiverNotified: false,
            recordedBy: uid,
            createdAt: now,
          ),
        );
      }

      // Switch the box LED off and count the stock down. Two separate writes
      // because the security rules allow a managed patient to touch exactly
      // these two fields, one key at a time.
      await _firestoreService.updateScheduleLed(scheduleId, false);
      if (schedule != null) {
        await _firestoreService.decrementPillsRemaining(
          scheduleId,
          schedule.pillsRemaining > 0 ? 1 : 0,
        );
      }

      notifyListeners();
      _reportDoseEvent(
        doseLogId: resolvedLogId,
        status: 'taken',
        scheduleId: scheduleId,
      );
      return DoseActionResult.success;
    } catch (e) {
      debugPrint('confirmDoseTaken failed: $e');
      _errorMessage = AppStrings.doseConfirmFailed;
      notifyListeners();
      return DoseActionResult.failed;
    }
  }

  /// Snoozes a dose by ten minutes, up to three times.
  ///
  /// The cap is enforced here and again in the Worker's sweep — the app cannot
  /// be the only place it lives, because the app may be closed when the third
  /// snooze expires.
  Future<DoseActionResult> snoozeDose({
    required String doseLogId,
    required int currentSnoozeCount,
    String? scheduleId,
  }) async {
    _errorMessage = null;
    try {
      if (currentSnoozeCount >= 3) {
        final marked = await markDoseMissed(
          doseLogId: doseLogId,
          reason: 'Exceeded the 3-snooze limit',
          scheduleId: scheduleId,
        );
        return marked == DoseActionResult.success
            ? DoseActionResult.snoozeLimitReached
            : DoseActionResult.failed;
      }

      await _firestoreService.updateDoseLogStatus(
        doseLogId: doseLogId,
        status: 'snoozed',
        snoozeCount: currentSnoozeCount + 1,
      );

      // Re-fire locally in ten minutes. Without this the snooze only changes a
      // database field and the patient is never prompted again — the dose then
      // goes missed with no second chance, which is the opposite of snoozing.
      if (scheduleId != null && scheduleId.isNotEmpty) {
        final schedule = _schedules
            .where((s) => s.scheduleId == scheduleId)
            .cast<ScheduleModel?>()
            .firstWhere((s) => s != null, orElse: () => null);
        await DoseReminderScheduler().scheduleSnooze(
          scheduleId: scheduleId,
          matBoxColumn: schedule?.matBoxColumn ?? 1,
        );
      }

      notifyListeners();
      return DoseActionResult.success;
    } catch (e) {
      debugPrint('snoozeDose failed: $e');
      _errorMessage = AppStrings.genericError;
      notifyListeners();
      return DoseActionResult.failed;
    }
  }

  /// Marks a dose missed and turns the compartment LED off, so the box stops
  /// prompting for a dose the system has written off.
  Future<DoseActionResult> markDoseMissed({
    required String doseLogId,
    String reason = 'Not confirmed',
    String? scheduleId,
  }) async {
    _errorMessage = null;
    try {
      await _firestoreService.updateDoseLogStatus(
        doseLogId: doseLogId,
        status: 'missed',
        skippedReason: reason,
        caregiverNotified: false,
      );
      if (scheduleId != null && scheduleId.isNotEmpty) {
        await _firestoreService.updateScheduleLed(scheduleId, false);
      }
      notifyListeners();
      _reportDoseEvent(
        doseLogId: doseLogId,
        status: 'missed',
        scheduleId: scheduleId,
      );
      return DoseActionResult.success;
    } catch (e) {
      debugPrint('markDoseMissed failed: $e');
      _errorMessage = AppStrings.genericError;
      notifyListeners();
      return DoseActionResult.failed;
    }
  }

  /// Tells the Worker to alert the caregiver. Intentionally not awaited by
  /// callers: the dose is already recorded, and `ApiService.reportDoseEvent`
  /// swallows its own failures.
  void _reportDoseEvent({
    required String doseLogId,
    required String status,
    String? scheduleId,
  }) {
    final schedule = scheduleId == null ? null : scheduleById(scheduleId);
    _apiService.reportDoseEvent(
      doseLogId: doseLogId,
      status: status,
      medicationName:
          schedule == null ? 'their medication' : medicationNameFor(schedule),
    );
  }

  // ==========================================
  // MEDICATIONS (solo users only — gated on can_edit_medications)
  // ==========================================

  /// Updates the medicine itself — name, dosage, instructions, doctor.
  ///
  /// These live on `patient_medications`, not on the schedule, which is why
  /// editing a dose time never reached them.
  Future<bool> updateMedication(PatientMedicationModel medication) async {
    _errorMessage = null;
    try {
      await _firestoreService.updatePatientMedication(medication);
      return true;
    } catch (e) {
      debugPrint('updateMedication failed: $e');
      _errorMessage = AppStrings.genericError;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSchedule(ScheduleModel schedule) async {
    _errorMessage = null;
    try {
      await _firestoreService.updateSchedule(schedule);
      return true;
    } catch (e) {
      debugPrint('updateSchedule failed: $e');
      _errorMessage = AppStrings.genericError;
      notifyListeners();
      return false;
    }
  }

  /// Retires a medicine and every schedule attached to it.
  Future<bool> deleteMedication(String patMedId) async {
    _errorMessage = null;
    try {
      final uid = _patientUid;
      if (uid == null) return false;
      await _firestoreService.deletePatientMedication(patMedId, patientUid: uid);
      return true;
    } catch (e) {
      debugPrint('deleteMedication failed: $e');
      _errorMessage = AppStrings.genericError;
      notifyListeners();
      return false;
    }
  }

  /// Removes one dose time while leaving the medicine in place.
  Future<bool> deleteSchedule(String scheduleId) async {
    _errorMessage = null;
    try {
      await _firestoreService.deactivateSchedule(scheduleId);
      return true;
    } catch (e) {
      debugPrint('deleteSchedule failed: $e');
      _errorMessage = AppStrings.genericError;
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // PROFILE, NOTIFICATIONS, DEVICE
  // ==========================================

  Future<bool> saveProfile(PatientProfileModel updated) async {
    _errorMessage = null;
    try {
      await _firestoreService.setPatientProfile(updated);
      _profile = updated;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('saveProfile failed: $e');
      _errorMessage = AppStrings.genericError;
      notifyListeners();
      return false;
    }
  }

  /// Saves the clinical details collected during first-run setup.
  Future<bool> saveProfileDetails({
    String? medicalConditions,
    String? allergies,
    String? emergencyContact,
    String? emergencyPhone,
    DateTime? dateOfBirth,
    String? gender,
  }) async {
    final uid = _patientUid;
    if (uid == null) return false;

    final base = _profile ??
        PatientProfileModel(
          profileId: uid,
          userRef: uid,
          createdAt: DateTime.now(),
        );

    return saveProfile(base.copyWith(
      medicalConditions: _splitList(medicalConditions),
      allergies: _splitList(allergies),
      emergencyContact: emergencyContact,
      emergencyPhone: emergencyPhone,
      dateOfBirth: dateOfBirth,
      gender: gender,
    ));
  }

  /// Forms collect these as free text ("dust, peanuts"); Firestore holds them
  /// as arrays. Null means "leave unchanged", which is why this returns null
  /// rather than an empty list.
  static List<String>? _splitList(String? raw) {
    if (raw == null) return null;
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> markNotificationRead(String notifId) async {
    try {
      await _firestoreService.markNotificationAsRead(notifId);
    } catch (e) {
      debugPrint('markNotificationRead failed: $e');
    }
  }

  Future<void> markAllNotificationsRead() async {
    final uid = _patientUid;
    if (uid == null) return;
    try {
      await _firestoreService.markAllNotificationsRead(uid);
    } catch (e) {
      debugPrint('markAllNotificationsRead failed: $e');
    }
  }

  /// Pairs a smart box by serial number.
  ///
  /// Returns false with [errorMessage] set rather than throwing — the pairing
  /// screen previously called nothing at all, so no device document was ever
  /// created.
  Future<bool> pairSmartBox(
    String serialNumber, {
    String deviceName = 'HealthSync Smart Box',
  }) async {
    final uid = _patientUid;
    if (uid == null) return false;
    _errorMessage = null;
    try {
      await _firestoreService.pairDevice(
        patientUid: uid,
        serialNumber: serialNumber,
        deviceName: deviceName,
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('pairSmartBox failed: $e');
      _errorMessage = AppStrings.devicePairFailed;
      notifyListeners();
      return false;
    }
  }

  Future<bool> unlinkCaregiver() async {
    if (_link == null || _patientUid == null) return false;
    _errorMessage = null;
    try {
      await _firestoreService.unlinkCaregiverPatient(
        _link!.linkId,
        _patientUid!,
      );
      _link = null;
      _caregiverUser = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('unlinkCaregiver failed: $e');
      _errorMessage = AppStrings.genericError;
      notifyListeners();
      return false;
    }
  }

  void _cancelSubscriptions() {
    _profileSub?.cancel();
    _medicationsSub?.cancel();
    _schedulesSub?.cancel();
    _allLogsSub?.cancel();
    _notificationsSub?.cancel();
    _deviceSub?.cancel();
    _linksSub?.cancel();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
