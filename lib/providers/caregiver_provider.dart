import 'dart:async';
import 'package:flutter/material.dart';
import '../models/caregiver_profile_model.dart';
import '../models/caregiver_patient_link_model.dart';
import '../models/patient_profile_model.dart';
import '../models/user_model.dart';
import '../models/schedule_model.dart';
import '../models/dose_log_model.dart';
import '../models/otp_code_model.dart';
import '../services/api_service.dart';
import '../services/firestore_service.dart';

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
  bool get hasLinkedPatients => _patientLinks.isNotEmpty;
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

  // Unlink a patient
  Future<void> unlinkPatient(String linkId, String patientUid) async {
    await _firestoreService.unlinkCaregiverPatient(linkId, patientUid);
    if (_selectedPatientUid == patientUid) {
      _selectedPatientUid = null;
      _selectedPatientUser = null;
      _selectedPatientProfile = null;
      _selectedPatientSchedules = [];
      _selectedPatientLogs = [];
      _patientSchedulesSub?.cancel();
      _patientLogsSub?.cancel();
    }
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
