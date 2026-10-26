import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../utils/dosage_strength.dart';

/// Amount box plus a unit menu whose choices follow the dosage form
/// (BUG-018/019). The caller owns the amount controller and the unit, and
/// saves with [DosageStrength.format].
class DosageStrengthField extends StatelessWidget {
  final TextEditingController amountController;
  final String dosageForm;
  final String unit;
  final ValueChanged<String> onUnitChanged;
  final String label;
  final Color accent;

  const DosageStrengthField({
    super.key,
    required this.amountController,
    required this.dosageForm,
    required this.unit,
    required this.onUnitChanged,
    this.label = 'Dosage strength',
    this.accent = AppColors.caregiverGreen,
  });

  @override
  Widget build(BuildContext context) {
    // A saved unit that is not in this form's list (an older free-text
    // value) is kept as a choice, so editing a medicine never changes it.
    final units = [...DosageStrength.unitsFor(dosageForm)];
    if (unit.isNotEmpty && !units.contains(unit)) units.add(unit);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [DosageAmountInputFormatter()],
            validator: DosageStrength.validateAmount,
            decoration: AppStyles.inputDecoration(label, accent: accent),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 118,
          child: DropdownButtonFormField<String>(
            // initialValue is read once; the key resets the menu when a new
            // dosage form changes the unit.
            key: ValueKey('$dosageForm/$unit'),
            initialValue: units.contains(unit) ? unit : units.first,
            isExpanded: true,
            items: [
              for (final u in units)
                DropdownMenuItem(value: u, child: Text(u)),
            ],
            onChanged: (u) {
              if (u != null) onUnitChanged(u);
            },
            decoration: AppStyles.inputDecoration('Unit', accent: accent),
          ),
        ),
      ],
    );
  }
}
