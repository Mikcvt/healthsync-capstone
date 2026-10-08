import 'package:flutter/material.dart';
import '../models/patient_medication_model.dart';
import '../models/schedule_model.dart';
import '../services/firestore_service.dart';

class ScheduleProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  // Wizard Step 1: Basic Info
  String _medicationName = '';
  String _genericName = '';
  String _dosageForm = 'Tablet';
  String _prescribedDosage = '500mg';
  int _quantityPerDose = 1;
  String _prescribingDoctor = '';
  String _purpose = '';
  String _colorLabel = '#1B5FD4';

  // Wizard Step 2: Timing & Frequency
  List<String> _scheduledTimes = ['08:00 AM'];
  List<int> _daysOfWeek = [1, 2, 3, 4, 5, 6, 7];
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  String _instructions = 'Take after meals';

  // Wizard Step 3: Smart Box Compartment & Stock
  int _matBoxColumn = 1;
  int _pillsRemaining = 30;
  int _lowStockThreshold = 5;

  /// Set when a caregiver is authoring on a patient's behalf, so the wizard
  /// writes to that patient rather than to the signed-in user. Null means the
  /// caregiver is authoring for the signed-in account itself.
  String? _targetPatientUid;
  String? _targetPatientName;

  String? get targetPatientUid => _targetPatientUid;
  String? get targetPatientName => _targetPatientName;
  bool get isAuthoringForPatient => _targetPatientUid != null;

  /// Points the wizard at [uid]. Call before pushing step 1, and clear it when
  /// the caregiver leaves the flow — a stale target would silently write the
  /// next medicine to the wrong person.
  void setTargetPatient({required String uid, required String name}) {
    _targetPatientUid = uid;
    _targetPatientName = name;
    notifyListeners();
  }

  void clearTargetPatient() {
    _targetPatientUid = null;
    _targetPatientName = null;
    notifyListeners();
  }

  /// The uid the wizard should save to: the targeted patient when a caregiver
  /// is authoring, otherwise the signed-in user.
  String resolveSaveUid(String currentUid) => _targetPatientUid ?? currentUid;

  bool _isSaving = false;
  String? _errorMessage;

  // Getters
  String get medicationName => _medicationName;
  String get genericName => _genericName;
  String get dosageForm => _dosageForm;
  String get prescribedDosage => _prescribedDosage;
  int get quantityPerDose => _quantityPerDose;
  String get prescribingDoctor => _prescribingDoctor;
  String get purpose => _purpose;
  String get colorLabel => _colorLabel;

  List<String> get scheduledTimes => _scheduledTimes;
  List<int> get daysOfWeek => _daysOfWeek;
  DateTime get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String get instructions => _instructions;

  int get matBoxColumn => _matBoxColumn;
  int get pillsRemaining => _pillsRemaining;
  int get lowStockThreshold => _lowStockThreshold;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  // Setters for Step 1
  void updateStep1({
    required String medicationName,
    String genericName = '',
    String dosageForm = 'Tablet',
    String prescribedDosage = '500mg',
    int quantityPerDose = 1,
    String prescribingDoctor = '',
    String purpose = '',
    String colorLabel = '#1B5FD4',
  }) {
    _medicationName = medicationName;
    _genericName = genericName;
    _dosageForm = dosageForm;
    _prescribedDosage = prescribedDosage;
    _quantityPerDose = quantityPerDose;
    _prescribingDoctor = prescribingDoctor;
    _purpose = purpose;
    _colorLabel = colorLabel;
    notifyListeners();
  }

  // Setters for Step 2
  void updateStep2({
    required List<String> scheduledTimes,
    List<int>? daysOfWeek,
    DateTime? startDate,
    DateTime? endDate,
    String instructions = 'Take after meals',
  }) {
    _scheduledTimes = scheduledTimes;
    if (daysOfWeek != null) _daysOfWeek = daysOfWeek;
    if (startDate != null) _startDate = startDate;
    _endDate = endDate;
    _instructions = instructions;
    notifyListeners();
  }

  // Setters for Step 3
  void updateStep3({
    required int matBoxColumn,
    int pillsRemaining = 30,
    int lowStockThreshold = 5,
  }) {
    _matBoxColumn = matBoxColumn;
    _pillsRemaining = pillsRemaining;
    _lowStockThreshold = lowStockThreshold;
    notifyListeners();
  }

  // Save new medication and schedules
  Future<bool> saveNewMedication(String patientUid) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Create PatientMedicationModel
      final patMed = PatientMedicationModel(
        patMedId: '',
        patientRef: patientUid,
        medicationRef: '',
        medicationName: _medicationName.trim(),
        prescribedDosage: _prescribedDosage.trim(),
        quantityPerDose: _quantityPerDose,
        instructions: _instructions.trim(),
        prescribingDoctor: _prescribingDoctor.trim(),
        purpose: _purpose.trim(),
        colorLabel: _colorLabel,
        datePrescribed: DateTime.now(),
        startDate: _startDate,
        endDate: _endDate,
        isActive: true,
      );

      final patMedId = await _firestoreService.addPatientMedication(patMed);

      // 2. Create Schedule(s) for each scheduled time
      for (final time in _scheduledTimes) {
        final schedule = ScheduleModel(
          scheduleId: '',
          patMedRef: patMedId,
          patientRef: patientUid,
          scheduledTime: time,
          daysOfWeek: _daysOfWeek,
          matBoxColumn: _matBoxColumn,
          caregiverDoctor: _prescribingDoctor.trim(),
          startDate: _startDate,
          endDate: _endDate,
          pillsRemaining: _pillsRemaining,
          lowStockThreshold: _lowStockThreshold,
          ledActive: false,
          isActive: true,
        );
        await _firestoreService.addSchedule(schedule);
      }

      _isSaving = false;
      resetForm();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  void resetForm() {
    _medicationName = '';
    _genericName = '';
    _dosageForm = 'Tablet';
    _prescribedDosage = '500mg';
    _quantityPerDose = 1;
    _prescribingDoctor = '';
    _purpose = '';
    _colorLabel = '#1B5FD4';
    _scheduledTimes = ['08:00 AM'];
    _daysOfWeek = [1, 2, 3, 4, 5, 6, 7];
    _startDate = DateTime.now();
    _endDate = null;
    _instructions = 'Take after meals';
    _matBoxColumn = 1;
    _pillsRemaining = 30;
    _lowStockThreshold = 5;
    _isSaving = false;
    _errorMessage = null;
    notifyListeners();
  }
}
