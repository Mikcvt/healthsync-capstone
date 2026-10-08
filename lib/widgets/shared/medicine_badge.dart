import 'package:flutter/material.dart';
import '../../constants/app_styles.dart';

/// The square at the start of a dose row: "Col 3" for a medicine in a paired
/// box, otherwise an icon for its form. A phone-only medicine must never show
/// a compartment number — there is no compartment to look in.
class MedicineBadge extends StatelessWidget {
  /// The compartment to show, already resolved against whether a box is
  /// paired. Null shows the dosage-form icon.
  final int? column;
  final String dosageForm;
  final double size;
  final Color foreground;
  final Color background;

  const MedicineBadge({
    super.key,
    required this.column,
    required this.dosageForm,
    required this.foreground,
    required this.background,
    this.size = 48,
  });

  static IconData iconFor(String dosageForm) {
    switch (dosageForm.toLowerCase()) {
      case 'liquid':
      case 'drops':
        return Icons.water_drop_outlined;
      case 'inhaler':
        return Icons.air_rounded;
      case 'injection':
        return Icons.vaccines_outlined;
      default:
        return Icons.medication_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.27),
      ),
      child: column != null
          ? Text(
              'Col $column',
              style: TextStyle(
                fontSize: size < 44 ? 9.5 : 10.5,
                fontWeight: FontWeight.w800,
                color: foreground,
                fontFamily: AppStyles.fontFamily,
              ),
            )
          : Icon(iconFor(dosageForm), color: foreground, size: size * 0.45),
    );
  }
}
