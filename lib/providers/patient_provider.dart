import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_strings.dart';
import '../models/patient_profile_model.dart';
import '../models/patient_medication_model.dart';
import '../models/schedule_model.dart';
import '../models/dose_log_model.dart';
import '../models/dose_slot.dart';
import '../models/device_model.dart';
import '../models/notification_model.dart';
import '../models/caregiver_patient_link_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/dose_reminder_scheduler.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../utils/adherence.dart';
import '../utils/date_formatter.dart';
import '../utils/dose_timing.dart';

/// How far back the history stream reaches.
///
/// Bounded deliberately: an unbounded stream re-reads the patient's whole
/// history on every write, and the Spark plan allows 50k reads a day. Every
/// screen in the app asks for 90 days or less.
const Duration _historyWindow = Duration(days: 90);

/// How long one snooze lasts. Another snooze is refused until it has run out.
const Duration snoozeDuration = Duration(minutes: 10);

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

/// What a Done or Skip changed, so Undo can put it back exactly
/// (DOSE_LOGIC_PROPOSAL.md, section 4.3), and so the caregiver is told only
/// once the Undo window has passed (4.2).
class DoseUndo {
  final String doseLogId;
  final String scheduleId;

  /// The dose-log fields as they were before the action.
  final Map<String, dynamic> restore;

  /// The status reported to the Worker once the action is final.
  final String reportStatus;

  /// Whether a pill was counted off, to give back on Undo.
  final bool decremented;

  /// The low-stock notification this action raised, hidden again on Undo.
  final String? lowStockNotifId;

  /// Whether the box LED was lit before, to light it again on Undo.
  final bool ledWasActive;

  bool _settled = false;

  DoseUndo._({
    required this.doseLogId,
    required this.scheduleId,
    required this.restore,
    required this.reportStatus,
    this.decremented = false,
    this.lowStockNotifId,
    this.ledWasActive = false,
  });

  /// Undone, or reported to the Worker. Either way nothing more happens.
  bool get isSettled => _settled;
}

/// The result of a Done or Skip, with what is needed to undo it.
class DoseOutcome {
  final DoseActionResult result;
  final DoseUndo? undo;

  const DoseOutcome(this.result, [this.undo]);
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

  /// Adherence uses the shared rules in [AdherenceStats]: taken ÷ (taken +
  /// missed + skipped), ignoring open, cancelled and mistake doses.
  double get todayAdherencePercentage =>
      AdherenceStats.of(todayLogs).adherence * 100.0;
  double get overallAdherencePercentage => overallStats.adherence * 100.0;
  AdherenceStats get overallStats => AdherenceStats.of(_allLogs);

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

  /// Whether a medicine box is paired. Without one the app is phone-only.
  bool get hasBox => _device != null;

  /// Whether to tell the patient to take [schedule] from a compartment. Needs
  /// both a compartment and a paired box: an unpaired box keeps its
  /// compartment numbers for re-pairing, but nothing is lit.
  bool showsCompartment(ScheduleModel schedule) =>
      hasBox && schedule.matBoxColumn != null;

  /// What to take, in words: "Compartment 3" with a box, "1 tablet" without.
  String doseInstructionFor(ScheduleModel schedule) {
    if (showsCompartment(schedule)) {
      return 'Compartment ${schedule.matBoxColumn}';
    }
    return medicationFor(schedule.patMedRef)?.doseDescription ?? 'Your dose';
  }

  /// Notification text for one dose.
  String reminderBodyFor(ScheduleModel schedule) {
    final name = medicationFor(schedule.patMedRef)?.medicationName.trim() ?? '';
    return [
      if (name.isNotEmpty) name,
      doseInstructionFor(schedule),
      schedule.scheduledTime,
    ].join(' · ');
  }

  /// Re-arms on-device reminders with current wording. Called when schedules,
  /// medicines, or whether a box is paired change.
  void _syncReminders() {
    if (!_schedulesLoaded) return;
    DoseReminderScheduler().syncReminders(
      _schedules,
      bodyFor: reminderBodyFor,
    );
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

  /// Whether [schedule] has a dose on [day]: the right weekday, and inside
  /// its start and end dates. The old dashboard checked the weekday only, so a
  /// course that had ended still showed.
  static bool runsOn(ScheduleModel schedule, DateTime day) {
    if (schedule.daysOfWeek.isNotEmpty &&
        !schedule.daysOfWeek.contains(day.weekday)) {
      return false;
    }
    final date = DateFormatter.startOfDay(day);
    if (date.isBefore(DateFormatter.startOfDay(schedule.startDate))) {
      return false;
    }
    final end = schedule.endDate;
    if (end != null && date.isAfter(DateFormatter.startOfDay(end))) {
      return false;
    }
    return true;
  }

  static String _dateKeyOf(DoseLogModel log) {
    if (log.scheduledDate.isNotEmpty) return log.scheduledDate;
    final at = log.scheduledAt;
    return at == null ? '' : DateFormatter.toDateKey(at);
  }

  static bool _sameMinute(DoseLogModel log, DateTime at) {
    final logAt = log.scheduledAt;
    if (logAt != null) {
      return logAt.year == at.year &&
          logAt.month == at.month &&
          logAt.day == at.day &&
          logAt.hour == at.hour &&
          logAt.minute == at.minute;
    }
    return DateFormatter.minutesOfDay(log.scheduledTime) ==
        at.hour * 60 + at.minute;
  }

  /// Every dose due on [day], earliest first, each with its log if there is
  /// one. Cancelled doses never appear.
  List<DoseSlot> slotsForDay(DateTime day) {
    final key = DateFormatter.toDateKey(day);
    final logs = _allLogs
        .where((l) => !l.isCancelled && _dateKeyOf(l) == key)
        .toList();
    final used = <String>{};
    final slots = <DoseSlot>[];

    for (final schedule in _schedules) {
      if (!runsOn(schedule, day)) continue;
      final at =
          DateFormatter.parseScheduleTime(schedule.scheduledTime, onDate: day);
      if (at == null) continue;
      final log = logs
          .where((l) =>
              l.scheduleRef == schedule.scheduleId && _sameMinute(l, at))
          .firstOrNull;
      // A dose time that had already passed when the medicine was added (an
      // 8 AM dose for a medicine added at 11 AM) never existed, unless
      // something was recorded for it. Same 15-minute grace as the Worker.
      if (log == null &&
          at.add(const Duration(minutes: 15)).isBefore(schedule.createdAt)) {
        continue;
      }
      if (log != null) used.add(log.doseLogId);
      slots.add(DoseSlot(schedule: schedule, scheduledAt: at, log: log));
    }

    // A dose already decided whose time has since been edited: the schedule
    // now points at a new time, but what happened at the old one still
    // belongs in "Done today".
    for (final log in logs) {
      if (used.contains(log.doseLogId) || !log.isResolved) continue;
      final schedule = scheduleById(log.scheduleRef);
      if (schedule == null) continue;
      final at = log.scheduledAt ??
          DateFormatter.parseScheduleTime(log.scheduledTime, onDate: day);
      if (at == null) continue;
      slots.add(DoseSlot(schedule: schedule, scheduledAt: at, log: log));
    }

    slots.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return slots;
  }

  /// Today's dose for [scheduleId], or null if it has none today.
  DoseSlot? todaySlotFor(String scheduleId) {
    final now = DateTime.now();
    final slots = slotsForDay(now)
        .where((s) => s.schedule.scheduleId == scheduleId)
        .toList();
    if (slots.isEmpty) return null;
    // Several slots happen only around an edited dose time; prefer the one
    // still open.
    return slots.where((s) => s.isOpen).firstOrNull ?? slots.last;
  }

  /// The dose of the same medicine just before [slot], today or yesterday —
  /// for the half-gap early-logging rule.
  DateTime? previousDoseAt(DoseSlot slot) {
    final day = slot.scheduledAt;
    final candidates = [
      ...slotsForDay(day.subtract(const Duration(days: 1))),
      ...slotsForDay(day),
    ].where((s) =>
        s.schedule.patMedRef == slot.schedule.patMedRef &&
        s.scheduledAt.isBefore(slot.scheduledAt));
    DateTime? latest;
    for (final s in candidates) {
      if (latest == null || s.scheduledAt.isAfter(latest)) {
        latest = s.scheduledAt;
      }
    }
    return latest;
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
      // Reminder text names the medicine, so a rename must reach it.
      _syncReminders();
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
      _syncReminders();
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
      final hadBox = hasBox;
      _device = dev;
      // Only pairing or unpairing changes reminder wording. Heartbeats update
      // this document constantly and must not re-arm every reminder.
      if (hadBox != hasBox) _syncReminders();
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
  //
  // Every action writes Firestore first. Done and Skip then wait for the Undo
  // window before the Worker is told (finalizeDoseAction), so an undone tap
  // never notifies the caregiver. Everything else reports straight away.

  /// A fresh pending log for [slot] under its deterministic id.
  DoseLogModel _newLog(String uid, DoseSlot slot, DateTime now) => DoseLogModel(
        doseLogId: slot.doseLogId,
        scheduleRef: slot.schedule.scheduleId,
        patientRef: uid,
        scheduledDate: DateFormatter.toDateKey(slot.scheduledAt),
        scheduledTime: slot.schedule.scheduledTime,
        scheduledAt: slot.scheduledAt,
        confirmedVia: '',
        recordedBy: uid,
        createdAt: now,
      );

  /// The current schedule for [slot] — the slot may hold an older copy.
  ScheduleModel _liveSchedule(DoseSlot slot) =>
      scheduleById(slot.schedule.scheduleId) ?? slot.schedule;

  DoseOutcome _fail(String message) {
    _errorMessage = message;
    notifyListeners();
    return const DoseOutcome(DoseActionResult.failed);
  }

  /// Marks [slot] taken. [early] is true when the patient came through the
  /// early-logging prompt. Call [finalizeDoseAction] when the Undo window
  /// closes, or [undoDoseAction] if Undo is tapped.
  Future<DoseOutcome> takeDose(DoseSlot slot, {bool early = false}) async {
    _errorMessage = null;
    final uid = _patientUid;
    if (uid == null) return const DoseOutcome(DoseActionResult.failed);
    final schedule = _liveSchedule(slot);

    try {
      final existing = await _firestoreService.getDoseLog(slot.doseLogId);
      // Confirming twice must not count a pill off twice. A double tap on a
      // slow connection is the common case, not an edge case.
      if (existing != null && existing.isTaken) {
        return const DoseOutcome(DoseActionResult.alreadyConfirmed);
      }
      if (existing != null && !existing.isOpen) {
        return _fail(AppStrings.doseAlreadyResolved);
      }
      // An empty compartment means the patient cannot have taken this dose.
      // Recording it anyway told the caregiver they had.
      if (schedule.pillsRemaining <= 0) {
        return _fail(AppStrings.doseOutOfStock);
      }

      final now = DateTime.now();
      final timing = DoseTiming.timingFor(
        takenAt: now,
        scheduledAt: slot.scheduledAt,
        early: early,
      );

      final Map<String, dynamic> restore;
      if (existing != null) {
        restore = {
          'status': existing.status,
          'taken_at': existing.takenAt,
          'timing': existing.timing,
          'confirmed_via': existing.confirmedVia,
          'logged_at': existing.loggedAt,
          'caregiver_notified': existing.caregiverNotified,
        };
        await _firestoreService.updateDoseLogFields(slot.doseLogId, {
          'status': DoseStatus.taken,
          'taken_at': now,
          'timing': timing,
          'confirmed_via': 'app',
          'logged_at': now,
          // Left false on purpose: only the Worker knows whether a push
          // actually left.
          'caregiver_notified': false,
        });
      } else {
        // Not materialised yet. Written under the Worker's own id, so the
        // materialiser sees it and does not create a second, pending copy
        // that the sweep would later mark missed.
        restore = {
          'status': DoseStatus.pending,
          'taken_at': null,
          'timing': null,
          'confirmed_via': '',
          'logged_at': null,
          'caregiver_notified': false,
        };
        await _firestoreService.setDoseLog(_newLog(uid, slot, now).copyWith(
          status: DoseStatus.taken,
          takenAt: now,
          timing: timing,
          confirmedVia: 'app',
          loggedAt: now,
        ));
      }

      // Switch the box LED off and count the stock down. Two separate writes
      // because the security rules allow a managed patient to touch exactly
      // these two fields on a schedule.
      final ledWasActive = schedule.ledActive;
      await _firestoreService.updateScheduleLed(schedule.scheduleId, false);
      await _firestoreService.decrementPillsRemaining(schedule.scheduleId, 1);
      final notifId =
          await _alertIfStockLow(uid, schedule, schedule.pillsRemaining - 1);

      notifyListeners();
      return DoseOutcome(
        DoseActionResult.success,
        DoseUndo._(
          doseLogId: slot.doseLogId,
          scheduleId: schedule.scheduleId,
          restore: restore,
          reportStatus: DoseStatus.taken,
          decremented: true,
          lowStockNotifId: notifId,
          ledWasActive: ledWasActive,
        ),
      );
    } catch (e) {
      debugPrint('takeDose failed: $e');
      return _fail(AppStrings.doseConfirmFailed);
    }
  }

  /// Marks [slot] skipped with [reason]. Same Undo contract as [takeDose].
  Future<DoseOutcome> skipDose(DoseSlot slot, String reason) async {
    _errorMessage = null;
    final uid = _patientUid;
    if (uid == null) return const DoseOutcome(DoseActionResult.failed);
    final schedule = _liveSchedule(slot);

    try {
      final existing = await _firestoreService.getDoseLog(slot.doseLogId);
      if (existing != null && existing.isTaken) {
        return const DoseOutcome(DoseActionResult.alreadyConfirmed);
      }
      if (existing != null && !existing.isOpen) {
        return _fail(AppStrings.doseAlreadyResolved);
      }

      final now = DateTime.now();
      final Map<String, dynamic> restore;
      if (existing != null) {
        restore = {
          'status': existing.status,
          'skipped_reason': existing.skippedReason,
          'acknowledged_at': existing.acknowledgedAt,
          'logged_at': existing.loggedAt,
          'caregiver_notified': existing.caregiverNotified,
        };
        await _firestoreService.updateDoseLogFields(slot.doseLogId, {
          'status': DoseStatus.skipped,
          'skipped_reason': reason,
          'acknowledged_at': now,
          'logged_at': now,
          'caregiver_notified': false,
        });
      } else {
        restore = {
          'status': DoseStatus.pending,
          'skipped_reason': '',
          'acknowledged_at': null,
          'logged_at': null,
          'caregiver_notified': false,
        };
        await _firestoreService.setDoseLog(_newLog(uid, slot, now).copyWith(
          status: DoseStatus.skipped,
          skippedReason: reason,
          acknowledgedAt: now,
          loggedAt: now,
        ));
      }

      final ledWasActive = schedule.ledActive;
      await _firestoreService.updateScheduleLed(schedule.scheduleId, false);

      notifyListeners();
      return DoseOutcome(
        DoseActionResult.success,
        DoseUndo._(
          doseLogId: slot.doseLogId,
          scheduleId: schedule.scheduleId,
          restore: restore,
          reportStatus: DoseStatus.skipped,
          ledWasActive: ledWasActive,
        ),
      );
    } catch (e) {
      debugPrint('skipDose failed: $e');
      return _fail(AppStrings.genericError);
    }
  }

  /// Puts a dose back exactly as it was before Done or Skip: status and
  /// fields, the pill, the low-stock notice and the LED. The Worker is never
  /// told about an undone action.
  Future<bool> undoDoseAction(DoseUndo undo) async {
    if (undo._settled) return false;
    undo._settled = true;
    _errorMessage = null;
    try {
      await _firestoreService.updateDoseLogFields(undo.doseLogId, undo.restore);
      if (undo.decremented) {
        await _firestoreService.incrementPillsRemaining(undo.scheduleId, 1);
      }
      final notifId = undo.lowStockNotifId;
      if (notifId != null) {
        await _firestoreService.deactivateNotification(notifId);
      }
      if (undo.ledWasActive) {
        await _firestoreService.updateScheduleLed(undo.scheduleId, true);
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('undoDoseAction failed: $e');
      // The action stands, so the caregiver must still hear about it.
      undo._settled = false;
      finalizeDoseAction(undo);
      _errorMessage = AppStrings.undoFailed;
      notifyListeners();
      return false;
    }
  }

  /// Called when the Undo window closes without Undo: the action is final,
  /// so now the Worker tells the caregiver. If the app is killed before this
  /// runs, the dose is still saved; only the push is lost (and for Skip, the
  /// Worker's backstop picks it up).
  void finalizeDoseAction(DoseUndo undo) {
    if (undo._settled) return;
    undo._settled = true;
    _reportDoseEvent(
      doseLogId: undo.doseLogId,
      status: undo.reportStatus,
      scheduleId: undo.scheduleId,
    );
  }

  /// Records a low-stock alert for the patient once stock reaches the
  /// threshold, and again when it reaches zero — not on every dose below it.
  /// Returns the notification's id, so Undo can hide it again.
  ///
  /// The caregiver's copy is sent by the Worker from `/dose-events`: security
  /// rules only let a client write notifications addressed to itself.
  Future<String?> _alertIfStockLow(
    String uid,
    ScheduleModel schedule,
    int remaining,
  ) async {
    if (remaining != schedule.lowStockThreshold && remaining != 0) return null;
    try {
      return await NotificationService().sendLowStockAlert(
        userUid: uid,
        medicationName: medicationNameFor(schedule),
        remainingCount: remaining,
      );
    } catch (e) {
      // The dose is already recorded; a lost alert must not fail it.
      debugPrint('low stock alert failed: $e');
      return null;
    }
  }

  /// Snoozes [slot] by ten minutes, up to three times. Only offered on the
  /// alarm screen, and only while the dose is due or late.
  ///
  /// The cap is enforced here and again in the Worker's sweep — the app may be
  /// closed when the last snooze expires.
  Future<DoseActionResult> snoozeDose(DoseSlot slot) async {
    _errorMessage = null;
    final uid = _patientUid;
    if (uid == null) return DoseActionResult.failed;

    final phase = DoseTiming.phaseOf(slot.scheduledAt, DateTime.now());
    if (phase != DosePhase.dueNow && phase != DosePhase.late) {
      _fail(AppStrings.snoozeNotAvailable);
      return DoseActionResult.failed;
    }

    try {
      final existing = await _firestoreService.getDoseLog(slot.doseLogId);
      if (existing != null && existing.isTaken) {
        return DoseActionResult.alreadyConfirmed;
      }
      if (existing != null && !existing.isOpen) {
        _fail(AppStrings.doseAlreadyResolved);
        return DoseActionResult.failed;
      }
      // One snooze at a time. The cap alone let three quick taps burn every
      // snooze and mark the dose missed immediately.
      if (existing != null && existing.isSnoozeActive) {
        _fail(AppStrings.snoozeActiveUntil(
          DateFormatter.toClockLabel(existing.snoozedUntil!),
        ));
        return DoseActionResult.failed;
      }

      final count = existing?.snoozeCount ?? 0;
      if (count >= 3) {
        final marked = await markDoseMissed(
          doseLogId: slot.doseLogId,
          reason: 'Exceeded the 3-snooze limit',
          scheduleId: slot.schedule.scheduleId,
        );
        return marked == DoseActionResult.success
            ? DoseActionResult.snoozeLimitReached
            : DoseActionResult.failed;
      }

      final now = DateTime.now();
      final until = now.add(snoozeDuration);
      if (existing == null) {
        await _firestoreService.setDoseLog(_newLog(uid, slot, now).copyWith(
          status: DoseStatus.snoozed,
          snoozeCount: 1,
          snoozedUntil: until,
        ));
      } else {
        await _firestoreService.updateDoseLogFields(slot.doseLogId, {
          'status': DoseStatus.snoozed,
          'snooze_count': count + 1,
          'snoozed_until': until,
        });
      }

      // Re-fire locally in ten minutes. Without this the snooze only changes a
      // database field and the patient is never prompted again.
      final schedule = _liveSchedule(slot);
      await DoseReminderScheduler().scheduleSnooze(
        scheduleId: schedule.scheduleId,
        body: '${reminderBodyFor(schedule)} — please take it now.',
        delay: snoozeDuration,
      );

      notifyListeners();
      return DoseActionResult.success;
    } catch (e) {
      debugPrint('snoozeDose failed: $e');
      _fail(AppStrings.genericError);
      return DoseActionResult.failed;
    }
  }

  /// Marks a dose missed and turns the compartment LED off, so the box stops
  /// prompting for a dose the system has written off. Used when the snooze
  /// limit is reached.
  Future<DoseActionResult> markDoseMissed({
    required String doseLogId,
    String reason = 'Not confirmed',
    String? scheduleId,
  }) async {
    _errorMessage = null;
    try {
      await _firestoreService.updateDoseLogFields(doseLogId, {
        'status': DoseStatus.missed,
        'skipped_reason': reason,
        'caregiver_notified': false,
        'logged_at': DateTime.now(),
      });
      if (scheduleId != null && scheduleId.isNotEmpty) {
        await _firestoreService.updateScheduleLed(scheduleId, false);
      }
      notifyListeners();
      _reportDoseEvent(
        doseLogId: doseLogId,
        status: DoseStatus.missed,
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

  /// "I took it but forgot to log it" (DOSE_LOGIC_PROPOSAL.md, 7.3).
  ///
  /// Turns a missed dose into a taken one, labelled `logged_late` so reports
  /// can still tell it was corrected, with [takenAt] the time the patient says
  /// they took it. Allowed only until the end of the next day.
  Future<DoseActionResult> logTakenLate(
    DoseSlot slot,
    DateTime takenAt,
  ) async {
    _errorMessage = null;
    final uid = _patientUid;
    if (uid == null) return DoseActionResult.failed;
    final now = DateTime.now();

    if (!DoseTiming.retroLogAllowed(slot.scheduledAt, now)) {
      _fail(AppStrings.retroWindowClosed);
      return DoseActionResult.failed;
    }
    if (takenAt.isAfter(now)) {
      _fail(AppStrings.retroTimeInFuture);
      return DoseActionResult.failed;
    }
    final schedule = _liveSchedule(slot);
    if (schedule.pillsRemaining <= 0) {
      _fail(AppStrings.doseOutOfStock);
      return DoseActionResult.failed;
    }

    try {
      final existing = await _firestoreService.getDoseLog(slot.doseLogId);
      if (existing != null && existing.isTaken) {
        return DoseActionResult.alreadyConfirmed;
      }
      // Only a missed dose (or one past its missed window that the Worker has
      // not swept yet) can be corrected this way.
      final missedWindow =
          DoseTiming.phaseOf(slot.scheduledAt, now) == DosePhase.missed;
      final correctable = existing == null
          ? missedWindow
          : existing.isMissed || (existing.isOpen && missedWindow);
      if (!correctable) {
        _fail(AppStrings.doseAlreadyResolved);
        return DoseActionResult.failed;
      }

      final fields = {
        'status': DoseStatus.taken,
        'timing': DoseTimingTag.loggedLate,
        'taken_at': takenAt,
        'logged_at': now,
        'acknowledged_at': now,
        'confirmed_via': 'app',
        'skipped_reason': '',
        'caregiver_notified': false,
      };
      if (existing == null) {
        await _firestoreService.setDoseLog(_newLog(uid, slot, now).copyWith(
          status: DoseStatus.taken,
          timing: DoseTimingTag.loggedLate,
          takenAt: takenAt,
          loggedAt: now,
          acknowledgedAt: now,
          confirmedVia: 'app',
        ));
      } else {
        await _firestoreService.updateDoseLogFields(slot.doseLogId, fields);
      }

      await _firestoreService.updateScheduleLed(schedule.scheduleId, false);
      await _firestoreService.decrementPillsRemaining(schedule.scheduleId, 1);
      await _alertIfStockLow(uid, schedule, schedule.pillsRemaining - 1);

      notifyListeners();
      // The Worker reads timing `logged_late` and sends the caregiver a
      // correction rather than "Dose taken".
      _reportDoseEvent(
        doseLogId: slot.doseLogId,
        status: DoseStatus.taken,
        scheduleId: schedule.scheduleId,
      );
      return DoseActionResult.success;
    } catch (e) {
      debugPrint('logTakenLate failed: $e');
      _fail(AppStrings.doseConfirmFailed);
      return DoseActionResult.failed;
    }
  }

  /// Saves why a dose was missed. A dose the Worker has not swept yet is
  /// marked missed here, and the caregiver is told, because the sweep will no
  /// longer see it.
  Future<DoseActionResult> saveMissedReason(DoseSlot slot, String reason) async {
    _errorMessage = null;
    final uid = _patientUid;
    if (uid == null) return DoseActionResult.failed;

    try {
      final now = DateTime.now();
      final existing = await _firestoreService.getDoseLog(slot.doseLogId);

      if (existing != null && existing.isMissed) {
        await _firestoreService.updateDoseLogFields(slot.doseLogId, {
          'skipped_reason': reason,
          'acknowledged_at': now,
        });
        notifyListeners();
        return DoseActionResult.success;
      }
      if (existing != null && !existing.isOpen) {
        _fail(AppStrings.doseAlreadyResolved);
        return DoseActionResult.failed;
      }

      if (existing == null) {
        await _firestoreService.setDoseLog(_newLog(uid, slot, now).copyWith(
          status: DoseStatus.missed,
          skippedReason: reason,
          acknowledgedAt: now,
          loggedAt: now,
        ));
      } else {
        await _firestoreService.updateDoseLogFields(slot.doseLogId, {
          'status': DoseStatus.missed,
          'skipped_reason': reason,
          'acknowledged_at': now,
          'logged_at': now,
          'caregiver_notified': false,
        });
      }
      await _firestoreService.updateScheduleLed(slot.schedule.scheduleId, false);
      notifyListeners();
      _reportDoseEvent(
        doseLogId: slot.doseLogId,
        status: DoseStatus.missed,
        scheduleId: slot.schedule.scheduleId,
      );
      return DoseActionResult.success;
    } catch (e) {
      debugPrint('saveMissedReason failed: $e');
      _fail(AppStrings.genericError);
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
  // MEDICATIONS (gated on can_edit_medications — caregivers only)
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
