import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/patient_profile_model.dart';
import '../models/caregiver_profile_model.dart';
import '../models/medication_model.dart';
import '../models/patient_medication_model.dart';
import '../models/schedule_model.dart';
import '../models/dose_log_model.dart';
import '../models/notification_model.dart';
import '../models/caregiver_patient_link_model.dart';
import '../models/device_model.dart';
import '../models/otp_code_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==========================================
  // USERS
  // ==========================================
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  Stream<UserModel?> streamUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    });
  }

  // ==========================================
  // PATIENT PROFILE
  // ==========================================
  Future<PatientProfileModel?> getPatientProfile(String uid) async {
    final doc = await _db.collection('patient_profile').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return PatientProfileModel.fromFirestore(doc);
    }
    return null;
  }

  Stream<PatientProfileModel?> streamPatientProfile(String uid) {
    return _db.collection('patient_profile').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return PatientProfileModel.fromFirestore(doc);
      }
      return null;
    });
  }

  Future<void> setPatientProfile(PatientProfileModel profile) async {
    await _db
        .collection('patient_profile')
        .doc(profile.userRef)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  // ==========================================
  // CAREGIVER PROFILE
  // ==========================================
  Future<CaregiverProfileModel?> getCaregiverProfile(String uid) async {
    final doc = await _db.collection('caregiver_profile').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return CaregiverProfileModel.fromFirestore(doc);
    }
    return null;
  }

  Stream<CaregiverProfileModel?> streamCaregiverProfile(String uid) {
    return _db.collection('caregiver_profile').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return CaregiverProfileModel.fromFirestore(doc);
      }
      return null;
    });
  }

  Future<void> setCaregiverProfile(CaregiverProfileModel profile) async {
    await _db
        .collection('caregiver_profile')
        .doc(profile.userRef)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  // ==========================================
  // MEDICATIONS & PATIENT MEDICATIONS
  // ==========================================
  Future<List<MedicationModel>> searchMedications(String query) async {
    final snapshot = await _db
        .collection('medications')
        .where('is_active', isEqualTo: true)
        .get();
    return snapshot.docs
        .map((doc) => MedicationModel.fromFirestore(doc))
        .where(
          (m) =>
              m.medicationName.toLowerCase().contains(query.toLowerCase()) ||
              m.genericName.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  Stream<List<PatientMedicationModel>> streamPatientMedications(
    String patientUid,
  ) {
    return _db
        .collection('patient_medications')
        .where('patient_ref', isEqualTo: patientUid)
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PatientMedicationModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<PatientMedicationModel?> getPatientMedication(String patMedId) async {
    final doc = await _db.collection('patient_medications').doc(patMedId).get();
    if (doc.exists && doc.data() != null) {
      return PatientMedicationModel.fromFirestore(doc);
    }
    return null;
  }

  Future<String> addPatientMedication(PatientMedicationModel model) async {
    final docRef = _db.collection('patient_medications').doc();
    final newModel = model.copyWith(patMedId: docRef.id);
    await docRef.set(newModel.toMap());
    return docRef.id;
  }

  Future<void> updatePatientMedication(PatientMedicationModel model) async {
    await _db
        .collection('patient_medications')
        .doc(model.patMedId)
        .update(model.toMap());
  }

  /// Retires a medication **and every schedule that points at it**.
  ///
  /// Deactivating only one side is what left medicines sitting in the list with
  /// their schedules gone, and schedules firing for medicines the patient had
  /// already removed.
  Future<void> deletePatientMedication(String patMedId) async {
    final batch = _db.batch();

    batch.update(_db.collection('patient_medications').doc(patMedId), {
      'is_active': false,
      'updated_at': Timestamp.now(),
    });

    final schedules = await _db
        .collection('schedules')
        .where('pat_med_ref', isEqualTo: patMedId)
        .get();
    for (final doc in schedules.docs) {
      batch.update(doc.reference, {'is_active': false, 'led_active': false});
    }

    await batch.commit();
  }

  Future<ScheduleModel?> getSchedule(String scheduleId) async {
    final doc = await _db.collection('schedules').doc(scheduleId).get();
    if (doc.exists && doc.data() != null) {
      return ScheduleModel.fromFirestore(doc);
    }
    return null;
  }

  /// Deactivates one schedule, leaving its medication in place — used when a
  /// medicine keeps some of its dose times but loses others.
  Future<void> deactivateSchedule(String scheduleId) async {
    await _db.collection('schedules').doc(scheduleId).update({
      'is_active': false,
      'led_active': false,
    });
  }

  // ==========================================
  // SCHEDULES
  // ==========================================
  Stream<List<ScheduleModel>> streamPatientSchedules(String patientUid) {
    return _db
        .collection('schedules')
        .where('patient_ref', isEqualTo: patientUid)
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ScheduleModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<String> addSchedule(ScheduleModel schedule) async {
    final docRef = _db.collection('schedules').doc();
    final newSchedule = schedule.copyWith(scheduleId: docRef.id);
    await docRef.set(newSchedule.toMap());
    return docRef.id;
  }

  Future<void> updateSchedule(ScheduleModel schedule) async {
    await _db
        .collection('schedules')
        .doc(schedule.scheduleId)
        .update(schedule.toMap());
  }

  Future<void> updateScheduleLed(String scheduleId, bool ledActive) async {
    await _db.collection('schedules').doc(scheduleId).update({
      'led_active': ledActive,
    });
  }

  Future<void> decrementPillsRemaining(String scheduleId, int amount) async {
    await _db.collection('schedules').doc(scheduleId).update({
      'pills_remaining': FieldValue.increment(-amount),
    });
  }

  // ==========================================
  // DOSE LOGS
  // ==========================================
  /// Dose logs for [patientUid], newest first.
  ///
  /// [since] bounds the window. It is not an optimisation: an unbounded stream
  /// re-reads the patient's entire history on every write, and the Spark plan
  /// allows 50k document reads a day. Ninety days covers every screen in the
  /// app, and the analytics screens never ask for more.
  Stream<List<DoseLogModel>> streamPatientDoseLogs(
    String patientUid, {
    String? dateStr,
    DateTime? since,
    int limit = 500,
  }) {
    Query query = _db
        .collection('dose_logs')
        .where('patient_ref', isEqualTo: patientUid)
        .where('is_active', isEqualTo: true);

    if (dateStr != null) {
      query = query.where('scheduled_date', isEqualTo: dateStr);
    } else if (since != null) {
      query = query
          .where('scheduled_at', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .orderBy('scheduled_at', descending: true);
    }

    return query.limit(limit).snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => DoseLogModel.fromFirestore(doc)).toList(),
    );
  }

  Future<DoseLogModel?> getDoseLog(String doseLogId) async {
    final doc = await _db.collection('dose_logs').doc(doseLogId).get();
    if (doc.exists && doc.data() != null) {
      return DoseLogModel.fromFirestore(doc);
    }
    return null;
  }

  Future<String> recordDoseLog(DoseLogModel log) async {
    final docRef = _db.collection('dose_logs').doc();
    final newLog = log.copyWith(doseLogId: docRef.id);
    await docRef.set(newLog.toMap());
    return docRef.id;
  }

  Future<void> updateDoseLogStatus({
    required String doseLogId,
    required String status,
    DateTime? takenAt,
    int? snoozeCount,
    String? skippedReason,
    bool? caregiverNotified,
    String? confirmedVia,
  }) async {
    final Map<String, dynamic> updates = {'status': status};
    if (takenAt != null) updates['taken_at'] = Timestamp.fromDate(takenAt);
    if (confirmedVia != null) updates['confirmed_via'] = confirmedVia;
    if (snoozeCount != null) updates['snooze_count'] = snoozeCount;
    if (skippedReason != null) updates['skipped_reason'] = skippedReason;
    if (caregiverNotified != null) {
      updates['caregiver_notified'] = caregiverNotified;
    }

    await _db.collection('dose_logs').doc(doseLogId).update(updates);
  }

  // ==========================================
  // NOTIFICATIONS
  // ==========================================
  /// Notifications for [userUid], newest first.
  ///
  /// Sorted client-side so the collection needs no composite index — the
  /// result set is capped at [limit] and a caregiver with several patients
  /// still produces only a handful a day.
  Stream<List<NotificationModel>> streamUserNotifications(
    String userUid, {
    int limit = 100,
  }) {
    return _db
        .collection('notifications')
        .where('user_ref', isEqualTo: userUid)
        .where('is_active', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList();
          items.sort((a, b) => b.sentAt.compareTo(a.sentAt));
          return items;
        });
  }

  /// Marks every unread notification for [userUid] read in one batch, so
  /// opening the alerts screen does not cost one write per row.
  Future<void> markAllNotificationsRead(String userUid) async {
    final unread = await _db
        .collection('notifications')
        .where('user_ref', isEqualTo: userUid)
        .where('is_active', isEqualTo: true)
        .limit(100)
        .get();

    final batch = _db.batch();
    var pending = 0;
    for (final doc in unread.docs) {
      if (doc.data()['read_at'] != null) continue;
      batch.update(doc.reference, {'read_at': Timestamp.now()});
      pending++;
    }
    if (pending > 0) await batch.commit();
  }

  Future<void> createNotification(NotificationModel notif) async {
    final docRef = _db.collection('notifications').doc();
    final newNotif = notif.copyWith(notifId: docRef.id);
    await docRef.set(newNotif.toMap());
  }

  Future<void> markNotificationAsRead(String notifId) async {
    await _db.collection('notifications').doc(notifId).update({
      'read_at': Timestamp.now(),
    });
  }

  // ==========================================
  // CAREGIVER - PATIENT LINKS
  // ==========================================
  Stream<List<CaregiverPatientLinkModel>> streamCaregiverLinks(
    String caregiverUid,
  ) {
    return _db
        .collection('caregiver_patient_links')
        .where('caregiver_ref', isEqualTo: caregiverUid)
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CaregiverPatientLinkModel.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<CaregiverPatientLinkModel>> streamPatientLinks(
    String patientUid,
  ) {
    return _db
        .collection('caregiver_patient_links')
        .where('patient_ref', isEqualTo: patientUid)
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CaregiverPatientLinkModel.fromFirestore(doc))
              .toList(),
        );
  }


  Future<void> unlinkCaregiverPatient(String linkId, String patientUid) async {
    await _db.collection('caregiver_patient_links').doc(linkId).update({
      'status': 'inactive',
      'is_active': false,
    });
    await _db.collection('patient_profile').doc(patientUid).update({
      'caregiver_ref': null,
    });
  }

  // ==========================================
  // OTP CODES
  //
  // The caregiver generates a code and writes it here; the patient never reads
  // this collection. Redemption happens in the Cloudflare Worker, which has
  // admin credentials, validates expiry and the `used` flag, and mints a
  // Firebase custom token. There is deliberately no markOtpUsed() here — if a
  // client could set `used`, it could also leave it false and replay the code.
  // ==========================================

  /// Creates a code for [patientUid], stored under its own code as the document
  /// id so the Worker can look it up with a direct `get` rather than a query.
  Future<OtpCodeModel> createOtpCode({
    required String patientUid,
    required String caregiverUid,
  }) async {
    // Collisions are handled by writing and retrying, never by checking first.
    //
    // A pre-flight get() on a code that does not exist is DENIED by the rules:
    // reads require isOwner(resource.data.caregiver_ref), and for a missing
    // document `resource` is null, so that expression fails. Relaxing the rule
    // to permit it would also hand anyone an existence oracle for guessing
    // codes.
    //
    // Writing blind is safe instead: `allow update: if false` means a set()
    // onto an existing code is rejected, so a collision surfaces as a failed
    // write rather than silently reassigning another patient's code.
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      final otp = OtpCodeModel.generate(
        patientRef: patientUid,
        caregiverRef: caregiverUid,
      );
      try {
        await _db.collection('otp_codes').doc(otp.code).set(otp.toMap());
        return otp;
      } catch (e) {
        // Either a collision (~1 in 887 million) or a genuine rules failure.
        // Retrying costs nothing and distinguishes the two: a real permissions
        // problem fails all three times.
        lastError = e;
      }
    }
    throw Exception('Could not create a code. $lastError');
  }

  /// The codes this caregiver has issued, newest first. Scoped to the caller by
  /// the security rules — a caregiver can never list another's codes.
  Stream<List<OtpCodeModel>> streamCaregiverOtpCodes(String caregiverUid) {
    return _db
        .collection('otp_codes')
        .where('caregiver_ref', isEqualTo: caregiverUid)
        .snapshots()
        .map((snapshot) {
          final codes = snapshot.docs
              .map((doc) => OtpCodeModel.fromFirestore(doc))
              .toList();
          codes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return codes;
        });
  }

  /// The code a caregiver can still hand to [patientUid], if one is outstanding.
  /// Used by the generate-OTP screen so reopening it shows the same code rather
  /// than silently minting a second one.
  Future<OtpCodeModel?> getActiveOtpForPatient({
    required String patientUid,
    required String caregiverUid,
  }) async {
    final query = await _db
        .collection('otp_codes')
        .where('caregiver_ref', isEqualTo: caregiverUid)
        .where('patient_ref', isEqualTo: patientUid)
        .where('used', isEqualTo: false)
        .get();

    final live = query.docs
        .map((doc) => OtpCodeModel.fromFirestore(doc))
        .where((otp) => otp.isRedeemable)
        .toList();
    if (live.isEmpty) return null;

    live.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return live.first;
  }

  /// Withdraws an unused code — the caregiver's "regenerate" action. Deleting
  /// rather than flagging keeps a redeemed code from ever being resurrected.
  Future<void> revokeOtpCode(String code) async {
    await _db.collection('otp_codes').doc(code).delete();
  }

  // ==========================================
  // DEVICES (ESP32 Smart Medicine Box)
  // ==========================================
  Stream<DeviceModel?> streamPatientDevice(String patientUid) {
    return _db
        .collection('devices')
        .where('patient_ref', isEqualTo: patientUid)
        .where('is_active', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            return DeviceModel.fromFirestore(snapshot.docs.first);
          }
          return null;
        });
  }

  Future<void> pairDevice({
    required String patientUid,
    required String serialNumber,
    String deviceName = 'HealthSync Smart Box',
  }) async {
    final docRef = _db.collection('devices').doc();
    final device = DeviceModel(
      deviceId: docRef.id,
      deviceName: deviceName,
      serialNumber: serialNumber.trim(),
      patientRef: patientUid,
      status: 'online',
      lastSync: DateTime.now(),
      columnsActive: 0,
      createdAt: DateTime.now(),
      isActive: true,
    );
    await docRef.set(device.toMap());
  }
}
