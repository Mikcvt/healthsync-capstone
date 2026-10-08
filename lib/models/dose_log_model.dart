import 'package:cloud_firestore/cloud_firestore.dart';

/// Dose log statuses. `taken`, `skipped`, `missed` and `cancelled` are final;
/// `pending` and `snoozed` still need a decision.
class DoseStatus {
  static const String pending = 'pending';
  static const String snoozed = 'snoozed';
  static const String taken = 'taken';

  /// The patient chose not to take it, and said why.
  static const String skipped = 'skipped';

  /// Nothing was recorded within the missed window.
  static const String missed = 'missed';

  /// The medicine was archived, or the dose time moved, before this dose came
  /// due. Kept for the record, never counted, never shown as a dose.
  static const String cancelled = 'cancelled';
}

/// When a taken dose was taken, relative to its dose time.
class DoseTimingTag {
  /// Confirmed through the early-logging prompt.
  static const String early = 'early';
  static const String onTime = 'on_time';
  static const String late = 'late';

  /// Was missed, then corrected with "I took it but forgot to log it".
  static const String loggedLate = 'logged_late';
}

class DoseLogModel {
  final String doseLogId;
  final String scheduleRef;
  final String patientRef;
  final String scheduledDate; // Format: "YYYY-MM-DD"
  final String scheduledTime; // e.g. "08:00 AM"

  /// [scheduledDate] and [scheduledTime] together as a single instant.
  ///
  /// The Worker's 5-minute sweep needs `where scheduled_at < cutoff`, and a
  /// range query cannot be built from two separate strings. This is also what
  /// history screens should sort on — sorting by the "08:00 AM" string puts
  /// 10:00 AM before 8:00 AM.
  final DateTime? scheduledAt;

  /// One of [DoseStatus].
  final String status;
  final DateTime? takenAt;
  final int snoozeCount;

  /// When the current snooze expires. Until then the dose cannot be snoozed
  /// again — without it three taps in a row used up every snooze and marked
  /// the dose missed in under a second.
  final DateTime? snoozedUntil;

  final String confirmedVia; // 'app', 'button', or '' while pending
  final bool caregiverNotified;
  final int doseCount;

  /// When the patient gave a reason for a missed dose.
  final DateTime? acknowledgedAt;

  /// The reason given for a skipped or missed dose.
  final String skippedReason;
  final String recordedBy;
  final DateTime createdAt;
  final bool isActive;

  /// One of [DoseTimingTag], set when the dose is taken. Null otherwise, and
  /// on logs written before timing existed.
  final String? timing;

  /// When the patient last acted on this dose. Differs from [takenAt] for a
  /// dose logged after the fact. The security rules also use it to allow Undo
  /// for a short time after an action.
  final DateTime? loggedAt;

  /// Why a dose was cancelled: 'archived' or 'rescheduled'.
  final String? cancelledReason;

  /// Set on every dose of a medicine archived as "entered by mistake", so it
  /// is kept but never counted in adherence.
  final bool excludedFromAdherence;

  const DoseLogModel({
    required this.doseLogId,
    required this.scheduleRef,
    required this.patientRef,
    required this.scheduledDate,
    required this.scheduledTime,
    this.scheduledAt,
    this.status = DoseStatus.pending,
    this.takenAt,
    this.snoozeCount = 0,
    this.snoozedUntil,
    this.confirmedVia = 'app',
    this.caregiverNotified = false,
    this.doseCount = 1,
    this.acknowledgedAt,
    this.skippedReason = '',
    this.recordedBy = 'patient',
    required this.createdAt,
    this.isActive = true,
    this.timing,
    this.loggedAt,
    this.cancelledReason,
    this.excludedFromAdherence = false,
  });

  bool get isTaken => status == DoseStatus.taken;
  bool get isMissed => status == DoseStatus.missed;
  bool get isSkipped => status == DoseStatus.skipped;
  bool get isSnoozed => status == DoseStatus.snoozed;
  bool get isPending => status == DoseStatus.pending;
  bool get isCancelled => status == DoseStatus.cancelled;

  /// Still waiting for the patient: nothing final has been recorded.
  bool get isOpen => isPending || isSnoozed;

  /// A decision has been recorded (taken, skipped or missed). Cancelled doses
  /// are neither open nor resolved — they never happened.
  bool get isResolved => isTaken || isSkipped || isMissed;

  /// A snooze is still running. A log written before [snoozedUntil] existed
  /// has none, and is treated as expired rather than locked forever.
  bool get isSnoozeActive =>
      isSnoozed &&
      snoozedUntil != null &&
      DateTime.now().isBefore(snoozedUntil!);

  /// The deterministic id the Worker's materialiser gives this dose:
  /// `{scheduleId}_{YYYY-MM-DD}_{HH:mm}`, local (Manila) date and 24-hour
  /// time. The app uses the same id when it has to create a log itself, so the
  /// materialiser recognises it instead of creating a duplicate.
  static String idFor(String scheduleId, DateTime scheduledAt) {
    String two(int v) => v.toString().padLeft(2, '0');
    final date =
        '${scheduledAt.year}-${two(scheduledAt.month)}-${two(scheduledAt.day)}';
    final time = '${two(scheduledAt.hour)}:${two(scheduledAt.minute)}';
    return '${scheduleId}_${date}_$time';
  }

  factory DoseLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return DoseLogModel.fromMap(data, doc.id);
  }

  static DateTime? _date(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  factory DoseLogModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return DoseLogModel(
      doseLogId: id ?? (map['dose_log_id'] as String? ?? ''),
      scheduleRef: map['schedule_ref'] as String? ?? '',
      patientRef: map['patient_ref'] as String? ?? '',
      scheduledDate: map['scheduled_date'] as String? ?? '',
      scheduledTime: map['scheduled_time'] as String? ?? '',
      scheduledAt: _date(map['scheduled_at']),
      status: map['status'] as String? ?? DoseStatus.pending,
      takenAt: _date(map['taken_at']),
      snoozeCount: (map['snooze_count'] as num?)?.toInt() ?? 0,
      snoozedUntil: map['snoozed_until'] is Timestamp
          ? (map['snoozed_until'] as Timestamp).toDate()
          : null,
      confirmedVia: map['confirmed_via'] as String? ?? 'app',
      caregiverNotified: map['caregiver_notified'] as bool? ?? false,
      doseCount: (map['dose_count'] as num?)?.toInt() ?? 1,
      acknowledgedAt: map['acknowledged_at'] is Timestamp
          ? (map['acknowledged_at'] as Timestamp).toDate()
          : null,
      skippedReason: map['skipped_reason'] as String? ?? '',
      recordedBy: map['recorded_by'] as String? ?? 'patient',
      createdAt: _date(map['created_at']) ?? DateTime.now(),
      isActive: map['is_active'] as bool? ?? true,
      timing: map['timing'] as String?,
      loggedAt: map['logged_at'] is Timestamp
          ? (map['logged_at'] as Timestamp).toDate()
          : null,
      cancelledReason: map['cancelled_reason'] as String?,
      excludedFromAdherence: map['excluded_from_adherence'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dose_log_id': doseLogId,
      'schedule_ref': scheduleRef,
      'patient_ref': patientRef,
      'scheduled_date': scheduledDate,
      'scheduled_time': scheduledTime,
      'scheduled_at':
          scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
      'status': status,
      'taken_at': takenAt != null ? Timestamp.fromDate(takenAt!) : null,
      'snooze_count': snoozeCount,
      'snoozed_until':
          snoozedUntil != null ? Timestamp.fromDate(snoozedUntil!) : null,
      'confirmed_via': confirmedVia,
      'caregiver_notified': caregiverNotified,
      'dose_count': doseCount,
      'acknowledged_at':
          acknowledgedAt != null ? Timestamp.fromDate(acknowledgedAt!) : null,
      'skipped_reason': skippedReason,
      'recorded_by': recordedBy,
      'created_at': Timestamp.fromDate(createdAt),
      'is_active': isActive,
      'timing': timing,
      'logged_at': loggedAt != null ? Timestamp.fromDate(loggedAt!) : null,
      'cancelled_reason': cancelledReason,
      'excluded_from_adherence': excludedFromAdherence,
    };
  }

  DoseLogModel copyWith({
    String? doseLogId,
    String? scheduleRef,
    String? patientRef,
    String? scheduledDate,
    String? scheduledTime,
    DateTime? scheduledAt,
    String? status,
    DateTime? takenAt,
    int? snoozeCount,
    DateTime? snoozedUntil,
    String? confirmedVia,
    bool? caregiverNotified,
    int? doseCount,
    DateTime? acknowledgedAt,
    String? skippedReason,
    String? recordedBy,
    DateTime? createdAt,
    bool? isActive,
    String? timing,
    DateTime? loggedAt,
    String? cancelledReason,
    bool? excludedFromAdherence,
  }) {
    return DoseLogModel(
      doseLogId: doseLogId ?? this.doseLogId,
      scheduleRef: scheduleRef ?? this.scheduleRef,
      patientRef: patientRef ?? this.patientRef,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      status: status ?? this.status,
      takenAt: takenAt ?? this.takenAt,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      confirmedVia: confirmedVia ?? this.confirmedVia,
      caregiverNotified: caregiverNotified ?? this.caregiverNotified,
      doseCount: doseCount ?? this.doseCount,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      skippedReason: skippedReason ?? this.skippedReason,
      recordedBy: recordedBy ?? this.recordedBy,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      timing: timing ?? this.timing,
      loggedAt: loggedAt ?? this.loggedAt,
      cancelledReason: cancelledReason ?? this.cancelledReason,
      excludedFromAdherence:
          excludedFromAdherence ?? this.excludedFromAdherence,
    );
  }
}
