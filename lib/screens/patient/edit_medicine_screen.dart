import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../models/schedule_model.dart';
import '../../services/firestore_service.dart';

class EditMedicineScreen extends StatefulWidget {
  final ScheduleModel? schedule;

  const EditMedicineScreen({super.key, this.schedule});

  @override
  State<EditMedicineScreen> createState() => _EditMedicineScreenState();
}

class _EditMedicineScreenState extends State<EditMedicineScreen> {
  late TextEditingController _timeController;
  late TextEditingController _pillsController;
  late TextEditingController _thresholdController;
  late int _selectedColumn;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _timeController = TextEditingController(text: widget.schedule?.scheduledTime ?? '08:00 AM');
    _pillsController = TextEditingController(text: '${widget.schedule?.pillsRemaining ?? 30}');
    _thresholdController = TextEditingController(text: '${widget.schedule?.lowStockThreshold ?? 5}');
    _selectedColumn = widget.schedule?.matBoxColumn ?? 1;
  }

  @override
  void dispose() {
    _timeController.dispose();
    _pillsController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      setState(() {
        _timeController.text = '${hour.toString().padLeft(2, '0')}:$minute $period';
      });
    }
  }

  Future<void> _onSave() async {
    if (widget.schedule == null) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);
    final pills = int.tryParse(_pillsController.text) ?? widget.schedule!.pillsRemaining;
    final threshold = int.tryParse(_thresholdController.text) ?? widget.schedule!.lowStockThreshold;

    final updated = widget.schedule!.copyWith(
      scheduledTime: _timeController.text.trim(),
      matBoxColumn: _selectedColumn,
      pillsRemaining: pills,
      lowStockThreshold: threshold,
    );

    await FirestoreService().updateSchedule(updated);
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medication updated successfully.'),
          backgroundColor: AppColors.patientBlue,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Medication',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Schedule & Box Settings',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Update dose timing, box compartment, or refill pill inventory count.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),

              // Time Picker input
              GestureDetector(
                onTap: _pickTime,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _timeController,
                    decoration: AppStyles.inputDecoration(
                      'Scheduled Time',
                      hint: '08:00 AM',
                    ).copyWith(
                      suffixIcon: const Icon(Icons.access_time_rounded, color: AppColors.patientBlue),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Column Selector
              const Text(
                'Box Compartment',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(8, (i) {
                  final col = i + 1;
                  final selected = _selectedColumn == col;
                  return ChoiceChip(
                    label: Text('Col $col'),
                    selected: selected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedColumn = col);
                    },
                    selectedColor: AppColors.patientBlue,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: selected ? AppColors.patientBlue : AppColors.borderGray,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Refill Inventory
              TextFormField(
                controller: _pillsController,
                keyboardType: TextInputType.number,
                decoration: AppStyles.inputDecoration(
                  'Pills Remaining',
                  hint: '30',
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _thresholdController,
                keyboardType: TextInputType.number,
                decoration: AppStyles.inputDecoration(
                  'Low Stock Threshold',
                  hint: '5',
                ),
              ),
              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.patientBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Changes',
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
