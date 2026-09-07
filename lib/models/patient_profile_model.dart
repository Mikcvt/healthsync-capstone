import 'package:cloud_firestore/cloud_firestore.dart';

class PatientProfileModel {
  final String profileId;
  final String userRef;
  final List<String> medicalConditions;
  final List<String> allergies;
  final String emergencyContact;
  final String emergencyPhone;
  final String? caregiverRef;
  final DateTime? dateOfBirth;
  final String gender;
  final DateTime createdAt;
  final bool isActive;

  const PatientProfileModel({
    required this.profileId,
    required this.userRef,
    this.medicalConditions = const [],
    this.allergies = const [],
    this.emergencyContact = '',
    this.emergencyPhone = '',
    this.caregiverRef,
    this.dateOfBirth,
    this.gender = '',
    required this.createdAt,
    this.isActive = true,
  });

  factory PatientProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return PatientProfileModel.fromMap(data, doc.id);
  }

  factory PatientProfileModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return PatientProfileModel(
      profileId: id ?? (map['profile_id'] as String? ?? ''),
      userRef: map['user_ref'] as String? ?? '',
      medicalConditions: List<String>.from(map['medical_conditions'] ?? []),
      allergies: List<String>.from(map['allergies'] ?? []),
      emergencyContact: map['emergency_contact'] as String? ?? '',
      emergencyPhone: map['emergency_phone'] as String? ?? '',
      caregiverRef: map['caregiver_ref'] as String?,
      dateOfBirth: map['date_of_birth'] is Timestamp
          ? (map['date_of_birth'] as Timestamp).toDate()
          : (map['date_of_birth'] != null
              ? DateTime.tryParse(map['date_of_birth'].toString())
              : null),
      gender: map['gender'] as String? ?? '',
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
      'profile_id': profileId,
      'user_ref': userRef,
      'medical_conditions': medicalConditions,
      'allergies': allergies,
      'emergency_contact': emergencyContact,
      'emergency_phone': emergencyPhone,
      'caregiver_ref': caregiverRef,
      'date_of_birth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'gender': gender,
      'created_at': Timestamp.fromDate(createdAt),
      'is_active': isActive,
    };
  }

  PatientProfileModel copyWith({
    String? profileId,
    String? userRef,
    List<String>? medicalConditions,
    List<String>? allergies,
    String? emergencyContact,
    String? emergencyPhone,
    String? caregiverRef,
    DateTime? dateOfBirth,
    String? gender,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return PatientProfileModel(
      profileId: profileId ?? this.profileId,
      userRef: userRef ?? this.userRef,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      allergies: allergies ?? this.allergies,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      caregiverRef: caregiverRef ?? this.caregiverRef,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
