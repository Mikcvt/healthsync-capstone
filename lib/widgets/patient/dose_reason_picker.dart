import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_styles.dart';

/// The reason list shared by Skip and the missed-dose screen, so both record
/// comparable reasons (DOSE_LOGIC_PROPOSAL.md, 3.4 and 7.2).
///
/// "Other reason" reveals a short text field. [onChanged] reports the reason
/// to save — the typed text for "Other", or null while "Other" is still empty.
class DoseReasonPicker extends StatefulWidget {
  final List<String> reasons;
  final ValueChanged<String?> onChanged;
  final Color accent;

  const DoseReasonPicker({
    super.key,
    required this.reasons,
    required this.onChanged,
    this.accent = AppColors.patientBlue,
  });

  @override
  State<DoseReasonPicker> createState() => _DoseReasonPickerState();
}

class _DoseReasonPickerState extends State<DoseReasonPicker> {
  final _other = TextEditingController();
  String? _selected;

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  void _report() {
    final selected = _selected;
    if (selected == AppStrings.reasonOther) {
      final text = _other.text.trim();
      widget.onChanged(text.isEmpty ? null : text);
    } else {
      widget.onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final reason in widget.reasons) ...[
          _ReasonTile(
            label: reason,
            selected: _selected == reason,
            accent: widget.accent,
            onTap: () {
              setState(() => _selected = reason);
              _report();
            },
          ),
          const SizedBox(height: 10),
        ],
        if (_selected == AppStrings.reasonOther)
          TextField(
            controller: _other,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            decoration: AppStyles.inputDecoration('What happened?'),
            onChanged: (_) => _report(),
          ),
      ],
    );
  }
}

class _ReasonTile extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _ReasonTile({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.08) : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : AppColors.borderGray,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? accent : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? accent : AppColors.textPrimary,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks why a dose is being skipped. Returns the reason, or null if the sheet
/// was dismissed.
Future<String?> showSkipReasonSheet(BuildContext context, String medicineName) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cardWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _SkipReasonSheet(medicineName: medicineName),
  );
}

class _SkipReasonSheet extends StatefulWidget {
  final String medicineName;

  const _SkipReasonSheet({required this.medicineName});

  @override
  State<_SkipReasonSheet> createState() => _SkipReasonSheetState();
}

class _SkipReasonSheetState extends State<_SkipReasonSheet> {
  String? _reason;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Why are you skipping ${widget.medicineName}?',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your caregiver will see this reason.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
              const SizedBox(height: 16),
              DoseReasonPicker(
                reasons: AppStrings.doseReasons,
                onChanged: (reason) => setState(() => _reason = reason),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _reason == null
                      ? null
                      : () => Navigator.pop(context, _reason),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.missedRed,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.borderGray,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Skip this dose',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
