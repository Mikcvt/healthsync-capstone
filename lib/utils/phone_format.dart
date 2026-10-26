import 'package:flutter/services.dart';

/// Philippine mobile numbers, the only kind HealthSync accepts (BUG-016/017).
///
/// On screen the field shows a fixed `+63` and the user types the remaining
/// 10 digits, which start with 9: `961 784 0760`. Stored as `+639617840760`.
class PhPhone {
  const PhPhone._();

  static const prefix = '+63';
  static const localLength = 10;

  /// The 10 local digits of [text], whatever form it came in: `961 784 0760`,
  /// `09617840760`, `639617840760` or `+63 961 784 0760`. Returns null when
  /// [text] is not a Philippine mobile number. Empty text gives ''.
  static String? localDigits(String? text) {
    var digits = (text ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.length == 12 && digits.startsWith('63')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length != localLength || !digits.startsWith('9')) return null;
    return digits;
  }

  /// What a phone field starts with for a saved number: the spaced local
  /// digits, or '' when nothing is saved or the saved value is not valid.
  static String forField(String? stored) => spaced(localDigits(stored) ?? '');

  /// True when [stored] holds something that is not a valid number, such as
  /// the 40-digit test value saved before this rule existed.
  static bool isUnreadable(String? stored) =>
      (stored ?? '').trim().isNotEmpty && localDigits(stored) == null;

  /// The value to save for what was typed in a phone field: `+639…`, or ''
  /// for an empty field. Call only after the field validated.
  static String toStored(String fieldText) {
    final digits = localDigits(fieldText);
    return (digits == null || digits.isEmpty) ? '' : '$prefix$digits';
  }

  /// `+63 961 784 0760` for display, or [stored] unchanged when it cannot be
  /// read.
  static String display(String stored) {
    final digits = localDigits(stored);
    if (digits == null || digits.isEmpty) return stored;
    return '$prefix ${spaced(digits)}';
  }

  /// `9617840760` → `961 784 0760`, for any number of digits up to 10.
  static String spaced(String digits) {
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) b.write(' ');
      b.write(digits[i]);
    }
    return b.toString();
  }
}

/// Keeps a phone field to at most 10 digits, spaced as `961 784 0760`.
///
/// A pasted `09…`, `63…` or `+63…` number loses its prefix first, so pasting
/// a whole number from contacts works.
class PhPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > PhPhone.localLength) {
      if (digits.startsWith('63')) {
        digits = digits.substring(2);
      } else if (digits.startsWith('0')) {
        digits = digits.substring(1);
      }
    }
    if (digits.length > PhPhone.localLength) {
      digits = digits.substring(0, PhPhone.localLength);
    }
    final text = PhPhone.spaced(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
