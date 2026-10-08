import '../../constants/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/schedule_provider.dart';
import 'add_medicine_step3_screen.dart';
import '../../utils/date_formatter.dart';
import '../../utils/snackbar_helper.dart';

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
          _sortByTimeOfDay(_times);
        });
      }
    }
  }

  /// Builds a whole day of doses from an interval.
  ///
  /// Most prescriptions are written as "every N hours", and entering six times
  /// by hand is where people give up. The waking-hours option is deliberate:
  /// "every 4 hours" on a chart usually means while awake, and generating a
  /// 2 AM alarm nobody intends to honour teaches patients to ignore reminders.
  Future<void> _openIntervalSheet() async {
    int interval = 8;
    TimeOfDay start = const TimeOfDay(hour: 8, minute: 0);
    bool wakingOnly = true;

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final preview = _buildIntervalTimes(
            start: start,
            intervalHours: interval,
            wakingOnly: wakingOnly,
          );

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Repeat every…',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'We will work out the dose times for you.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),

                Wrap(
                  spacing: 8,
                  children: [4, 6, 8, 12].map((h) {
                    final selected = interval == h;
                    return ChoiceChip(
                      label: Text('$h hours'),
                      selected: selected,
                      onSelected: (_) => setSheet(() => interval = h),
                      selectedColor: AppColors.patientBlue,
                      labelStyle: TextStyle(
                        color:
                            selected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    const Text(
                      'First dose',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: sheetContext,
                          initialTime: start,
                        );
                        if (picked != null) setSheet(() => start = picked);
                      },
                      icon: const Icon(Icons.access_time_rounded, size: 18),
                      label: Text(
                        _formatTimeOfDay(start),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: wakingOnly,
                  onChanged: (v) => setSheet(() => wakingOnly = v),
                  activeThumbColor: AppColors.patientBlue,
                  title: const Text(
                    'Only while awake',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Skips doses between 10 PM and 6 AM.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),

                const SizedBox(height: 8),
                Text(
                  preview.isEmpty
                      ? 'No dose times fit — try a shorter gap or turn off "only while awake".'
                      : '${preview.length} doses a day: ${preview.join(' · ')}',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: preview.isEmpty
                        ? AppColors.missedRed
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: preview.isEmpty
                        ? null
                        : () => Navigator.pop(sheetContext, preview),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.patientBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Use these times',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      // Replaces rather than appends: the generated set is the whole plan, and
      // merging would leave stray times from an earlier attempt.
      setState(() => _times
        ..clear()
        ..addAll(result));
    }
  }

  static String _formatTimeOfDay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  /// Dose times from [start], every [intervalHours], within one day.
  static List<String> _buildIntervalTimes({
    required TimeOfDay start,
    required int intervalHours,
    required bool wakingOnly,
  }) {
    const wakeHour = 6;
    const sleepHour = 22;

    final times = <String>[];
    var minutes = start.hour * 60 + start.minute;
    final limit = minutes + 24 * 60;

    while (minutes < limit) {
      final hour = (minutes ~/ 60) % 24;
      final minute = minutes % 60;

      final awake = hour >= wakeHour && hour < sleepHour;
      if (!wakingOnly || awake) {
        times.add(_formatTimeOfDay(TimeOfDay(hour: hour, minute: minute)));
      }
      minutes += intervalHours * 60;
    }

    return _sortByTimeOfDay(times.toSet().toList());
  }

  /// "06:00 PM" sorts before "12:00 PM" as text, so order by the clock.
  static List<String> _sortByTimeOfDay(List<String> times) => times
    ..sort((a, b) =>
        DateFormatter.minutesOfDay(a).compareTo(DateFormatter.minutesOfDay(b)));

  void _onNext() {
    if (_times.isEmpty) {
      SnackbarHelper.showWarning(
        context,
        'Choose at least one dose time.',
      );
      return;
    }
    if (_selectedDays.isEmpty) {
      SnackbarHelper.showWarning(
        context,
        'Choose at least one day of the week.',
      );
      return;
    }

    context.read<ScheduleProvider>().updateStep2(
      scheduledTimes: List<String>.from(_times),
      daysOfWeek: _selectedDays,
      startDate: _startDate,
      instructions: _instructionController.text.trim(),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddMedicineStep3Screen(),
        settings: const RouteSettings(name: addMedicineFlowRoute),
      ),
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
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _openIntervalSheet,
                        icon: const Icon(Icons.repeat_rounded,
                            size: 18, color: AppColors.patientBlue),
                        label: const Text(
                          'Every…',
                          style: TextStyle(
                            color: AppColors.patientBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.add_alarm_rounded,
                            size: 18, color: AppColors.patientBlue),
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
