import 'package:cloud_firestore/cloud_firestore.dart';

class PatientMedicationModel {
  final String patMedId;
  final String patientRef;
  final String medicationRef;
  final String medicationName; // Cached for UI display
  final String prescribedDosage; // e.g., "500mg"
  final int quantityPerDose; // e.g., 1 pill
  final String instructions; // e.g., "Take after meal"
  final String prescribingDoctor;
  final String purpose;
  final String colorLabel; // Hex color string or color name
  final DateTime datePrescribed;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;

  /// Why it left the regimen: 'completed' or 'mistake'. Empty while active.
  final String archivedReason;

  const PatientMedicationModel({
    required this.patMedId,
    required this.patientRef,
    required this.medicationRef,
    this.medicationName = '',
    this.prescribedDosage = '',
    this.quantityPerDose = 1,
    this.instructions = '',
    this.prescribingDoctor = '',
    this.purpose = '',
    this.colorLabel = '#1B5FD4',
    required this.datePrescribed,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    this.archivedReason = '',
  });

  factory PatientMedicationModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return PatientMedicationModel.fromMap(data, doc.id);
  }

  factory PatientMedicationModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return PatientMedicationModel(
      patMedId: id ?? (map['pat_med_id'] as String? ?? ''),
      patientRef: map['patient_ref'] as String? ?? '',
      medicationRef: map['medication_ref'] as String? ?? '',
      medicationName: map['medication_name'] as String? ?? '',
      prescribedDosage: map['prescribed_dosage'] as String? ?? '',
      quantityPerDose: (map['quantity_per_dose'] as num?)?.toInt() ?? 1,
      instructions: map['instructions'] as String? ?? '',
      prescribingDoctor: map['prescribing_doctor'] as String? ?? '',
      purpose: map['purpose'] as String? ?? '',
      colorLabel: map['color_label'] as String? ?? '#1B5FD4',
      datePrescribed: map['date_prescribed'] is Timestamp
          ? (map['date_prescribed'] as Timestamp).toDate()
          : (map['date_prescribed'] != null
              ? DateTime.tryParse(map['date_prescribed'].toString()) ?? DateTime.now()
              : DateTime.now()),
      startDate: map['start_date'] is Timestamp
          ? (map['start_date'] as Timestamp).toDate()
          : (map['start_date'] != null
              ? DateTime.tryParse(map['start_date'].toString()) ?? DateTime.now()
              : DateTime.now()),
      endDate: map['end_date'] is Timestamp
          ? (map['end_date'] as Timestamp).toDate()
          : (map['end_date'] != null
              ? DateTime.tryParse(map['end_date'].toString())
              : null),
      isActive: map['is_active'] as bool? ?? true,
      archivedReason: map['archived_reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pat_med_id': patMedId,
      'patient_ref': patientRef,
      'medication_ref': medicationRef,
      'medication_name': medicationName,
      'prescribed_dosage': prescribedDosage,
      'quantity_per_dose': quantityPerDose,
      'instructions': instructions,
      'prescribing_doctor': prescribingDoctor,
      'purpose': purpose,
      'color_label': colorLabel,
      'date_prescribed': Timestamp.fromDate(datePrescribed),
      'start_date': Timestamp.fromDate(startDate),
      'end_date': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'is_active': isActive,
      'archived_reason': archivedReason,
    };
  }

  PatientMedicationModel copyWith({
    String? patMedId,
    String? patientRef,
    String? medicationRef,
    String? medicationName,
    String? prescribedDosage,
    int? quantityPerDose,
    String? instructions,
    String? prescribingDoctor,
    String? purpose,
    String? colorLabel,
    DateTime? datePrescribed,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    String? archivedReason,
  }) {
    return PatientMedicationModel(
      patMedId: patMedId ?? this.patMedId,
      patientRef: patientRef ?? this.patientRef,
      medicationRef: medicationRef ?? this.medicationRef,
      medicationName: medicationName ?? this.medicationName,
      prescribedDosage: prescribedDosage ?? this.prescribedDosage,
      quantityPerDose: quantityPerDose ?? this.quantityPerDose,
      instructions: instructions ?? this.instructions,
      prescribingDoctor: prescribingDoctor ?? this.prescribingDoctor,
      purpose: purpose ?? this.purpose,
      colorLabel: colorLabel ?? this.colorLabel,
      datePrescribed: datePrescribed ?? this.datePrescribed,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      archivedReason: archivedReason ?? this.archivedReason,
    );
  }
}
