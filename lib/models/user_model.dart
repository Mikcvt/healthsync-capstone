import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String role; // 'patient' or 'caregiver'
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final DateTime createdAt;
  final bool isActive;

  const UserModel({
    required this.uid,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone = '',
    required this.createdAt,
    this.isActive = true,
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get isPatient => role == 'patient';
  bool get isCaregiver => role == 'caregiver';

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return UserModel.fromMap(data, doc.id);
  }

  factory UserModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return UserModel(
      uid: id ?? (map['uid'] as String? ?? ''),
      role: map['role'] as String? ?? 'patient',
      firstName: map['first_name'] as String? ?? '',
      lastName: map['last_name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
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
      'uid': uid,
      'role': role,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'created_at': Timestamp.fromDate(createdAt),
      'is_active': isActive,
    };
  }

  UserModel copyWith({
    String? uid,
    String? role,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
