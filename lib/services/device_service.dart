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

  // Update ESP32 heartbeat / sync ping
  Future<void> recordHeartbeat({
    required String deviceId,
    required int batteryLevel,
    required int activeColumnsCount,
  }) async {
    await _firestore.collection('devices').doc(deviceId).update({
      'status': 'online',
      'last_sync': FieldValue.serverTimestamp(),
      'battery_level': batteryLevel,
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

  // Generate 8-column compartment status map for UI visualization
  // Returns a List of 8 maps containing column index (1-8), status, schedule, and pills
  List<Map<String, dynamic>> buildCompartmentGrid(List<ScheduleModel> schedules) {
    final List<Map<String, dynamic>> columns = [];

    for (int i = 1; i <= 8; i++) {
      final matchingSchedule = schedules.where((s) => s.matBoxColumn == i).firstOrNull;

      if (matchingSchedule != null) {
        columns.add({
          'column_number': i,
          'is_assigned': true,
          'schedule': matchingSchedule,
          'led_active': matchingSchedule.ledActive,
          'pills_remaining': matchingSchedule.pillsRemaining,
          'is_low_stock': matchingSchedule.isLowStock,
        });
      } else {
        columns.add({
          'column_number': i,
          'is_assigned': false,
          'schedule': null,
          'led_active': false,
          'pills_remaining': 0,
          'is_low_stock': false,
        });
      }
    }

    return columns;
  }
}
