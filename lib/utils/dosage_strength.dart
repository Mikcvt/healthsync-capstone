import 'package:flutter/services.dart';

/// Dosage strength as an amount plus a unit that fits the dosage form
/// (BUG-018/019). Saved as one string, `"500 mg"`, so everything that reads
/// `prescribed_dosage` is unchanged.
class DosageStrength {
  const DosageStrength._();

  /// The units offered for each dosage form; the first is the default.
  static const _units = <String, List<String>>{
    'Tablet': ['mg', 'mcg', 'g'],
    'Capsule': ['mg', 'mcg', 'g'],
    'Liquid': ['ml', 'mg/5ml'],
    'Drops': ['drops', 'ml'],
    'Inhaler': ['puff', 'mcg'],
    'Injection': ['ml', 'units', 'mg'],
  };

  /// At most 6 characters: `12500`, `2.5`, `0.25`.
  static const maxAmountLength = 6;

  static List<String> unitsFor(String dosageForm) =>
      _units[dosageForm] ?? _units['Tablet']!;

  /// Splits a saved value such as `500mg`, `500 mg` or `1 puff`. Returns null
  /// when it does not start with a number.
  static ({String amount, String unit})? parse(String? saved) {
    final match =
        RegExp(r'^\s*(\d+(?:\.\d+)?)\s*(.*?)\s*$').firstMatch(saved ?? '');
    if (match == null) return null;
    return (amount: match.group(1)!, unit: match.group(2)!);
  }

  static String format(String amount, String unit) =>
      unit.isEmpty ? amount.trim() : '${amount.trim()} $unit';

  static String? validateAmount(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter the dosage strength';
    final number = double.tryParse(text);
    if (number == null || number <= 0) return 'Enter a number above 0';
    return null;
  }
}

/// Digits and one decimal point, at most [DosageStrength.maxAmountLength]
/// characters and 2 decimals.
class DosageAmountInputFormatter extends TextInputFormatter {
  static final _allowed = RegExp(r'^\d*(\.\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.length > DosageStrength.maxAmountLength ||
        !_allowed.hasMatch(text)) {
      return oldValue;
    }
    return newValue;
  }
}
