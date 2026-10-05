import 'dart:async';
import 'package:flutter/material.dart';
import '../models/patient_profile_model.dart';
import '../models/patient_medication_model.dart';
import '../models/schedule_model.dart';
import '../models/dose_log_model.dart';
import '../models/device_model.dart';
import '../models/caregiver_patient_link_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class PatientProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  String? _patientUid;
  PatientProfileModel? _profile;
  List<PatientMedicationModel> _medications = [];
  List<ScheduleModel> _schedules = [];
  List<DoseLogModel> _todayLogs = [];
  List<DoseLogModel> _allLogs = [];
  DeviceModel? _device;
  CaregiverPatientLinkModel? _link;
  UserModel? _caregiverUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Stream Subscriptions
  StreamSubscription? _profileSub;
  StreamSubscription? _medicationsSub;
  StreamSubscription? _schedulesSub;
  StreamSubscription? _todayLogsSub;
  StreamSubscription? _allLogsSub;
  StreamSubscription? _deviceSub;
  StreamSubscription? _linksSub;

  // Getters
  PatientProfileModel? get profile => _profile;
  List<PatientMedicationModel> get medications => _medications;
  List<ScheduleModel> get schedules => _schedules;
  List<DoseLogModel> get todayLogs => _todayLogs;
  List<DoseLogModel> get allLogs => _allLogs;
  DeviceModel? get device => _device;
  CaregiverPatientLinkModel? get link => _link;
  UserModel? get caregiverUser => _caregiverUser;
  bool get isLinkedToCaregiver => _link != null && _link!.status == 'active';
  bool get isLinkPending => _link != null && _link!.status == 'pending';
  String? get inviteCode => _link?.inviteCode;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Calculate adherence percentage for today
  double get todayAdherencePercentage {
    if (_todayLogs.isEmpty) return 100.0;
    final takenCount = _todayLogs.where((l) => l.isTaken).length;
    final totalResolved = _todayLogs.where((l) => l.isTaken || l.isMissed).length;
    if (totalResolved == 0) return 100.0;
    return (takenCount / totalResolved) * 100.0;
  }

  // Calculate overall adherence percentage
  double get overallAdherencePercentage {
    if (_allLogs.isEmpty) return 100.0;
    final takenCount = _allLogs.where((l) => l.isTaken).length;
    final totalResolved = _allLogs.where((l) => l.isTaken || l.isMissed).length;
    if (totalResolved == 0) return 100.0;
    return (takenCount / totalResolved) * 100.0;
  }

  // Next upcoming dose
  ScheduleModel? get nextDueDose {
    if (_schedules.isEmpty) return null;
    return _schedules.first;
  }

  void initForPatient(String uid) {
    if (_patientUid == uid) return;
    _patientUid = uid;
    _cancelSubscriptions();

    _isLoading = true;
    notifyListeners();

    final todayStr = _formatDate(DateTime.now());

    // Listen to profile
    _profileSub = _firestoreService.streamPatientProfile(uid).listen((p) {
      _profile = p;
      notifyListeners();
    });

    // Listen to medications
    _medicationsSub = _firestoreService.streamPatientMedications(uid).listen((meds) {
      _medications = meds;
      notifyListeners();
    });

    // Listen to schedules
    _schedulesSub = _firestoreService.streamPatientSchedules(uid).listen((schs) {
      _schedules = schs;
      notifyListeners();
    });

    // Listen to today's dose logs
    _todayLogsSub = _firestoreService.streamPatientDoseLogs(uid, dateStr: todayStr).listen((logs) {
      _todayLogs = logs;
      notifyListeners();
    });

    // Listen to all dose history
    _allLogsSub = _firestoreService.streamPatientDoseLogs(uid).listen((logs) {
      _allLogs = logs;
      notifyListeners();
    });

    // Listen to device
    _deviceSub = _firestoreService.streamPatientDevice(uid).listen((dev) {
      _device = dev;
      notifyListeners();
    });

    // Listen to caregiver links
    _linksSub = _firestoreService.streamPatientLinks(uid).listen((links) async {
      if (links.isNotEmpty) {
        final active = links.where((l) => l.status == 'active').firstOrNull;
        _link = active ?? links.first;
        if (_link != null && _link!.caregiverRef.isNotEmpty) {
          _caregiverUser = await _firestoreService.getUser(_link!.caregiverRef);
        } else {
          _caregiverUser = null;
        }
      } else {
        _link = null;
        _caregiverUser = null;
      }
      notifyListeners();
    });

    _isLoading = false;
    notifyListeners();
  }

  /// Confirms a dose was taken, from the app or the box button.
  ///
  /// Returns false and sets [errorMessage] on failure rather than throwing —
  /// an uncaught error here left the patient looking at an unchanged screen
  /// with no idea the confirmation had not been recorded.
  Future<bool> confirmDoseTaken({
    required String scheduleId,
    String? doseLogId,
    int matBoxColumn = 1,
    String confirmedVia = 'app',
  }) async {
    _errorMessage = null;
    try {
      await _confirmDoseTaken(
        scheduleId: scheduleId,
        doseLogId: doseLogId,
        confirmedVia: confirmedVia,
      );
      return true;
    } catch (e) {
      _errorMessage = 'Could not record this dose. Please try again.';
      debugPrint('confirmDoseTaken failed: $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> _confirmDoseTaken({
    required String scheduleId,
    String? doseLogId,
    String confirmedVia = 'app',
  }) async {
    final now = DateTime.now();
    final todayStr = _formatDate(now);

    // 1. Turn off LED for the compartment
    await _firestoreService.updateScheduleLed(scheduleId, false);

    // 2. Decrement remaining pills
    await _firestoreService.decrementPillsRemaining(scheduleId, 1);

    // 3. Update or create dose log
    if (doseLogId != null && doseLogId.isNotEmpty) {
      await _firestoreService.updateDoseLogStatus(
        doseLogId: doseLogId,
        status: 'taken',
        takenAt: now,
        caregiverNotified: true,
      );
    } else {
      final newLog = DoseLogModel(
        doseLogId: '',
        scheduleRef: scheduleId,
        patientRef: _patientUid ?? '',
        scheduledDate: todayStr,
        scheduledTime: _formatTime(now),
        status: 'taken',
        takenAt: now,
        confirmedVia: confirmedVia,
        caregiverNotified: true,
        createdAt: now,
      );
      await _firestoreService.recordDoseLog(newLog);
    }
    notifyListeners();
  }

  // Snooze dose (+10 mins)
  Future<void> snoozeDose(String doseLogId, int currentSnoozeCount) async {
    if (currentSnoozeCount >= 3) {
      // Exceeded max snoozes -> mark missed
      await markDoseMissed(doseLogId, reason: 'Exceeded max snooze limit (3x)');
      return;
    }

    await _firestoreService.updateDoseLogStatus(
      doseLogId: doseLogId,
      status: 'snoozed',
      snoozeCount: currentSnoozeCount + 1,
    );
    notifyListeners();
  }

  // Mark dose missed
  Future<void> markDoseMissed(String doseLogId, {String reason = 'No response'}) async {
    await _firestoreService.updateDoseLogStatus(
      doseLogId: doseLogId,
      status: 'missed',
      skippedReason: reason,
      caregiverNotified: true,
    );
    notifyListeners();
  }

  // Update profile
  Future<void> saveProfile(PatientProfileModel updated) async {
    await _firestoreService.setPatientProfile(updated);
    _profile = updated;
    notifyListeners();
  }

  // Pair IoT Smart Medicine Box
  Future<void> pairSmartBox(String serialNumber, {String deviceName = 'HealthSync Box'}) async {
    if (_patientUid == null) return;
    await _firestoreService.pairDevice(
      patientUid: _patientUid!,
      serialNumber: serialNumber,
      deviceName: deviceName,
    );
    notifyListeners();
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }


  // Unlink caregiver
  Future<void> unlinkCaregiver() async {
    if (_link == null || _patientUid == null) return;
    await _firestoreService.unlinkCaregiverPatient(_link!.linkId, _patientUid!);
    _link = null;
    _caregiverUser = null;
    notifyListeners();
  }

  void _cancelSubscriptions() {
    _profileSub?.cancel();
    _medicationsSub?.cancel();
    _schedulesSub?.cancel();
    _todayLogsSub?.cancel();
    _allLogsSub?.cancel();
    _deviceSub?.cancel();
    _linksSub?.cancel();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
