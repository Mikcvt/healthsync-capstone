import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import 'add_medicine_step3_screen.dart';

class AddMedicineStep2Screen extends StatefulWidget {
  const AddMedicineStep2Screen({super.key});

  @override
  State<AddMedicineStep2Screen> createState() => _AddMedicineStep2ScreenState();
}

class _AddMedicineStep2ScreenState extends State<AddMedicineStep2Screen> {
  String _selectedTime = '8:00 PM';
  String _selectedFrequency = 'Daily';
  final Set<String> _selectedTakeWith = {'Water'};
  final Set<String> _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'};
  String _selectedReminder = 'At dose time';

  final _startDateController = TextEditingController(text: '19/05/2026');
  final _endDateController = TextEditingController(text: '19/06/2026');

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Row(
                children: [
                  Icon(Icons.chevron_left_rounded, color: Color(0xFF2563EB), size: 20),
                  Text(
                    'Back',
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Text(
                'Add Medicine',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ),
            const Text(
              '2/3',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.caregiverGreen,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Step 2: Schedule & Timing',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.borderGray),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('SCHEDULE TIME *'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTimeChip('7:00 AM'),
                        _buildTimeChip('12:00 PM'),
                        _buildTimeChip('8:00 PM', highlightGreen: true),
                        _buildCustomChip('+ Custom'),
                      ],
                    ),
                    const SizedBox(height: 18),

                    _buildSectionHeader('FREQUENCY *'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSelectChip('Daily', _selectedFrequency, (val) => setState(() => _selectedFrequency = val)),
                        _buildSelectChip('Every 2 days', _selectedFrequency, (val) => setState(() => _selectedFrequency = val)),
                        _buildCustomChip('+ Custom'),
                      ],
                    ),
                    const SizedBox(height: 18),

                    _buildSectionHeader('Take with'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildMultiChip('Water'),
                        _buildMultiChip('Food'),
                        _buildMultiChip('Milk'),
                        _buildMultiChip('Before meal'),
                        _buildMultiChip('After meal'),
                      ],
                    ),
                    const SizedBox(height: 18),

                    _buildSectionHeader('Start date *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _startDateController,
                      decoration: AppStyles.inputDecoration('DD/MM/YYYY', hint: '19/05/2026'),
                    ),
                    const SizedBox(height: 16),

                    _buildSectionHeader('End date (optional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _endDateController,
                      decoration: AppStyles.inputDecoration('DD/MM/YYYY', hint: '19/06/2026'),
                    ),
                    const SizedBox(height: 18),

                    _buildSectionHeader('Days of the week'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildDayChip('Mon'),
                        const SizedBox(width: 6),
                        _buildDayChip('Tue'),
                        const SizedBox(width: 6),
                        _buildDayChip('Wed'),
                        const SizedBox(width: 6),
                        _buildDayChip('Thu'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildDayChip('Fri'),
                        const SizedBox(width: 6),
                        _buildDayChip('Sat'),
                        const SizedBox(width: 6),
                        _buildDayChip('Sun'),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 18),

                    _buildSectionHeader('Reminder 1'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildReminderChip('At dose time', isGreen: true),
                        _buildReminderChip('5 min before', isGreen: false),
                        _buildCustomChip('+'),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.borderGray)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddMedicineStep3Screen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.patientBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: 0.5,
        fontFamily: 'PlusJakartaSans',
      ),
    );
  }

  Widget _buildTimeChip(String time, {bool highlightGreen = false}) {
    final bool isSelected = _selectedTime == time;
    return GestureDetector(
      onTap: () => setState(() => _selectedTime = time),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (highlightGreen ? const Color(0xFFEAF8F1) : const Color(0xFFEBF3FF))
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (highlightGreen ? const Color(0xFF0D9B6B) : const Color(0xFF2563EB))
                : AppColors.borderGray,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          time,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? (highlightGreen ? const Color(0xFF0D9B6B) : const Color(0xFF2563EB))
                : AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
      ),
    );
  }

  Widget _buildSelectChip(String label, String currentSelected, Function(String) onSelect) {
    final bool isSelected = currentSelected == label;
    return GestureDetector(
      onTap: () => onSelect(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEBF3FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : AppColors.borderGray,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? const Color(0xFF2563EB) : AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
      ),
    );
  }

  Widget _buildMultiChip(String label) {
    final bool isSelected = _selectedTakeWith.contains(label);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedTakeWith.remove(label);
          } else {
            _selectedTakeWith.add(label);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEBF3FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : AppColors.borderGray,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? const Color(0xFF2563EB) : AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
      ),
    );
  }

  Widget _buildDayChip(String day) {
    final bool isSelected = _selectedDays.contains(day);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedDays.remove(day);
            } else {
              _selectedDays.add(day);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEBF3FF) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : AppColors.borderGray,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            day,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? const Color(0xFF2563EB) : AppColors.textPrimary,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReminderChip(String label, {required bool isGreen}) {
    final bool isSelected = _selectedReminder == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedReminder = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isGreen ? const Color(0xFFEAF8F1) : const Color(0xFFEBF3FF))
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isGreen ? const Color(0xFF0D9B6B) : const Color(0xFF2563EB))
                : AppColors.borderGray,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? (isGreen ? const Color(0xFF0D9B6B) : const Color(0xFF2563EB))
                : AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
      ),
    );
  }

  Widget _buildCustomChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          fontFamily: 'PlusJakartaSans',
        ),
      ),
    );
  }
}
