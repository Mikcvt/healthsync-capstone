import 'package:cloud_firestore/cloud_firestore.dart';

/// Account types. A user's capabilities are driven by [accountType], never by
/// [role] — `role` is kept only so documents written before the account-type
/// redesign still load.
///
/// There are two roles: a caregiver who authors a patient's regimen, and a
/// managed patient who confirms doses. A third self-managing "solo" type was
/// scaffolded and has been removed; [_deriveAccountType] still maps any
/// document left carrying it.
class AccountType {
  static const String managed = 'managed';
  static const String caregiver = 'caregiver';
}

class UserModel {
  final String uid;
  final String role; // 'patient' | 'caregiver'
  final String accountType; // 'managed' | 'caregiver'
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final bool canEditMedications;
  final DateTime createdAt;
  final bool isActive;

  /// Set when the patient has asked to delete their account. Their caregiver
  /// must approve before anything is removed.
  final DateTime? deletionRequestedAt;

  const UserModel({
    required this.uid,
    required this.role,
    required this.accountType,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone = '',
    required this.canEditMedications,
    required this.createdAt,
    this.isActive = true,
    this.deletionRequestedAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  bool get isPatient => role == 'patient';
  bool get isCaregiver => accountType == AccountType.caregiver;
  bool get isManaged => accountType == AccountType.managed;

  /// Whether this patient is waiting on their caregiver to approve deletion.
  bool get hasPendingDeletion => deletionRequestedAt != null;

  /// A managed patient has no real email address — their account was created by
  /// a caregiver and they sign in with an OTP-minted custom token. Used to skip
  /// the email-verification gate in [AuthGate].
  bool get requiresEmailVerification => !isManaged;

  /// Back-fills [accountType] for documents written before the redesign.
  ///
  /// A stored `'solo'` is mapped to [AccountType.managed] rather than kept:
  /// the type no longer exists, and resolving an unknown account to the
  /// read-only side is the safe direction to fail. Pairing that with
  /// [_deriveCanEdit] means such an account cannot author medications.
  static String _deriveAccountType(String role, Object? stored) {
    if (stored is String && stored.isNotEmpty) {
      return stored == 'solo' ? AccountType.managed : stored;
    }
    return role == 'caregiver' ? AccountType.caregiver : AccountType.managed;
  }

  /// Only caregivers may author medications. A managed patient is read-only by
  /// design, so an absent field must resolve to `false` for them rather than
  /// defaulting open.
  static bool _deriveCanEdit(String accountType, Object? stored) {
    if (stored is bool) return stored;
    return accountType != AccountType.managed;
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return UserModel.fromMap(data, doc.id);
  }

  factory UserModel.fromMap(Map<String, dynamic> map, [String? id]) {
    final role = map['role'] as String? ?? 'patient';
    final accountType = _deriveAccountType(role, map['account_type']);
    return UserModel(
      uid: id ?? (map['uid'] as String? ?? ''),
      role: role,
      accountType: accountType,
      firstName: map['first_name'] as String? ?? '',
      lastName: map['last_name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      canEditMedications: _deriveCanEdit(
        accountType,
        map['can_edit_medications'],
      ),
      createdAt: map['created_at'] is Timestamp
          ? (map['created_at'] as Timestamp).toDate()
          : (map['created_at'] != null
              ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
      isActive: map['is_active'] as bool? ?? true,
      deletionRequestedAt: map['deletion_requested_at'] is Timestamp
          ? (map['deletion_requested_at'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'role': role,
      'account_type': accountType,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'can_edit_medications': canEditMedications,
      'created_at': Timestamp.fromDate(createdAt),
      'is_active': isActive,
    };
  }

  UserModel copyWith({
    String? uid,
    String? role,
    String? accountType,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    bool? canEditMedications,
    DateTime? createdAt,
    bool? isActive,
    DateTime? deletionRequestedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      accountType: accountType ?? this.accountType,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      canEditMedications: canEditMedications ?? this.canEditMedications,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      deletionRequestedAt: deletionRequestedAt ?? this.deletionRequestedAt,
    );
  }
}
