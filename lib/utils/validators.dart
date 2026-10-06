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

  /// Optional by design — a managed patient often has no phone of their own,
  /// and the caregiver is the contact.
  static String? phone(String? value, {bool isRequired = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return isRequired ? 'Enter a phone number' : null;
    final digits = text.replaceAll(RegExp(r'[\s()+-]'), '');
    if (!RegExp(r'^\d{7,15}$').hasMatch(digits)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  /// `HS` plus six characters from the unambiguous alphabet. Dashes and case
  /// are forgiven here because the patient is copying from a text message.
  static String? otpCode(String? value) {
    final text = (value ?? '').trim().toUpperCase().replaceAll('-', '');
    if (text.isEmpty) return 'Enter the code your caregiver sent you';
    if (text.length != 8) return 'The code is 8 characters long';
    if (!RegExp(r'^HS[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$').hasMatch(text)) {
      return 'That does not look like a HealthSync code';
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

  /// Box compartments are physical: there are exactly eight.
  static String? boxColumn(int? value) {
    if (value == null) return 'Choose a compartment';
    if (value < 1 || value > 8) return 'Choose a compartment from 1 to 8';
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
