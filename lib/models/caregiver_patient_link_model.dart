import 'package:cloud_firestore/cloud_firestore.dart';

class CaregiverPatientLinkModel {
  final String linkId;
  final String caregiverRef;
  final String patientRef;
  final String inviteCode;
  final DateTime linkedSince;
  final String linkedBy;
  final String status; // 'active', 'pending', 'rejected', 'inactive'
  final bool canViewVitals;
  final bool canViewSchedule;
  final bool canReceiveAlerts;
  final DateTime createdAt;
  final bool isActive;

  const CaregiverPatientLinkModel({
    required this.linkId,
    required this.caregiverRef,
    required this.patientRef,
    this.inviteCode = '',
    required this.linkedSince,
    this.linkedBy = 'caregiver',
    this.status = 'active',
    this.canViewVitals = true,
    this.canViewSchedule = true,
    this.canReceiveAlerts = true,
    required this.createdAt,
    this.isActive = true,
  });

  bool get isApproved => status == 'active';
  bool get isPending => status == 'pending';

  factory CaregiverPatientLinkModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return CaregiverPatientLinkModel.fromMap(data, doc.id);
  }

  factory CaregiverPatientLinkModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return CaregiverPatientLinkModel(
      linkId: id ?? (map['link_id'] as String? ?? ''),
      caregiverRef: map['caregiver_ref'] as String? ?? '',
      patientRef: map['patient_ref'] as String? ?? '',
      inviteCode: map['invite_code'] as String? ?? '',
      linkedSince: map['linked_since'] is Timestamp
          ? (map['linked_since'] as Timestamp).toDate()
          : (map['linked_since'] != null
              ? DateTime.tryParse(map['linked_since'].toString()) ?? DateTime.now()
              : DateTime.now()),
      linkedBy: map['linked_by'] as String? ?? 'caregiver',
      status: map['status'] as String? ?? 'active',
      canViewVitals: map['can_view_vitals'] as bool? ?? true,
      canViewSchedule: map['can_view_schedule'] as bool? ?? true,
      canReceiveAlerts: map['can_receive_alerts'] as bool? ?? true,
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
      'link_id': linkId,
      'caregiver_ref': caregiverRef,
      'patient_ref': patientRef,
      'invite_code': inviteCode,
      'linked_since': Timestamp.fromDate(linkedSince),
      'linked_by': linkedBy,
      'status': status,
      'can_view_vitals': canViewVitals,
      'can_view_schedule': canViewSchedule,
      'can_receive_alerts': canReceiveAlerts,
      'created_at': Timestamp.fromDate(createdAt),
      'is_active': isActive,
    };
  }

  CaregiverPatientLinkModel copyWith({
    String? linkId,
    String? caregiverRef,
    String? patientRef,
    String? inviteCode,
    DateTime? linkedSince,
    String? linkedBy,
    String? status,
    bool? canViewVitals,
    bool? canViewSchedule,
    bool? canReceiveAlerts,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return CaregiverPatientLinkModel(
      linkId: linkId ?? this.linkId,
      caregiverRef: caregiverRef ?? this.caregiverRef,
      patientRef: patientRef ?? this.patientRef,
      inviteCode: inviteCode ?? this.inviteCode,
      linkedSince: linkedSince ?? this.linkedSince,
      linkedBy: linkedBy ?? this.linkedBy,
      status: status ?? this.status,
      canViewVitals: canViewVitals ?? this.canViewVitals,
      canViewSchedule: canViewSchedule ?? this.canViewSchedule,
      canReceiveAlerts: canReceiveAlerts ?? this.canReceiveAlerts,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
