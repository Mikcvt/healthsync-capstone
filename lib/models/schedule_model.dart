import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleModel {
  final String scheduleId;
  final String patMedRef;
  final String patientRef;
  final String scheduledTime; // e.g. "08:00 AM" or "08:00"
  final List<int> daysOfWeek; // 1 = Monday, 7 = Sunday
  final int matBoxColumn; // 1–8
  final String caregiverDoctor;
  final DateTime startDate;
  final DateTime? endDate;
  final int pillsRemaining;
  final int lowStockThreshold;
  final bool ledActive;
  final bool isActive;

  const ScheduleModel({
    required this.scheduleId,
    required this.patMedRef,
    this.patientRef = '',
    required this.scheduledTime,
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    this.matBoxColumn = 1,
    this.caregiverDoctor = '',
    required this.startDate,
    this.endDate,
    this.pillsRemaining = 30,
    this.lowStockThreshold = 5,
    this.ledActive = false,
    this.isActive = true,
  });

  bool get isLowStock => pillsRemaining <= lowStockThreshold;

  factory ScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ScheduleModel.fromMap(data, doc.id);
  }

  factory ScheduleModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return ScheduleModel(
      scheduleId: id ?? (map['schedule_id'] as String? ?? ''),
      patMedRef: map['pat_med_ref'] as String? ?? '',
      patientRef: map['patient_ref'] as String? ?? '',
      scheduledTime: map['scheduled_time'] as String? ?? '08:00 AM',
      daysOfWeek: (map['days_of_week'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [1, 2, 3, 4, 5, 6, 7],
      matBoxColumn: (map['mat_box_column'] as num?)?.toInt() ?? 1,
      caregiverDoctor: map['caregiver_doctor'] as String? ?? '',
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
      pillsRemaining: (map['pills_remaining'] as num?)?.toInt() ?? 30,
      lowStockThreshold: (map['low_stock_threshold'] as num?)?.toInt() ?? 5,
      ledActive: map['led_active'] as bool? ?? false,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schedule_id': scheduleId,
      'pat_med_ref': patMedRef,
      'patient_ref': patientRef,
      'scheduled_time': scheduledTime,
      'days_of_week': daysOfWeek,
      'mat_box_column': matBoxColumn,
      'caregiver_doctor': caregiverDoctor,
      'start_date': Timestamp.fromDate(startDate),
      'end_date': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'pills_remaining': pillsRemaining,
      'low_stock_threshold': lowStockThreshold,
      'led_active': ledActive,
      'is_active': isActive,
    };
  }

  ScheduleModel copyWith({
    String? scheduleId,
    String? patMedRef,
    String? patientRef,
    String? scheduledTime,
    List<int>? daysOfWeek,
    int? matBoxColumn,
    String? caregiverDoctor,
    DateTime? startDate,
    DateTime? endDate,
    int? pillsRemaining,
    int? lowStockThreshold,
    bool? ledActive,
    bool? isActive,
  }) {
    return ScheduleModel(
      scheduleId: scheduleId ?? this.scheduleId,
      patMedRef: patMedRef ?? this.patMedRef,
      patientRef: patientRef ?? this.patientRef,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      matBoxColumn: matBoxColumn ?? this.matBoxColumn,
      caregiverDoctor: caregiverDoctor ?? this.caregiverDoctor,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      pillsRemaining: pillsRemaining ?? this.pillsRemaining,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      ledActive: ledActive ?? this.ledActive,
      isActive: isActive ?? this.isActive,
    );
  }
}
