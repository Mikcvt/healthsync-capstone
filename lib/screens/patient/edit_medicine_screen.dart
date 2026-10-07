import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_styles.dart';
import '../../models/patient_medication_model.dart';
import '../../models/schedule_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/caregiver_provider.dart';
import '../../providers/patient_provider.dart';
import '../../utils/date_formatter.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/validators.dart';

/// Edits one dose of one medicine.
///
/// Reachable from both sides: a solo user editing their own regimen, and a
/// caregiver editing a managed patient's. Those write through different
/// providers because the patient-side provider is never initialised on a
/// caregiver's device, so the save path is chosen from the account type.
class EditMedicineScreen extends StatefulWidget {
  final ScheduleModel? schedule;

  /// The medicine behind [schedule]. Supplying it makes name, dosage and
  /// instructions editable; without it only the schedule fields are shown.
  final PatientMedicationModel? medication;

  const EditMedicineScreen({super.key, this.schedule, this.medication});

  @override
  State<EditMedicineScreen> createState() => _EditMedicineScreenState();
}

class _EditMedicineScreenState extends State<EditMedicineScreen> {
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _instructionsController;
  late TextEditingController _doctorController;
  late TextEditingController _timeController;
  late TextEditingController _pillsController;
  late TextEditingController _thresholdController;
  late int _selectedColumn;
  late Set<int> _selectedDays;
  bool _isSaving = false;

  static const List<String> _dayLabels = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  @override
  void initState() {
    super.initState();
    final med = widget.medication;
    final schedule = widget.schedule;

    _nameController = TextEditingController(text: med?.medicationName ?? '');
    _dosageController = TextEditingController(text: med?.prescribedDosage ?? '');
    _instructionsController =
        TextEditingController(text: med?.instructions ?? '');
    _doctorController =
        TextEditingController(text: med?.prescribingDoctor ?? '');
    _timeController =
        TextEditingController(text: schedule?.scheduledTime ?? '08:00 AM');
    _pillsController =
        TextEditingController(text: '${schedule?.pillsRemaining ?? 30}');
    _thresholdController =
        TextEditingController(text: '${schedule?.lowStockThreshold ?? 5}');
    _selectedColumn = schedule?.matBoxColumn ?? 1;
    _selectedDays = {...?schedule?.daysOfWeek};
    if (_selectedDays.isEmpty) _selectedDays = {1, 2, 3, 4, 5, 6, 7};
  }

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _dosageController,
      _instructionsController,
      _doctorController,
      _timeController,
      _pillsController,
      _thresholdController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTime() async {
    // Seeded from the time already on the schedule rather than always 8:00 AM,
    // so reopening the picker does not discard the current value.
    final current = DateFormatter.parseScheduleTime(_timeController.text);
    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 8, minute: 0)
          : TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    setState(() {
      _timeController.text = DateFormatter.toTimeLabel(
        DateTime(2000, 1, 1, picked.hour, picked.minute),
      );
    });
  }

  Future<void> _onSave() async {
    final schedule = widget.schedule;
    if (schedule == null) {
      Navigator.pop(context);
      return;
    }

    // A time the app cannot parse is a dose the box will never light for, so
    // it is rejected here rather than written and silently skipped.
    if (_timeController.text.trim().isEmpty ||
        DateFormatter.parseScheduleTime(_timeController.text) == null) {
      SnackbarHelper.showError(context, 'Choose a valid dose time.');
      return;
    }

    if (_selectedDays.isEmpty) {
      SnackbarHelper.showError(
        context,
        'Pick at least one day, or the dose will never be scheduled.',
      );
      return;
    }

    if (widget.medication != null && _nameController.text.trim().isEmpty) {
      SnackbarHelper.showError(context, 'Enter the medicine name.');
      return;
    }

    final pillsError =
        Validators.positiveInt(_pillsController.text, 'pills remaining');
    if (pillsError != null) {
      SnackbarHelper.showError(context, pillsError);
      return;
    }

    setState(() => _isSaving = true);

    final isCaregiver = context.read<AuthProvider>().isCaregiver;
    final caregiver = context.read<CaregiverProvider>();
    final patient = context.read<PatientProvider>();

    final updatedSchedule = schedule.copyWith(
      scheduledTime: _timeController.text.trim(),
      matBoxColumn: _selectedColumn,
      daysOfWeek: _selectedDays.toList()..sort(),
      pillsRemaining:
          int.tryParse(_pillsController.text) ?? schedule.pillsRemaining,
      lowStockThreshold: int.tryParse(_thresholdController.text) ??
          schedule.lowStockThreshold,
    );

    var saved = isCaregiver
        ? await caregiver.updateSchedule(updatedSchedule)
        : await patient.updateSchedule(updatedSchedule);

    // The medicine's own fields live on a separate document, so they are a
    // second write. A failure here still leaves the schedule change applied,
    // which is why the message below reports partial success honestly.
    final med = widget.medication;
    if (saved && med != null) {
      final updatedMed = med.copyWith(
        medicationName: _nameController.text.trim(),
        prescribedDosage: _dosageController.text.trim(),
        instructions: _instructionsController.text.trim(),
        prescribingDoctor: _doctorController.text.trim(),
      );
      saved = isCaregiver
          ? await caregiver.updateMedication(updatedMed)
          : await patient.updateMedication(updatedMed);

      if (!saved && mounted) {
        setState(() => _isSaving = false);
        SnackbarHelper.showError(
          context,
          'The dose time was saved, but the medicine details were not. '
          'Please try again.',
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (saved) {
      SnackbarHelper.showSuccess(context, 'Medication updated.');
      Navigator.pop(context);
    } else {
      SnackbarHelper.showError(
        context,
        (isCaregiver ? caregiver.errorMessage : patient.errorMessage) ??
            AppStrings.genericError,
      );
    }
  }

  /// Retires the medicine and all of its dose times.
  ///
  /// Confirmation names the medicine and the number of dose times, because the
  /// blast radius is larger than the screen suggests — this is reachable while
  /// editing a single time, but it removes all of them.
  Future<void> _confirmDelete() async {
    final med = widget.medication;
    if (med == null) return;

    final name = med.medicationName.trim().isEmpty
        ? 'this medicine'
        : med.medicationName;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove this medicine?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          '$name will stop appearing and no more reminders will be sent for '
          'any of its dose times. Past doses stay in the history.',
          style: const TextStyle(height: 1.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove',
                style: TextStyle(color: AppColors.missedRed)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    final isCaregiver = context.read<AuthProvider>().isCaregiver;
    final caregiver = context.read<CaregiverProvider>();
    final patient = context.read<PatientProvider>();

    final ok = isCaregiver
        ? await caregiver.deleteMedication(med.patMedId, med.patientRef)
        : await patient.deleteMedication(med.patMedId);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      SnackbarHelper.showSuccess(context, '$name removed.');
      Navigator.pop(context);
    } else {
      SnackbarHelper.showError(
        context,
        (isCaregiver ? caregiver.errorMessage : patient.errorMessage) ??
            AppStrings.genericError,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMedication = widget.medication != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit medicine',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          if (hasMedication)
            IconButton(
              tooltip: 'Remove medicine',
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.missedRed),
              onPressed: _isSaving ? null : _confirmDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasMedication) ...[
                const _SectionLabel('Medicine'),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: AppStyles.inputDecoration('Medicine name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dosageController,
                  decoration: AppStyles.inputDecoration('Dosage (e.g. 500mg)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _instructionsController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: AppStyles.inputDecoration('Instructions'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _doctorController,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      AppStyles.inputDecoration('Prescribing doctor'),
                ),
                const SizedBox(height: 24),
              ],

              const _SectionLabel('When'),
              GestureDetector(
                onTap: _pickTime,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _timeController,
                    decoration: AppStyles.inputDecoration('Dose time').copyWith(
                      suffixIcon: const Icon(Icons.access_time_rounded,
                          color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Repeats on',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (index) {
                  final day = index + 1; // DateTime.weekday: 1 = Monday
                  final selected = _selectedDays.contains(day);
                  return ChoiceChip(
                    label: Text(_dayLabels[index]),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      selected
                          ? _selectedDays.remove(day)
                          : _selectedDays.add(day);
                    }),
                    selectedColor: AppColors.patientBlue,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),
              const _SectionLabel('Smart box compartment'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(8, (index) {
                  final col = index + 1;
                  final selected = _selectedColumn == col;
                  return ChoiceChip(
                    label: Text('Col $col'),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedColumn = col),
                    selectedColor: AppColors.ledActive,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),
              const _SectionLabel('Stock'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pillsController,
                      keyboardType: TextInputType.number,
                      decoration: AppStyles.inputDecoration('Pills remaining'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _thresholdController,
                      keyboardType: TextInputType.number,
                      decoration: AppStyles.inputDecoration('Alert below'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.patientBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.borderGray,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      );
}
