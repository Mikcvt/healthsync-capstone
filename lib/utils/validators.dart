import 'phone_format.dart';

/// Form validators, returning null when the value is acceptable and a
/// user-facing message otherwise — the shape `TextFormField.validator` expects.
///
/// Messages say what to do, not what went wrong: "Enter your first name" rather
/// than "Invalid input".
class Validators {
  const Validators._();

  static String? required(String? value, String fieldLabel) {
    if (value == null || value.trim().isEmpty) return 'Enter $fieldLabel';
    return null;
  }

  static String? name(String? value, {String label = 'name'}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter the $label';
    if (text.length < 2) return 'That $label looks too short';
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter an email address';
    // Deliberately permissive: the authority on whether an address exists is
    // the verification email, not a regex.
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Firebase rejects anything under six characters, so a shorter minimum here
  /// would fail at the server with a worse message.
  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Enter a password';
    if (text.length < 6) return 'Use at least 6 characters';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Re-enter your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  /// A Philippine mobile number as typed after the fixed `+63`: 10 digits
  /// starting with 9. See [PhPhone]. Optional unless [isRequired], by design:
  /// a managed patient often has no phone of their own.
  static String? phPhone(String? value, {bool isRequired = false}) {
    final digits = PhPhone.localDigits(value);
    if (digits == '') return isRequired ? 'Enter a phone number' : null;
    if (digits == null) return 'Enter the 10 digits after +63, starting with 9';
    return null;
  }

  /// `HS` plus six characters from the unambiguous alphabet. Dashes and case
  /// are forgiven here because the patient is copying from a text message.
  static String? otpCode(String? value) {
    final text = (value ?? '').trim().toUpperCase().replaceAll('-', '');
    if (text.isEmpty) return 'Enter the code your care partner sent you';
    if (text.length != 8) return 'The code is 8 characters long';
    if (!RegExp(r'^HS[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$').hasMatch(text)) {
      return 'That does not look like a HealthSync code';
    }
    return null;
  }

  /// Largest amount on hand and low-stock alert (BUG-020). The fields also
  /// stop typing at 3 and 2 digits.
  static const maxOnHand = 999;
  static const maxLowStockAlert = 99;

  /// The amount on hand and the low-stock alert, checked together.
  ///
  /// [alertWithinStock] refuses an alert above the amount on hand, which would
  /// fire the moment the medicine is saved. Only Add medicine sets it: on Edit,
  /// the count falls below the alert as doses are taken, and that must not
  /// block every other edit to the medicine.
  static String? stock(
    String? onHand,
    String? alert, {
    String onHandLabel = 'the amount on hand',
    bool alertWithinStock = false,
  }) {
    final count = int.tryParse(onHand?.trim() ?? '');
    final threshold = int.tryParse(alert?.trim() ?? '');
    if (count == null || threshold == null) {
      return 'Enter $onHandLabel and the low-stock alert as whole numbers.';
    }
    if (count < 0 || count > maxOnHand) {
      return 'Enter $onHandLabel as 0 to $maxOnHand.';
    }
    if (threshold < 0 || threshold > maxLowStockAlert) {
      return 'Set the low-stock alert to 0 to $maxLowStockAlert.';
    }
    if (alertWithinStock && threshold > count) {
      return 'The low-stock alert cannot be more than $onHandLabel.';
    }
    return null;
  }

  static String? positiveInt(String? value, String fieldLabel, {int max = 9999}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter $fieldLabel';
    final parsed = int.tryParse(text);
    if (parsed == null) return 'Enter $fieldLabel as a number';
    if (parsed < 0) return '$fieldLabel cannot be negative';
    if (parsed > max) return '$fieldLabel looks too large';
    return null;
  }

  /// Device serials are printed on the box lid and typed by hand.
  static String? deviceSerial(String? value) {
    final text = (value ?? '').trim().toUpperCase();
    if (text.isEmpty) return 'Enter the serial number on the box';
    if (text.length < 6) return 'That serial number looks too short';
    if (!RegExp(r'^[A-Z0-9-]+$').hasMatch(text)) {
      return 'Serial numbers use letters, numbers and dashes only';
    }
    return null;
  }
}
