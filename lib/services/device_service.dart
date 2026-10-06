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
