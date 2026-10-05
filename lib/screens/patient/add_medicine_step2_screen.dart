import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/schedule_provider.dart';
import 'add_medicine_step3_screen.dart';

class AddMedicineStep2Screen extends StatefulWidget {
  const AddMedicineStep2Screen({super.key});

  @override
  State<AddMedicineStep2Screen> createState() => _AddMedicineStep2ScreenState();
}

class _AddMedicineStep2ScreenState extends State<AddMedicineStep2Screen> {
  final List<String> _times = ['08:00 AM'];
  final List<int> _selectedDays = [1, 2, 3, 4, 5, 6, 7]; // Mon=1 ... Sun=7
  final _instructionController = TextEditingController(text: 'Take after meals with water');
  final DateTime _startDate = DateTime.now();

  final List<String> _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void dispose() {
    _instructionController.dispose();
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
      final formatted = '${hour.toString().padLeft(2, '0')}:$minute $period';

      if (!_times.contains(formatted)) {
        setState(() {
          _times.add(formatted);
          _times.sort();
        });
      }
    }
  }

  void _onNext() {
    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one dose time.')),
      );
      return;
    }
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day of the week.')),
      );
      return;
    }

    context.read<ScheduleProvider>().updateStep2(
      scheduledTimes: _times,
      daysOfWeek: _selectedDays,
      startDate: _startDate,
      instructions: _instructionController.text.trim(),
    );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddMedicineStep3Screen()),
    );
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
          'Add Medicine · Step 2 of 3',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Bar
              Row(
                children: [
                  _StepBar(active: true),
                  const SizedBox(width: 8),
                  _StepBar(active: true),
                  const SizedBox(width: 8),
                  _StepBar(active: false),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'Schedule & Timing',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Set the exact times and recurring days when this medication should be taken.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 24),

              // Dose Times
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Dose Times',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.add_alarm_rounded, size: 18, color: AppColors.patientBlue),
                    label: const Text(
                      'Add Time',
                      style: TextStyle(
                        color: AppColors.patientBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _times.map((t) {
                  return Chip(
                    backgroundColor: AppColors.ledActiveBg,
                    side: const BorderSide(color: AppColors.patientBlue),
                    avatar: const Icon(Icons.access_time_rounded, size: 16, color: AppColors.patientBlue),
                    label: Text(
                      t,
                      style: const TextStyle(
                        color: AppColors.patientBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    deleteIcon: _times.length > 1
                        ? const Icon(Icons.close_rounded, size: 16, color: AppColors.patientBlue)
                        : null,
                    onDeleted: _times.length > 1
                        ? () => setState(() => _times.remove(t))
                        : null,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Days of week
              const Text(
                'Repeat on Days',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  final dayNum = index + 1;
                  final isSelected = _selectedDays.contains(dayNum);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          if (_selectedDays.length > 1) {
                            _selectedDays.remove(dayNum);
                          }
                        } else {
                          _selectedDays.add(dayNum);
                          _selectedDays.sort();
                        }
                      });
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.patientBlue : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.patientBlue : AppColors.borderGray,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _dayLabels[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Instructions
              const Text(
                'Special Instructions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _instructionController,
                maxLines: 2,
                decoration: AppStyles.inputDecoration(
                  'Instructions',
                  hint: 'e.g. Take after breakfast, avoid dairy',
                ),
              ),
              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.patientBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Continue to Smart Box', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
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

class _StepBar extends StatelessWidget {
  final bool active;
  const _StepBar({required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 5,
        decoration: BoxDecoration(
          color: active ? AppColors.patientBlue : AppColors.borderGray,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
