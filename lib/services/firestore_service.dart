import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'connectivity_service.dart';
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

  /// A new medicine and one schedule per dose time, in one batch (BUG-021).
  /// Writing them one by one waited for the server 1 + N times in a row
  /// before the success screen. Returns the commit for [settle].
  Future<void> addMedicationWithSchedules(
    PatientMedicationModel medication,
    List<ScheduleModel> schedules,
  ) {
    final batch = _db.batch();
    final medRef = _db.collection('patient_medications').doc();
    batch.set(medRef, medication.copyWith(patMedId: medRef.id).toMap());
    for (final schedule in schedules) {
      final ref = _db.collection('schedules').doc();
      batch.set(ref, {
        ...schedule.copyWith(scheduleId: ref.id, patMedRef: medRef.id).toMap(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
    return batch.commit();
  }

  Future<void> updatePatientMedication(PatientMedicationModel model) async {
    await _db
        .collection('patient_medications')
        .doc(model.patMedId)
        .update(model.toMap());
  }

  /// What the patient's phone found when it checked whether reminders can
  /// fire, plus when the app was opened. Read by the caregiver dashboard.
  Future<void> reportReminderHealth(
    String uid, {
    required bool notificationsOk,
    required bool exactAlarmsOk,
    required bool batteryOk,
  }) async {
    await _db.collection('users').doc(uid).update({
      'reminders_notifications_ok': notificationsOk,
      'reminders_exact_alarms_ok': exactAlarmsOk,
      'reminders_battery_ok': batteryOk,
      'app_last_opened_at': Timestamp.now(),
    });
  }

  /// Ends a patient's treatment: every active medicine is archived as a
  /// finished course, in one step.
  ///
  /// The same outcome as "Course finished" on each medicine: schedules go
  /// inactive (so the Worker creates no more doses and the patient's phone
  /// drops their reminders), LEDs go off, and doses not yet due are cancelled.
  /// Past doses are untouched and keep counting in adherence. The patient's
  /// account stays, and a medicine added or restored later resumes normally.
  ///
  /// Returns how many medicines were archived.
  Future<int> completeTreatment(String patientUid) async {
    final medications = await _db
        .collection('patient_medications')
        .where('patient_ref', isEqualTo: patientUid)
        .where('is_active', isEqualTo: true)
        .get();
    final schedules = await _db
        .collection('schedules')
        .where('patient_ref', isEqualTo: patientUid)
        .where('is_active', isEqualTo: true)
        .get();

    final now = Timestamp.now();
    final batch = _db.batch();
    for (final doc in medications.docs) {
      batch.update(doc.reference, {
        'is_active': false,
        'archived_at': now,
        'archived_reason': 'completed',
        'updated_at': now,
      });
    }
    for (final doc in schedules.docs) {
      batch.update(doc.reference, {
        'is_active': false,
        'led_active': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
    batch.update(_db.collection('patient_profile').doc(patientUid), {
      'treatment_completed_at': now,
    });
    await batch.commit();

    await _cancelFutureDoseLogs(
      patientUid: patientUid,
      scheduleIds: schedules.docs.map((doc) => doc.id).toList(),
    );
    return medications.docs.length;
  }

  /// Marks a missed dose as seen by the patient, which removes it from the
  /// dashboard. The log itself is untouched — adherence still counts it missed.
  Future<void> acknowledgeDoseLog(String doseLogId) async {
    await _db.collection('dose_logs').doc(doseLogId).update({
      'acknowledged_at': Timestamp.now(),
    });
  }

  /// Medicines removed from the active regimen, newest first.
  Stream<List<PatientMedicationModel>> streamArchivedMedications(
    String patientUid,
  ) {
    return _db
        .collection('patient_medications')
        .where('patient_ref', isEqualTo: patientUid)
        .where('is_active', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => PatientMedicationModel.fromFirestore(doc))
              .toList();
          items.sort((a, b) => b.startDate.compareTo(a.startDate));
          return items;
        });
  }

  /// Puts an archived medicine back into the regimen.
  ///
  /// Dose-log ids are fixed (`{schedule}_{date}_{time}`) and the Worker's
  /// materialiser skips any id that already exists, so the future doses that
  /// archiving cancelled must be turned back into pending ones here — or
  /// today's and tomorrow's doses would silently never come back.
  Future<void> restoreMedication(
    String patMedId, {
    required String patientUid,
  }) async {
    final batch = _db.batch();
    batch.update(_db.collection('patient_medications').doc(patMedId), {
      'is_active': true,
      'archived_at': null,
      'archived_reason': null,
      'updated_at': Timestamp.now(),
    });

    final schedules = await _db
        .collection('schedules')
        .where('patient_ref', isEqualTo: patientUid)
        .where('pat_med_ref', isEqualTo: patMedId)
        .get();
    final scheduleIds = <String>{};
    for (final doc in schedules.docs) {
      scheduleIds.add(doc.id);
      batch.update(doc.reference, {
        'is_active': true,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    await _reviveCancelledDoseLogs(
      patientUid: patientUid,
      scheduleIds: scheduleIds,
    );
    await _setAdherenceExclusion(
      patientUid: patientUid,
      scheduleIds: scheduleIds,
      excluded: false,
    );
  }

  /// Cancels still-pending doses scheduled from now on for [scheduleIds].
  ///
  /// Never deletes: a dose log is part of the medical record. Cancelled doses
  /// are kept, excluded from every list and from adherence, and can be revived
  /// by [restoreMedication].
  Future<void> _cancelFutureDoseLogs({
    required String patientUid,
    required List<String> scheduleIds,
  }) async {
    if (scheduleIds.isEmpty) return;
    final now = Timestamp.now();

    // Queried by patient_ref so the security rules can authorise it — rules
    // are not filters, and a query on schedule_ref alone is rejected outright.
    final snapshot = await _db
        .collection('dose_logs')
        .where('patient_ref', isEqualTo: patientUid)
        .where('status', isEqualTo: 'pending')
        .get();

    final targets = snapshot.docs.where((doc) {
      final data = doc.data();
      if (!scheduleIds.contains(data['schedule_ref'])) return false;
      final at = data['scheduled_at'];
      return at is Timestamp && at.compareTo(now) > 0;
    });
    await _batchUpdate(targets.map((d) => d.reference), {
      'status': 'cancelled',
      'cancelled_reason': 'archived',
    });
  }

  /// Turns future doses cancelled by archiving back into pending ones.
  Future<void> _reviveCancelledDoseLogs({
    required String patientUid,
    required Set<String> scheduleIds,
  }) async {
    if (scheduleIds.isEmpty) return;
    final now = Timestamp.now();
    final snapshot = await _db
        .collection('dose_logs')
        .where('patient_ref', isEqualTo: patientUid)
        .where('status', isEqualTo: 'cancelled')
        .get();

    final targets = snapshot.docs.where((doc) {
      final data = doc.data();
      if (!scheduleIds.contains(data['schedule_ref'])) return false;
      if (data['cancelled_reason'] != 'archived') return false;
      final at = data['scheduled_at'];
      return at is Timestamp && at.compareTo(now) > 0;
    });
    await _batchUpdate(targets.map((d) => d.reference), {
      'status': 'pending',
      'cancelled_reason': null,
    });
  }

  /// Marks every dose of [scheduleIds] as counted or not counted in adherence.
  /// Used for a medicine archived as "entered by mistake": its doses stay
  /// stored, but describe something that never happened.
  Future<void> _setAdherenceExclusion({
    required String patientUid,
    required Set<String> scheduleIds,
    required bool excluded,
  }) async {
    if (scheduleIds.isEmpty) return;
    final snapshot = await _db
        .collection('dose_logs')
        .where('patient_ref', isEqualTo: patientUid)
        .get();

    final targets = snapshot.docs.where((doc) {
      final data = doc.data();
      if (!scheduleIds.contains(data['schedule_ref'])) return false;
      return (data['excluded_from_adherence'] == true) != excluded;
    });
    await _batchUpdate(targets.map((d) => d.reference), {
      'excluded_from_adherence': excluded,
    });
  }

  /// Applies the same update to many documents, in batches under Firestore's
  /// 500-write limit.
  Future<void> _batchUpdate(
    Iterable<DocumentReference> refs,
    Map<String, dynamic> data,
  ) async {
    final list = refs.toList();
    for (var i = 0; i < list.length; i += 450) {
      final batch = _db.batch();
      for (final ref in list.skip(i).take(450)) {
        batch.update(ref, data);
      }
      await batch.commit();
    }
  }

  /// Why a medicine left the active regimen.
  ///
  /// The distinction matters for honesty of the record: a finished course is
  /// part of the patient's history and its missed doses are real, while a
  /// mistyped entry never happened and its logs are noise.
  Future<void> archivePatientMedication(
    String patMedId, {
    required String patientUid,
    required bool wasMistake,
  }) =>
      deletePatientMedication(
        patMedId,
        patientUid: patientUid,
        wasMistake: wasMistake,
      );

  Future<void> deletePatientMedication(
    String patMedId, {
    required String patientUid,
    // Only an explicit "entered by mistake" choice stops a medicine's doses
    // counting; every other removal keeps its history counted.
    bool wasMistake = false,
  }) async {
    final batch = _db.batch();

    batch.update(_db.collection('patient_medications').doc(patMedId), {
      'is_active': false,
      // Both are archived; only one is a mistake. The archive screen reads
      // this to offer "restore" versus "delete permanently".
      'archived_at': Timestamp.now(),
      'archived_reason': wasMistake ? 'mistake' : 'completed',
      'updated_at': Timestamp.now(),
    });

    final schedules = await _db
        .collection('schedules')
        .where('patient_ref', isEqualTo: patientUid)
        .where('pat_med_ref', isEqualTo: patMedId)
        .get();
    final scheduleIds = <String>[];
    for (final doc in schedules.docs) {
      scheduleIds.add(doc.id);
      batch.update(doc.reference, {
        'is_active': false,
        'led_active': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    // Cancel doses that have not happened yet.
    //
    // The schedule is inactive now, so the Worker will not create more — but
    // the ones already materialised would sit there until the sweep marked
    // them missed, producing alerts for a medicine nobody is taking any more.
    // Past doses are never touched: they are the adherence record.
    await _cancelFutureDoseLogs(patientUid: patientUid, scheduleIds: scheduleIds);

    // A mistaken entry describes doses that never happened: keep them, but
    // stop counting them.
    if (wasMistake) {
      await _setAdherenceExclusion(
        patientUid: patientUid,
        scheduleIds: scheduleIds.toSet(),
        excluded: true,
      );
    }
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
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================
  // SCHEDULES
  //
  // Every caregiver write that changes which doses exist (adding, editing,
  // archiving, restoring, deactivating) stamps updated_at with the server's
  // clock. The Worker creates doses hourly, and runs early only when it finds
  // a schedule stamped in the last 10 minutes; an unstamped edit would wait up
  // to an hour, long enough for a moved dose time to be swept as missed.
  //
  // Patient writes (led_active, pills_remaining) never stamp it: the rules
  // allow a patient to change those two fields and nothing else.
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

  Future<void> updateSchedule(ScheduleModel schedule) async {
    await _db
        .collection('schedules')
        .doc(schedule.scheduleId)
        .update({
          ...schedule.toMap(),
          'updated_at': FieldValue.serverTimestamp(),
        });
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

  /// Gives back stock taken by a dose that was undone.
  Future<void> incrementPillsRemaining(String scheduleId, int amount) async {
    await _db.collection('schedules').doc(scheduleId).update({
      'pills_remaining': FieldValue.increment(amount),
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

    // Cancelled doses (archived medicine, moved dose time) are kept in
    // Firestore for the record but never shown or counted anywhere, so they
    // are dropped here once rather than on every screen.
    //
    // includeMetadataChanges: a dose saved offline arrives with
    // hasPendingWrites and comes again once the server has it, which is what
    // clears its "waiting to sync" mark.
    return query.limit(limit).snapshots(includeMetadataChanges: true).map(
      (snapshot) => snapshot.docs
          .map((doc) => DoseLogModel.fromFirestore(doc))
          .where((log) => !log.isCancelled)
          .toList(),
    );
  }

  // ==========================================
  // OFFLINE
  //
  // Firestore applies every write to the phone's copy at once and sends it
  // when it can, even after a restart. But on Android a write's Future only
  // completes when the SERVER confirms it — never, while offline. Awaiting
  // each write left every dose button spinning forever without internet.
  // Dose actions now issue their writes and [settle] them instead.
  // ==========================================

  /// How long a dose action waits for the server before treating its writes
  /// as saved on the phone.
  static const Duration _ackWait = Duration(seconds: 4);

  /// Waits briefly for [writes] to reach the server. True: the server has
  /// them. False: they are saved on this phone and will sync later (offline,
  /// or a connection too slow to answer). Throws if the server refused one,
  /// which can only be learned while online.
  Future<bool> settle(Iterable<Future<void>> writes) async {
    final all = Future.wait(writes);
    if (!ConnectivityService().online.value) {
      _logLateFailure(all);
      return false;
    }
    try {
      await all.timeout(_ackWait);
      return true;
    } on TimeoutException {
      _logLateFailure(all);
      return false;
    }
  }

  void _logLateFailure(Future<Object?> pending) {
    // A refusal that arrives after the action returned. Firestore has already
    // rolled the phone's copy back, which the dose stream shows.
    unawaited(pending.then<void>((_) {}, onError: (Object e) {
      debugPrint('A write saved offline was refused when it synced: $e');
    }));
  }

  /// One dose log. Online: the server's copy, falling back to the phone's if
  /// the server is slow to answer. Offline: the phone's copy only. Null when
  /// it does not exist (or is not on this phone), so the caller creates it
  /// under its deterministic id.
  Future<DoseLogModel?> getDoseLog(String doseLogId) async {
    final ref = _db.collection('dose_logs').doc(doseLogId);
    DocumentSnapshot<Map<String, dynamic>>? doc;
    if (ConnectivityService().online.value) {
      try {
        doc = await ref.get().timeout(_ackWait);
      } on TimeoutException {
        doc = await _cached(ref);
      } on FirebaseException {
        doc = await _cached(ref);
      }
    } else {
      doc = await _cached(ref);
    }
    if (doc != null && doc.exists && doc.data() != null) {
      return DoseLogModel.fromFirestore(doc);
    }
    return null;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _cached(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      return await ref.get(const GetOptions(source: Source.cache));
    } on FirebaseException {
      // Not on this phone.
      return null;
    }
  }

  Future<String> recordDoseLog(DoseLogModel log) async {
    final docRef = _db.collection('dose_logs').doc();
    final newLog = log.copyWith(doseLogId: docRef.id);
    await docRef.set(newLog.toMap());
    return docRef.id;
  }

  /// Creates or replaces a dose log under its own [DoseLogModel.doseLogId].
  /// Used with the deterministic id, so a log the app creates before the
  /// Worker's materialiser runs is the same document it would have created.
  Future<void> setDoseLog(DoseLogModel log) async {
    // merge: a log created offline may land on one the Worker made in the
    // meantime; fields the app does not model (missed_at, late_notified)
    // must survive.
    await _db
        .collection('dose_logs')
        .doc(log.doseLogId)
        .set({
          ...log.toMap(),
          'synced_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  /// Writes [fields] onto a dose log. [DateTime] values become Timestamps and
  /// null values are written as null, which is how Undo clears a field.
  Future<void> updateDoseLogFields(
    String doseLogId,
    Map<String, dynamic> fields,
  ) async {
    final converted = fields.map(
      (key, value) =>
          MapEntry(key, value is DateTime ? Timestamp.fromDate(value) : value),
    );
    await _db.collection('dose_logs').doc(doseLogId).update({
      ...converted,
      // When this change reached the SERVER. A dose logged offline arrives
      // hours after its logged_at; the Worker's alert backstop goes by this.
      'synced_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateDoseLogStatus({
    required String doseLogId,
    required String status,
    DateTime? takenAt,
    int? snoozeCount,
    DateTime? snoozedUntil,
    String? skippedReason,
    bool? caregiverNotified,
    String? confirmedVia,
  }) async {
    final Map<String, dynamic> updates = {'status': status};
    if (snoozedUntil != null) {
      updates['snoozed_until'] = Timestamp.fromDate(snoozedUntil);
    }
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

  /// Hides a notification without deleting it — used when the dose that
  /// triggered it is undone.
  Future<void> deactivateNotification(String notifId) async {
    await _db.collection('notifications').doc(notifId).update({
      'is_active': false,
    });
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
