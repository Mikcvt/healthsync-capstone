import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device_model.dart';
import '../models/schedule_model.dart';

class DeviceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream device state for a patient
  Stream<DeviceModel?> streamDeviceForPatient(String patientUid) {
    return _firestore
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

  /// ESP32 heartbeat.
  ///
  /// No battery level: this build has no battery monitoring on any GPIO pin,
  /// and the field only ever carried the literal 100 written at pairing time.
  Future<void> recordHeartbeat({
    required String deviceId,
    required int activeColumnsCount,
  }) async {
    await _firestore.collection('devices').doc(deviceId).update({
      'status': 'online',
      'last_sync': FieldValue.serverTimestamp(),
      'columns_active': activeColumnsCount,
    });
  }

  // Turn on/off LED for specific box column (1-8)
  Future<void> setColumnLedStatus({
    required String scheduleId,
    required bool ledActive,
  }) async {
    await _firestore.collection('schedules').doc(scheduleId).update({
      'led_active': ledActive,
    });
  }

  /// Whether [patientUid] has a box paired. A one-time read for the add- and
  /// edit-medicine screens, which decide once whether to offer compartments.
  Future<bool> hasPairedBox(String patientUid) async {
    final snapshot = await _firestore
        .collection('devices')
        .where('patient_ref', isEqualTo: patientUid)
        .where('is_active', isEqualTo: true)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Compartments already holding a medicine, mapped to that medicine's name.
  ///
  /// [exceptPatMedId] leaves out the medicine being edited, so its own
  /// compartment stays selectable. Two medicines in one compartment was
  /// possible before this existed; the box view then showed only one of them.
  Future<Map<int, String>> occupiedCompartments(
    String patientUid, {
    String? exceptPatMedId,
  }) async {
    final results = await Future.wait([
      _firestore
          .collection('schedules')
          .where('patient_ref', isEqualTo: patientUid)
          .where('is_active', isEqualTo: true)
          .get(),
      _firestore
          .collection('patient_medications')
          .where('patient_ref', isEqualTo: patientUid)
          .where('is_active', isEqualTo: true)
          .get(),
    ]);

    final names = {
      for (final doc in results[1].docs)
        doc.id: (doc.data()['medication_name'] as String? ?? '').trim(),
    };

    final occupied = <int, String>{};
    for (final doc in results[0].docs) {
      final schedule = ScheduleModel.fromFirestore(doc);
      final column = schedule.matBoxColumn;
      if (column == null || schedule.patMedRef == exceptPatMedId) continue;
      final name = names[schedule.patMedRef] ?? '';
      occupied[column] = name.isEmpty ? 'Another medicine' : name;
    }
    return occupied;
  }

  /// Puts every dose time of one medicine into [column], or takes it out of
  /// the box when [column] is null. Caregiver-only under the security rules.
  Future<void> assignCompartment({
    required List<String> scheduleIds,
    required int? column,
  }) async {
    if (scheduleIds.isEmpty) return;
    final batch = _firestore.batch();
    for (final id in scheduleIds) {
      batch.update(_firestore.collection('schedules').doc(id), {
        'mat_box_column': column,
        // A medicine leaving the box must not leave its LED lit.
        if (column == null) 'led_active': false,
      });
    }
    await batch.commit();
  }

  /// The physical box has exactly eight compartments, so the grid is always
  /// eight entries — an unassigned column is shown as empty rather than
  /// omitted, because the patient is looking at real hardware.
  List<BoxCompartment> buildCompartmentGrid(List<ScheduleModel> schedules) {
    return List<BoxCompartment>.generate(8, (index) {
      final column = index + 1;
      final schedule =
          schedules.where((s) => s.matBoxColumn == column).firstOrNull;
      return BoxCompartment(
        columnNumber: column,
        schedule: schedule,
      );
    });
  }
}

/// One compartment of the 8-column box, assigned or not.
class BoxCompartment {
  final int columnNumber;
  final ScheduleModel? schedule;

  const BoxCompartment({required this.columnNumber, this.schedule});

  bool get isAssigned => schedule != null;
  bool get ledActive => schedule?.ledActive ?? false;
  int get pillsRemaining => schedule?.pillsRemaining ?? 0;
  bool get isLowStock => schedule?.isLowStock ?? false;
}
