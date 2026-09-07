import 'package:cloud_firestore/cloud_firestore.dart';

class MedicationModel {
  final String medicationId;
  final String medicationName;
  final String genericName;
  final String dosageForm; // e.g., 'Tablet', 'Capsule', 'Syrup', 'Drops'
  final List<String> commonDosages; // e.g., ['500mg', '250mg']
  final String category; // e.g., 'Antibiotic', 'Cardiovascular', 'Painkiller', 'Vitamins'
  final DateTime createdAt;
  final bool isActive;

  const MedicationModel({
    required this.medicationId,
    required this.medicationName,
    this.genericName = '',
    this.dosageForm = 'Tablet',
    this.commonDosages = const [],
    this.category = 'General',
    required this.createdAt,
    this.isActive = true,
  });

  factory MedicationModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return MedicationModel.fromMap(data, doc.id);
  }

  factory MedicationModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return MedicationModel(
      medicationId: id ?? (map['medication_id'] as String? ?? ''),
      medicationName: map['medication_name'] as String? ?? '',
      genericName: map['generic_name'] as String? ?? '',
      dosageForm: map['dosage_form'] as String? ?? 'Tablet',
      commonDosages: List<String>.from(map['common_dosages'] ?? []),
      category: map['category'] as String? ?? 'General',
      createdAt: map['created_at'] is Timestamp
          ? (map['created_at'] as Timestamp).toDate()
          : (map['created_at'] != null
              ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medication_id': medicationId,
      'medication_name': medicationName,
      'generic_name': genericName,
      'dosage_form': dosageForm,
      'common_dosages': commonDosages,
      'category': category,
      'created_at': Timestamp.fromDate(createdAt),
      'is_active': isActive,
    };
  }

  MedicationModel copyWith({
    String? medicationId,
    String? medicationName,
    String? genericName,
    String? dosageForm,
    List<String>? commonDosages,
    String? category,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return MedicationModel(
      medicationId: medicationId ?? this.medicationId,
      medicationName: medicationName ?? this.medicationName,
      genericName: genericName ?? this.genericName,
      dosageForm: dosageForm ?? this.dosageForm,
      commonDosages: commonDosages ?? this.commonDosages,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
