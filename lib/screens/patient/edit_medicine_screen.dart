import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';

class EditMedicineScreen extends StatefulWidget {
  final String medicineName;
  final String dosage;
  final String unit;
  final String scheduleTime;
  final int selectedColumn;
  final String doctorNotes;

  const EditMedicineScreen({
    super.key,
    this.medicineName = 'Metformin',
    this.dosage = '500',
    this.unit = 'mg',
    this.scheduleTime = '8:00 PM',
    this.selectedColumn = 3,
    this.doctorNotes = 'e.g. Take with food',
  });

  @override
  State<EditMedicineScreen> createState() => _EditMedicineScreenState();
}

class _EditMedicineScreenState extends State<EditMedicineScreen> {
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _unitController;
  late TextEditingController _notesController;
  late String _selectedTime;
  late int _selectedColumn;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medicineName);
    _dosageController = TextEditingController(text: widget.dosage);
    _unitController = TextEditingController(text: widget.unit);
    _notesController = TextEditingController(text: widget.doctorNotes);
    _selectedTime = widget.scheduleTime;
    _selectedColumn = widget.selectedColumn;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _unitController.dispose();
    _notesController.dispose();
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
                    'Cancel',
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
                'Edit Medicine',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ),
            const SizedBox(width: 50), // Balance the title centering
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.borderGray),
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
                    _buildLabel('Medicine name *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      decoration: AppStyles.inputDecoration('Medicine name', hint: 'Metformin'),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Dosage *'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _dosageController,
                                keyboardType: TextInputType.number,
                                decoration: AppStyles.inputDecoration('500', hint: '500'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Unit *'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _unitController,
                                decoration: AppStyles.inputDecoration('mg', hint: 'mg'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    _buildLabel('SCHEDULE TIME *'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTimeChip('7:00 AM'),
                        _buildTimeChip('12:00 AM'),
                        _buildTimeChip('8:00 PM', isGreen: true),
                        _buildCustomChip('+ Custom'),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('ASSIGN BOX COLUMN'),
                    const SizedBox(height: 10),

                    // 6 Column Grid
                    Row(
                      children: [
                        _buildColumnBox(1, 'Amlodipine', isOccupied: true),
                        const SizedBox(width: 10),
                        _buildColumnBox(2, 'Losartan', isOccupied: true),
                        const SizedBox(width: 10),
                        _buildColumnBox(3, 'Current', isCurrent: true),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildColumnBox(4, 'Available', isAvailable: true),
                        const SizedBox(width: 10),
                        _buildColumnBox(5, 'Available', isAvailable: true),
                        const SizedBox(width: 10),
                        _buildColumnBox(6, 'Available', isAvailable: true),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Doctor\'s notes (optional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notesController,
                      decoration: AppStyles.inputDecoration('Doctor notes', hint: 'e.g. Take with food'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Save Medicine Button
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Medication updated successfully')),
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B65D4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save Medicine',
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: 0.3,
        fontFamily: 'PlusJakartaSans',
      ),
    );
  }

  Widget _buildTimeChip(String time, {bool isGreen = false}) {
    final bool isSelected = _selectedTime == time;
    return GestureDetector(
      onTap: () => setState(() => _selectedTime = time),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          time,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

  Widget _buildColumnBox(int number, String subtitle, {bool isCurrent = false, bool isOccupied = false, bool isAvailable = false}) {
    final bool isSelected = _selectedColumn == number;
    final Color bgColor = isCurrent || isSelected
        ? const Color(0xFFEBF3FF)
        : Colors.white;
    final Color borderColor = isSelected
        ? const Color(0xFF2563EB)
        : (isCurrent ? const Color(0xFF93C5FD) : AppColors.borderGray);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedColumn = number),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$number',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isSelected || isCurrent ? const Color(0xFF2563EB) : AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected || isCurrent
                      ? const Color(0xFF2563EB)
                      : (isAvailable ? AppColors.textSecondary : const Color(0xFF94A3B8)),
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
