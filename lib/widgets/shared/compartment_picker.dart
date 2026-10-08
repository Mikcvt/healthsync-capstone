import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';

/// Chooses where a medicine lives: one of the box's eight compartments, or
/// "Not in the box".
///
/// A compartment in [occupied] already holds another medicine and cannot be
/// picked — two medicines in one compartment would light one LED for both.
class CompartmentPicker extends StatelessWidget {
  /// The chosen compartment, or null for "Not in the box".
  final int? selected;
  final Map<int, String> occupied;
  final ValueChanged<int?> onChanged;
  final Color accent;

  const CompartmentPicker({
    super.key,
    required this.selected,
    required this.occupied,
    required this.onChanged,
    this.accent = AppColors.patientBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.95,
          ),
          itemCount: 8,
          itemBuilder: (context, index) {
            final column = index + 1;
            return _CompartmentTile(
              column: column,
              selected: selected == column,
              takenBy: occupied[column],
              accent: accent,
              onTap: () => onChanged(column),
            );
          },
        ),
        const SizedBox(height: 10),
        _NotInBoxTile(
          selected: selected == null,
          accent: accent,
          onTap: () => onChanged(null),
        ),
      ],
    );
  }
}

class _CompartmentTile extends StatelessWidget {
  final int column;
  final bool selected;
  final String? takenBy;
  final Color accent;
  final VoidCallback onTap;

  const _CompartmentTile({
    required this.column,
    required this.selected,
    required this.takenBy,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final taken = takenBy != null;
    final foreground = selected
        ? Colors.white
        : taken
            ? AppColors.textMuted
            : AppColors.textPrimary;

    return Semantics(
      button: true,
      enabled: !taken,
      selected: selected,
      label: taken
          ? 'Compartment $column, used by $takenBy'
          : 'Compartment $column',
      child: GestureDetector(
        onTap: taken ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? accent
                : taken
                    ? AppColors.background
                    : AppColors.cardWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent : AppColors.borderGray,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                taken ? Icons.lock_outline_rounded : Icons.lightbulb_outline_rounded,
                size: 18,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(height: 3),
              Text(
                '$column',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
              if (taken)
                Text(
                  takenBy!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.textMuted,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotInBoxTile extends StatelessWidget {
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _NotInBoxTile({
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.08) : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : AppColors.borderGray,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? accent : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Not in the box',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Kept in its own pack. Reminders come on the phone only.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tinted note explaining how reminders will work without the box.
class BoxInfoBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  final Color background;

  const BoxInfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.color = AppColors.blueDark,
    this.background = AppColors.blueLight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: color,
                fontFamily: AppStyles.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
