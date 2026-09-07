import 'dart:async';
import 'package:flutter/material.dart';
import '../models/caregiver_profile_model.dart';
import '../models/caregiver_patient_link_model.dart';
import '../models/patient_profile_model.dart';
import '../models/user_model.dart';
import '../models/schedule_model.dart';
import '../models/dose_log_model.dart';
import '../services/firestore_service.dart';

class CaregiverProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  String? _caregiverUid;
  CaregiverProfileModel? _profile;
  List<CaregiverPatientLinkModel> _patientLinks = [];
  String? _selectedPatientUid;
  UserModel? _selectedPatientUser;
  PatientProfileModel? _selectedPatientProfile;
  List<ScheduleModel> _selectedPatientSchedules = [];
  List<DoseLogModel> _selectedPatientLogs = [];
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription? _profileSub;
  StreamSubscription? _linksSub;
  StreamSubscription? _patientSchedulesSub;
  StreamSubscription? _patientLogsSub;

  CaregiverProfileModel? get profile => _profile;
  List<CaregiverPatientLinkModel> get patientLinks => _patientLinks;
  String? get selectedPatientUid => _selectedPatientUid;
  UserModel? get selectedPatientUser => _selectedPatientUser;
  PatientProfileModel? get selectedPatientProfile => _selectedPatientProfile;
  List<ScheduleModel> get selectedPatientSchedules => _selectedPatientSchedules;
  List<DoseLogModel> get selectedPatientLogs => _selectedPatientLogs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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
    _linksSub = _firestoreService.streamCaregiverLinks(uid).listen((links) async {
      _patientLinks = links;
      if (_selectedPatientUid == null && links.isNotEmpty) {
        selectPatient(links.first.patientRef);
      }
      notifyListeners();
    });
  }

  // Select active patient to monitor
  Future<void> selectPatient(String patientUid) async {
    _selectedPatientUid = patientUid;
    _patientSchedulesSub?.cancel();
    _patientLogsSub?.cancel();

    // Fetch user & profile info
    _selectedPatientUser = await _firestoreService.getUser(patientUid);
    _selectedPatientProfile = await _firestoreService.getPatientProfile(patientUid);

    // Stream schedules
    _patientSchedulesSub = _firestoreService.streamPatientSchedules(patientUid).listen((schs) {
      _selectedPatientSchedules = schs;
      notifyListeners();
    });

    // Stream logs
    _patientLogsSub = _firestoreService.streamPatientDoseLogs(patientUid).listen((logs) {
      _selectedPatientLogs = logs;
      notifyListeners();
    });

    notifyListeners();
  }

  // Link a new patient via invite code
  Future<bool> linkPatient(String inviteCode) async {
    if (_caregiverUid == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final link = await _firestoreService.linkByInviteCode(
        caregiverUid: _caregiverUid!,
        inviteCode: inviteCode,
      );

      _isLoading = false;
      if (link != null) {
        await selectPatient(link.patientRef);
        return true;
      } else {
        _errorMessage = 'Invalid or expired invite code. Please check with your patient.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update alert preferences
  Future<void> updateAlertPreferences({
    bool? alertPrefMissed,
    bool? alertPrefVitals,
    bool? alertPrefDaily,
  }) async {
    if (_profile == null || _caregiverUid == null) return;
    final updated = _profile!.copyWith(
      alertPrefMissed: alertPrefMissed,
      alertPrefVitals: alertPrefVitals,
      alertPrefDaily: alertPrefDaily,
    );
    await _firestoreService.setCaregiverProfile(updated);
    _profile = updated;
    notifyListeners();
  }

  void _cancelSubscriptions() {
    _profileSub?.cancel();
    _linksSub?.cancel();
    _patientSchedulesSub?.cancel();
    _patientLogsSub?.cancel();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
