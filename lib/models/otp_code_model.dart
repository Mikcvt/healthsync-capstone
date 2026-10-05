import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// A one-time code a caregiver hands to a managed patient so they can open the
/// app without ever signing up.
///
/// Security note: the client may only *create* and *read its own* codes. The
/// `used` flag is flipped server-side by the Cloudflare Worker, which validates
/// the code and mints the Firebase custom token. If a client could write it,
/// anyone could replay a code.
class OtpCodeModel {
  /// Excludes 0/O and 1/I/L — a patient reads this off a text message and
  /// types it by hand, often on a small screen.
  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// 'HS' + 6 random characters. 31^6 is ~887 million combinations, which
  /// matters because `/otp/redeem` is the one unauthenticated endpoint.
  static const int _randomLength = 6;

  /// Spec: a code dies 48 hours after it is generated.
  static const Duration validity = Duration(hours: 48);

  final String code;
  final String patientRef;
  final String caregiverRef;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool used;

  const OtpCodeModel({
    required this.code,
    required this.patientRef,
    required this.caregiverRef,
    required this.createdAt,
    required this.expiresAt,
    this.used = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// What the caregiver's screen should treat as still handable to a patient.
  bool get isRedeemable => !used && !isExpired;

  Duration get timeRemaining {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Formats as "HS47-XQKM" for display only. Never store or transmit this
  /// form — [code] is the value the Worker checks.
  String get displayCode =>
      code.length > 4 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;

  /// Uses [Random.secure] rather than [Random]. A predictable code is a
  /// predictable account key.
  static String generateCode() {
    final rng = Random.secure();
    final buffer = StringBuffer('HS');
    for (var i = 0; i < _randomLength; i++) {
      buffer.write(_alphabet[rng.nextInt(_alphabet.length)]);
    }
    return buffer.toString();
  }

  /// Builds a fresh code for [patientRef], expiring [validity] from now.
  factory OtpCodeModel.generate({
    required String patientRef,
    required String caregiverRef,
  }) {
    final now = DateTime.now();
    return OtpCodeModel(
      code: generateCode(),
      patientRef: patientRef,
      caregiverRef: caregiverRef,
      createdAt: now,
      expiresAt: now.add(validity),
    );
  }

  factory OtpCodeModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return OtpCodeModel.fromMap(data, doc.id);
  }

  factory OtpCodeModel.fromMap(Map<String, dynamic> map, [String? id]) {
    final createdAt = _toDate(map['created_at']) ?? DateTime.now();
    return OtpCodeModel(
      code: map['code'] as String? ?? id ?? '',
      patientRef: map['patient_ref'] as String? ?? '',
      caregiverRef: map['caregiver_ref'] as String? ?? '',
      createdAt: createdAt,
      expiresAt: _toDate(map['expires_at']) ?? createdAt.add(validity),
      used: map['used'] as bool? ?? false,
    );
  }

  static DateTime? _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value != null) return DateTime.tryParse(value.toString());
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'patient_ref': patientRef,
      'caregiver_ref': caregiverRef,
      'created_at': Timestamp.fromDate(createdAt),
      'expires_at': Timestamp.fromDate(expiresAt),
      'used': used,
    };
  }

  OtpCodeModel copyWith({
    String? code,
    String? patientRef,
    String? caregiverRef,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? used,
  }) {
    return OtpCodeModel(
      code: code ?? this.code,
      patientRef: patientRef ?? this.patientRef,
      caregiverRef: caregiverRef ?? this.caregiverRef,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      used: used ?? this.used,
    );
  }
}
