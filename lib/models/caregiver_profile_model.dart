import 'package:cloud_firestore/cloud_firestore.dart';

class CaregiverProfileModel {
  final String profileId;
  final String userRef;
  final bool alertPrefMissed;
  final bool alertPrefLowStock;
  final bool alertPrefDaily;
  final DateTime createdAt;
  final bool isActive;

  const CaregiverProfileModel({
    required this.profileId,
    required this.userRef,
    this.alertPrefMissed = true,
    this.alertPrefLowStock = true,
    this.alertPrefDaily = true,
    required this.createdAt,
    this.isActive = true,
  });

  factory CaregiverProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return CaregiverProfileModel.fromMap(data, doc.id);
  }

  factory CaregiverProfileModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return CaregiverProfileModel(
      profileId: id ?? (map['profile_id'] as String? ?? ''),
      userRef: map['user_ref'] as String? ?? '',
      alertPrefMissed: map['alert_pref_missed'] as bool? ?? true,
      alertPrefLowStock: map['alert_pref_low_stock'] as bool? ?? true,
      alertPrefDaily: map['alert_pref_daily'] as bool? ?? true,
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
      'alert_pref_missed': alertPrefMissed,
      'alert_pref_low_stock': alertPrefLowStock,
      'alert_pref_daily': alertPrefDaily,
      'created_at': Timestamp.fromDate(createdAt),
      'is_active': isActive,
    };
  }

  CaregiverProfileModel copyWith({
    String? profileId,
    String? userRef,
    bool? alertPrefMissed,
    bool? alertPrefLowStock,
    bool? alertPrefDaily,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return CaregiverProfileModel(
      profileId: profileId ?? this.profileId,
      userRef: userRef ?? this.userRef,
      alertPrefMissed: alertPrefMissed ?? this.alertPrefMissed,
      alertPrefLowStock: alertPrefLowStock ?? this.alertPrefLowStock,
      alertPrefDaily: alertPrefDaily ?? this.alertPrefDaily,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
