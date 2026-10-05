import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Raised when the Worker rejects a request. [code] is the machine-readable
/// reason, so screens can tell "wrong code" apart from "expired code" without
/// matching on message text.
class ApiException implements Exception {
  final String message;
  final String code;
  final int statusCode;

  const ApiException(this.message, this.code, this.statusCode);

  bool get isInvalidCode => code == 'invalid_code';
  bool get isUsedCode => code == 'code_used';
  bool get isExpiredCode => code == 'code_expired';
  bool get isRateLimited => code == 'rate_limited';

  @override
  String toString() => message;
}

/// The result of redeeming an OTP: a Firebase custom token plus enough of the
/// patient's identity to greet them before their profile stream arrives.
class OtpRedemption {
  final String token;
  final String uid;
  final String firstName;
  final String lastName;

  const OtpRedemption({
    required this.token,
    required this.uid,
    required this.firstName,
    required this.lastName,
  });

  String get fullName => '$firstName $lastName'.trim();
}

/// The only place the app talks to the Cloudflare Worker.
///
/// The Worker holds the Firebase service account key and does the four things a
/// client cannot do safely: create patient accounts, mint custom tokens from
/// OTP codes, push FCM to another user, and sweep missed doses on a cron.
class ApiService {
  /// Supplied at build time so a debug run can point at `wrangler dev`:
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8787
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://healthsync-api.healthsync12.workers.dev',
  );

  static const Duration _timeout = Duration(seconds: 20);

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = false,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (authenticated) {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) {
        throw const ApiException(
          'You are not signed in. Please sign in and try again.',
          'unauthenticated',
          401,
        );
      }
      headers['Authorization'] = 'Bearer $token';
    }

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (e) {
      throw const ApiException(
        'Could not reach HealthSync. Check your internet connection.',
        'network_error',
        0,
      );
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'Something went wrong. Please try again.',
        'bad_response',
        response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw ApiException(
      decoded['error'] as String? ?? 'Something went wrong. Please try again.',
      decoded['code'] as String? ?? 'error',
      response.statusCode,
    );
  }

  /// Trades an OTP code for a Firebase custom token. Unauthenticated by
  /// necessity — the patient has no credentials yet, which is the entire point.
  Future<OtpRedemption> redeemOtp(String code) async {
    final data = await _post('/otp/redeem', {'code': code});
    return OtpRedemption(
      token: data['token'] as String? ?? '',
      uid: data['uid'] as String? ?? '',
      firstName: data['first_name'] as String? ?? '',
      lastName: data['last_name'] as String? ?? '',
    );
  }

  /// Creates a managed patient account. The caller must be a caregiver; the
  /// Worker re-checks that server-side rather than trusting this app.
  Future<String> createManagedPatient({
    required String firstName,
    required String lastName,
    String phone = '',
    String medicalConditions = '',
    String allergies = '',
    String emergencyContact = '',
    String emergencyPhone = '',
  }) async {
    final data = await _post(
      '/patients',
      {
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'medical_conditions': medicalConditions,
        'allergies': allergies,
        'emergency_contact': emergencyContact,
        'emergency_phone': emergencyPhone,
      },
      authenticated: true,
    );
    return data['uid'] as String? ?? '';
  }

  /// Tells the Worker a dose was confirmed or missed so it can alert the
  /// caregiver.
  ///
  /// Call this *after* the dose log is written to Firestore, and never let a
  /// failure here surface as a failed confirmation — the cron sweep will catch
  /// anything this call drops.
  Future<bool> reportDoseEvent({
    required String doseLogId,
    required String status,
    String medicationName = '',
  }) async {
    try {
      final data = await _post(
        '/dose-events',
        {
          'dose_log_id': doseLogId,
          'status': status,
          'medication_name': medicationName,
        },
        authenticated: true,
      );
      return data['notified'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  void dispose() => _client.close();
}
