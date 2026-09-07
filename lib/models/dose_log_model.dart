import 'package:cloud_firestore/cloud_firestore.dart';

class DoseLogModel {
  final String doseLogId;
  final String scheduleRef;
  final String patientRef;
  final String scheduledDate; // Format: "YYYY-MM-DD"
  final String scheduledTime; // e.g. "08:00 AM"
  final String status; // 'taken', 'missed', 'snoozed', 'pending'
  final DateTime? takenAt;
  final int snoozeCount;
  final String confirmedVia; // 'app', 'box', 'caregiver'
  final bool caregiverNotified;
  final int doseCount;
  final String skippedReason;
  final String recordedBy;
  final DateTime createdAt;
  final bool isActive;

  const DoseLogModel({
    required this.doseLogId,
    required this.scheduleRef,
    required this.patientRef,
    required this.scheduledDate,
    required this.scheduledTime,
    this.status = 'pending',
    this.takenAt,
    this.snoozeCount = 0,
    this.confirmedVia = 'app',
    this.caregiverNotified = false,
    this.doseCount = 1,
    this.skippedReason = '',
    this.recordedBy = 'patient',
    required this.createdAt,
    this.isActive = true,
  });

  bool get isTaken => status == 'taken';
  bool get isMissed => status == 'missed';
  bool get isSnoozed => status == 'snoozed';
  bool get isPending => status == 'pending';

  factory DoseLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return DoseLogModel.fromMap(data, doc.id);
  }

  factory DoseLogModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return DoseLogModel(
      doseLogId: id ?? (map['dose_log_id'] as String? ?? ''),
      scheduleRef: map['schedule_ref'] as String? ?? '',
      patientRef: map['patient_ref'] as String? ?? '',
      scheduledDate: map['scheduled_date'] as String? ?? '',
      scheduledTime: map['scheduled_time'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      takenAt: map['taken_at'] is Timestamp
          ? (map['taken_at'] as Timestamp).toDate()
          : (map['taken_at'] != null
              ? DateTime.tryParse(map['taken_at'].toString())
              : null),
      snoozeCount: (map['snooze_count'] as num?)?.toInt() ?? 0,
      confirmedVia: map['confirmed_via'] as String? ?? 'app',
      caregiverNotified: map['caregiver_notified'] as bool? ?? false,
      doseCount: (map['dose_count'] as num?)?.toInt() ?? 1,
      skippedReason: map['skipped_reason'] as String? ?? '',
      recordedBy: map['recorded_by'] as String? ?? 'patient',
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
      'dose_log_id': doseLogId,
      'schedule_ref': scheduleRef,
      'patient_ref': patientRef,
      'scheduled_date': scheduledDate,
      'scheduled_time': scheduledTime,
      'status': status,
      'taken_at': takenAt != null ? Timestamp.fromDate(takenAt!) : null,
      'snooze_count': snoozeCount,
      'confirmed_via': confirmedVia,
      'caregiver_notified': caregiverNotified,
      'dose_count': doseCount,
      'skipped_reason': skippedReason,
      'recorded_by': recordedBy,
      'created_at': Timestamp.fromDate(createdAt),
      'is_active': isActive,
    };
  }

  DoseLogModel copyWith({
    String? doseLogId,
    String? scheduleRef,
    String? patientRef,
    String? scheduledDate,
    String? scheduledTime,
    String? status,
    DateTime? takenAt,
    int? snoozeCount,
    String? confirmedVia,
    bool? caregiverNotified,
    int? doseCount,
    String? skippedReason,
    String? recordedBy,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return DoseLogModel(
      doseLogId: doseLogId ?? this.doseLogId,
      scheduleRef: scheduleRef ?? this.scheduleRef,
      patientRef: patientRef ?? this.patientRef,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      status: status ?? this.status,
      takenAt: takenAt ?? this.takenAt,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      confirmedVia: confirmedVia ?? this.confirmedVia,
      caregiverNotified: caregiverNotified ?? this.caregiverNotified,
      doseCount: doseCount ?? this.doseCount,
      skippedReason: skippedReason ?? this.skippedReason,
      recordedBy: recordedBy ?? this.recordedBy,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
