import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceModel {
  final String deviceId;
  final String deviceType; // 'esp32_smart_box'
  final String deviceName;
  final String serialNumber;
  final String patientRef;
  final String status; // 'online', 'offline', 'pairing'
  final DateTime lastSync;
  final int columnsActive; // 1–8
  final String firmwareVersion;
  final DateTime createdAt;
  final bool isActive;

  const DeviceModel({
    required this.deviceId,
    this.deviceType = 'esp32_smart_box',
    required this.deviceName,
    required this.serialNumber,
    this.patientRef = '',
    this.status = 'offline',
    required this.lastSync,
    this.columnsActive = 0,
    this.firmwareVersion = 'v1.0.0',
    required this.createdAt,
    this.isActive = true,
  });

  bool get isOnline => status == 'online';

  factory DeviceModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return DeviceModel.fromMap(data, doc.id);
  }

  factory DeviceModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return DeviceModel(
      deviceId: id ?? (map['device_id'] as String? ?? ''),
      deviceType: map['device_type'] as String? ?? 'esp32_smart_box',
      deviceName: map['device_name'] as String? ?? 'HealthSync Box',
      serialNumber: map['serial_number'] as String? ?? '',
      patientRef: map['patient_ref'] as String? ?? '',
      status: map['status'] as String? ?? 'offline',
      lastSync: map['last_sync'] is Timestamp
          ? (map['last_sync'] as Timestamp).toDate()
          : (map['last_sync'] != null
              ? DateTime.tryParse(map['last_sync'].toString()) ?? DateTime.now()
              : DateTime.now()),
      columnsActive: (map['columns_active'] as num?)?.toInt() ?? 0,
      firmwareVersion: map['firmware_version'] as String? ?? 'v1.0.0',
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
      'device_id': deviceId,
      'device_type': deviceType,
      'device_name': deviceName,
      'serial_number': serialNumber,
      'patient_ref': patientRef,
      'status': status,
      'last_sync': Timestamp.fromDate(lastSync),
      'columns_active': columnsActive,
      'firmware_version': firmwareVersion,
      'created_at': Timestamp.fromDate(createdAt),
      'is_active': isActive,
    };
  }

  DeviceModel copyWith({
    String? deviceId,
    String? deviceType,
    String? deviceName,
    String? serialNumber,
    String? patientRef,
    String? status,
    DateTime? lastSync,
    int? columnsActive,
    String? firmwareVersion,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return DeviceModel(
      deviceId: deviceId ?? this.deviceId,
      deviceType: deviceType ?? this.deviceType,
      deviceName: deviceName ?? this.deviceName,
      serialNumber: serialNumber ?? this.serialNumber,
      patientRef: patientRef ?? this.patientRef,
      status: status ?? this.status,
      lastSync: lastSync ?? this.lastSync,
      columnsActive: columnsActive ?? this.columnsActive,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
