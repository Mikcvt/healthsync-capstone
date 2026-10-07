import 'dart:async';
import 'package:flutter/material.dart';
import '../models/caregiver_profile_model.dart';
import '../models/caregiver_patient_link_model.dart';
import '../models/patient_profile_model.dart';
import '../models/user_model.dart';
import '../models/schedule_model.dart';
import '../models/dose_log_model.dart';
import '../models/notification_model.dart';
import '../models/patient_medication_model.dart';
import '../models/otp_code_model.dart';
import '../services/api_service.dart';
import '../services/firestore_service.dart';
import '../utils/date_formatter.dart';

/// How far back the selected patient's dose history reaches. Bounded because
/// an unbounded stream re-reads the whole history on every write, against the
/// Spark plan's 50k reads a day.
const Duration _historyWindow = Duration(days: 90);

class CaregiverProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final ApiService _apiService = ApiService();

  String? _caregiverUid;
  CaregiverProfileModel? _profile;
  List<CaregiverPatientLinkModel> _patientLinks = [];
  String? _selectedPatientUid;
  UserModel? _selectedPatientUser;
  PatientProfileModel? _selectedPatientProfile;
  List<ScheduleModel> _selectedPatientSchedules = [];
  List<DoseLogModel> _selectedPatientLogs = [];
  List<PatientMedicationModel> _selectedPatientMedications = [];
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  bool _linksLoaded = false;
  String? _errorMessage;

  StreamSubscription? _profileSub;
  StreamSubscription? _linksSub;
  StreamSubscription? _notificationsSub;
  StreamSubscription? _patientSchedulesSub;
  StreamSubscription? _patientLogsSub;
  StreamSubscription? _patientMedicationsSub;

  CaregiverProfileModel? get profile => _profile;
  List<CaregiverPatientLinkModel> get patientLinks => _patientLinks;
  String? get selectedPatientUid => _selectedPatientUid;
  UserModel? get selectedPatientUser => _selectedPatientUser;
  PatientProfileModel? get selectedPatientProfile => _selectedPatientProfile;
  List<PatientMedicationModel> get selectedPatientMedications =>
      _selectedPatientMedications;
  List<NotificationModel> get notifications => _notifications;
  bool get hasLinkedPatients => _patientLinks.isNotEmpty;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// True until the patient-links stream has emitted once, so an empty list can
  /// be told apart from one that has not arrived.
  bool get isLoadingPatients => _caregiverUid != null && !_linksLoaded;

  int get unreadNotificationCount =>
      _notifications.where((n) => n.readAt == null).length;

  /// The selected patient's schedules, earliest time of day first — the order
  /// every schedule and history view presents them in.
  List<ScheduleModel> get selectedPatientSchedules {
    final sorted = [..._selectedPatientSchedules];
    sorted.sort((a, b) => DateFormatter.minutesOfDay(a.scheduledTime)
        .compareTo(DateFormatter.minutesOfDay(b.scheduledTime)));
    return sorted;
  }

  /// Dose logs for the selected patient, newest scheduled time first.
  List<DoseLogModel> get selectedPatientLogs {
    final sorted = [..._selectedPatientLogs];
    sorted.sort((a, b) {
      final aAt = a.scheduledAt;
      final bAt = b.scheduledAt;
      if (aAt != null && bAt != null) return bAt.compareTo(aAt);
      return b.scheduledDate.compareTo(a.scheduledDate);
    });
    return sorted;
  }

  /// Logs belonging to a schedule still in the regimen. Deleted and finished
  /// medicines keep their history but stop appearing in day views.
  bool _isLiveSchedule(DoseLogModel log) {
    if (log.scheduleRef.isEmpty) return true;
    return _selectedPatientSchedules
        .any((s) => s.scheduleId == log.scheduleRef);
  }

  /// The selected patient's logs for one calendar day.
  List<DoseLogModel> logsForDay(DateTime day) {
    final key = DateFormatter.toDateKey(day);
    return selectedPatientLogs.where((log) {
      if (!_isLiveSchedule(log)) return false;
      if (log.scheduledDate.isNotEmpty) return log.scheduledDate == key;
      final at = log.scheduledAt;
      return at != null && DateFormatter.isSameDay(at, day);
    }).toList();
  }

  PatientMedicationModel? medicationFor(String patMedRef) {
    for (final med in _selectedPatientMedications) {
      if (med.patMedId == patMedRef) return med;
    }
    return null;
  }

  /// A readable medicine name for a schedule, for alert bodies and list rows.
  String medicationNameFor(ScheduleModel schedule) {
    final name = medicationFor(schedule.patMedRef)?.medicationName.trim() ?? '';
    return name.isEmpty ? 'Medication' : name;
  }

  /// The medicine name behind a dose log, resolved through its schedule.
  String medicationNameForLog(DoseLogModel log) {
    for (final schedule in _selectedPatientSchedules) {
      if (schedule.scheduleId == log.scheduleRef) {
        return medicationNameFor(schedule);
      }
    }
    return 'Medication';
  }

  ScheduleModel? scheduleById(String scheduleId) {
    for (final schedule in _selectedPatientSchedules) {
      if (schedule.scheduleId == scheduleId) return schedule;
    }
    return null;
  }

  /// Adherence over [days] for the selected patient, as a 0-1 ratio.
  ///
  /// Shared by the reports screen and the per-patient views so the same patient
  /// cannot show two different percentages on two screens.
  double adherenceOver(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final window = _selectedPatientLogs.where((log) {
      final at = log.scheduledAt;
      return at == null || at.isAfter(cutoff);
    });
    final resolved = window.where((l) => l.isTaken || l.isMissed).length;
    if (resolved == 0) return 1.0;
    return window.where((l) => l.isTaken).length / resolved;
  }

  /// Schedules of the selected patient whose stock has hit the threshold.
  List<ScheduleModel> get lowStockSchedules =>
      _selectedPatientSchedules.where((s) => s.isLowStock).toList();

  // Adherence calculation for selected patient
  double get patientAdherencePercentage {
    if (_selectedPatientLogs.isEmpty) return 100.0;
    final takenCount = _selectedPatientLogs.where((l) => l.isTaken).length;
    final total = _selectedPatientLogs.where((l) => l.isTaken || l.isMissed).length;
    if (total == 0) return 100.0;
    return (takenCount / total) * 100.0;
  }

  void initForCaregiver(String uid) {
    if (_caregiverUid == uid) return;
    _caregiverUid = uid;
    _cancelSubscriptions();

    // Listen to caregiver profile
    _profileSub = _firestoreService.streamCaregiverProfile(uid).listen((p) {
      _profile = p;
      notifyListeners();
    });

    // Listen to linked patients
    _linksSub =
        _firestoreService.streamCaregiverLinks(uid).listen((links) async {
      _patientLinks = links;
      _linksLoaded = true;
      if (_selectedPatientUid == null && links.isNotEmpty) {
        selectPatient(links.first.patientRef);
      }
      notifyListeners();
    }, onError: (Object e) {
      _linksLoaded = true;
      debugPrint('Caregiver links stream error: $e');
      notifyListeners();
    });

    // The caregiver's own alert feed, written by the Worker when it pushes.
    _notificationsSub =
        _firestoreService.streamUserNotifications(uid).listen((items) {
      _notifications = items;
      notifyListeners();
    }, onError: (Object e) => debugPrint('Notifications stream error: $e'));
  }

  Future<void> markNotificationRead(String notifId) async {
    try {
      await _firestoreService.markNotificationAsRead(notifId);
    } catch (e) {
      debugPrint('markNotificationRead failed: $e');
    }
  }

  Future<void> markAllNotificationsRead() async {
    final uid = _caregiverUid;
    if (uid == null) return;
    try {
      await _firestoreService.markAllNotificationsRead(uid);
    } catch (e) {
      debugPrint('markAllNotificationsRead failed: $e');
    }
  }

  // Select active patient to monitor
  Future<void> selectPatient(String patientUid) async {
    _selectedPatientUid = patientUid;
    _patientSchedulesSub?.cancel();
    _patientLogsSub?.cancel();
    _patientMedicationsSub?.cancel();

    // Cleared up front so the UI never shows the previous patient's data
    // against the new patient's name while the streams reconnect.
    _selectedPatientSchedules = [];
    _selectedPatientLogs = [];
    _selectedPatientMedications = [];
    notifyListeners();

    _selectedPatientUser = await _firestoreService.getUser(patientUid);
    _selectedPatientProfile =
        await _firestoreService.getPatientProfile(patientUid);

    _patientSchedulesSub = _firestoreService
        .streamPatientSchedules(patientUid)
        .listen((schs) {
      _selectedPatientSchedules = schs;
      notifyListeners();
    }, onError: (Object e) => debugPrint('Patient schedules error: $e'));

    _patientLogsSub = _firestoreService
        .streamPatientDoseLogs(
          patientUid,
          since: DateTime.now().subtract(_historyWindow),
        )
        .listen((logs) {
      _selectedPatientLogs = logs;
      notifyListeners();
    }, onError: (Object e) => debugPrint('Patient logs error: $e'));

    _patientMedicationsSub = _firestoreService
        .streamPatientMedications(patientUid)
        .listen((meds) {
      _selectedPatientMedications = meds;
      notifyListeners();
    }, onError: (Object e) => debugPrint('Patient medications error: $e'));

    notifyListeners();
  }

  /// Creates a managed patient account through the Worker.
  ///
  /// The patient never signs up — this mints their Auth account and Firestore
  /// documents so their schedule can be built before they ever open the app.
  /// Returns the new uid, or null with [errorMessage] set.
  Future<String?> createPatient({
    required String firstName,
    required String lastName,
    String phone = '',
    String medicalConditions = '',
    String allergies = '',
    String emergencyContact = '',
    String emergencyPhone = '',
  }) async {
    if (_caregiverUid == null) return null;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final uid = await _apiService.createManagedPatient(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        medicalConditions: medicalConditions,
        allergies: allergies,
        emergencyContact: emergencyContact,
        emergencyPhone: emergencyPhone,
      );
      _isLoading = false;
      notifyListeners();
      return uid.isEmpty ? null : uid;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Edits a patient's regimen on their behalf.
  ///
  /// The caregiver is the only account permitted to change a managed patient's
  /// medicines, so these two methods are the authoring path for that whole
  /// role — the patient-side provider is never initialised on this device.
  Future<bool> updateSchedule(ScheduleModel schedule) async {
    _errorMessage = null;
    try {
      await _firestoreService.updateSchedule(schedule);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Retires a medicine and every schedule attached to it. Dose history is
  /// deliberately left intact — adherence records are evidence, not clutter.
  /// Approves a patient's deletion request, or removes a patient directly.
  Future<bool> removePatient(String patientUid) async {
    if (_caregiverUid == null) return false;
    _errorMessage = null;
    try {
      await _firestoreService.deactivatePatient(
        patientUid: patientUid,
        caregiverUid: _caregiverUid!,
      );
      if (_selectedPatientUid == patientUid) {
        _selectedPatientUid = null;
        _selectedPatientUser = null;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Declines the request, leaving the account in place.
  Future<bool> declineDeletionRequest(String patientUid) async {
    _errorMessage = null;
    try {
      await _firestoreService.cancelAccountDeletionRequest(patientUid);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Archives a medicine. [wasMistake] decides whether it can later be erased
  /// for good, or kept as a finished course with its history intact.
  Future<bool> archiveMedication(
    String patMedId,
    String patientUid, {
    required bool wasMistake,
  }) async {
    _errorMessage = null;
    try {
      await _firestoreService.archivePatientMedication(
        patMedId,
        patientUid: patientUid,
        wasMistake: wasMistake,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteMedication(String patMedId, String patientUid) async {
    _errorMessage = null;
    try {
      await _firestoreService.deletePatientMedication(patMedId, patientUid: patientUid);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateMedication(PatientMedicationModel medication) async {
    _errorMessage = null;
    try {
      await _firestoreService.updatePatientMedication(medication);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Returns the code currently outstanding for [patientUid], or mints a new
  /// one. Reusing an unspent code matters: issuing a second would silently
  /// invalidate the one the caregiver already sent.
  Future<OtpCodeModel?> getOrCreateOtp(String patientUid) async {
    if (_caregiverUid == null) return null;
    _errorMessage = null;
    try {
      final existing = await _firestoreService.getActiveOtpForPatient(
        patientUid: patientUid,
        caregiverUid: _caregiverUid!,
      );
      if (existing != null) return existing;

      return await _firestoreService.createOtpCode(
        patientUid: patientUid,
        caregiverUid: _caregiverUid!,
      );
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  /// Revokes the current code and issues a fresh one.
  Future<OtpCodeModel?> regenerateOtp({
    required String patientUid,
    required String currentCode,
  }) async {
    if (_caregiverUid == null) return null;
    _errorMessage = null;
    try {
      await _firestoreService.revokeOtpCode(currentCode);
      return await _firestoreService.createOtpCode(
        patientUid: patientUid,
        caregiverUid: _caregiverUid!,
      );
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  // Update alert preferences
  Future<void> updateAlertPreferences({
    bool? alertPrefMissed,
    bool? alertPrefLowStock,
    bool? alertPrefDaily,
  }) async {
    if (_profile == null || _caregiverUid == null) return;
    final updated = _profile!.copyWith(
      alertPrefMissed: alertPrefMissed,
      alertPrefLowStock: alertPrefLowStock,
      alertPrefDaily: alertPrefDaily,
    );
    await _firestoreService.setCaregiverProfile(updated);
    _profile = updated;
    notifyListeners();
  }

  // Unlink a patient
  Future<void> unlinkPatient(String linkId, String patientUid) async {
    await _firestoreService.unlinkCaregiverPatient(linkId, patientUid);
    if (_selectedPatientUid == patientUid) {
      _selectedPatientUid = null;
      _selectedPatientUser = null;
      _selectedPatientProfile = null;
      _selectedPatientSchedules = [];
      _selectedPatientLogs = [];
      _selectedPatientMedications = [];
      _patientSchedulesSub?.cancel();
      _patientLogsSub?.cancel();
      _patientMedicationsSub?.cancel();
    }
    notifyListeners();
  }

  void _cancelSubscriptions() {
    _profileSub?.cancel();
    _linksSub?.cancel();
    _notificationsSub?.cancel();
    _patientSchedulesSub?.cancel();
    _patientLogsSub?.cancel();
    _patientMedicationsSub?.cancel();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
