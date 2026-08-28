import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import 'add_medicine_step2_screen.dart';

class AddMedicineStep1Screen extends StatefulWidget {
  const AddMedicineStep1Screen({super.key});

  @override
  State<AddMedicineStep1Screen> createState() => _AddMedicineStep1ScreenState();
}

class _AddMedicineStep1ScreenState extends State<AddMedicineStep1Screen> {
  final _nameController = TextEditingController(text: 'Metformin');
  final _brandController = TextEditingController(text: 'Glucophage');
  final _dosageController = TextEditingController(text: '500');
  final _unitController = TextEditingController(text: 'mg');
  final _qtyController = TextEditingController(text: '1');
  final _totalPillsController = TextEditingController(text: '30');
  final _prescribedController = TextEditingController(text: 'Dr. Adia Fernandez');
  final _purposeController = TextEditingController(text: 'Blood sugar management');
  final _notesController = TextEditingController(text: 'e.g. Take with food');

  String _selectedForm = 'Tablet';

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _dosageController.dispose();
    _unitController.dispose();
    _qtyController.dispose();
    _totalPillsController.dispose();
    _prescribedController.dispose();
    _purposeController.dispose();
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
              '1/3',
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
                          color: const Color(0xFFE2E8F0),
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
                  'Step 1: Medicine Information',
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
                    _buildLabel('Medicine name *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      decoration: AppStyles.inputDecoration('Medicine name', hint: 'e.g. Metformin'),
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Brand name (optional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _brandController,
                      decoration: AppStyles.inputDecoration('Brand name', hint: 'e.g. Glucophage'),
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
                    const SizedBox(height: 16),

                    _buildLabel('Form *'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildFormChip('Tablet'),
                        const SizedBox(width: 10),
                        _buildFormChip('Capsule'),
                        const SizedBox(width: 10),
                        _buildFormChip('+'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Quantity per dose *'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _qtyController,
                                keyboardType: TextInputType.number,
                                decoration: AppStyles.inputDecoration('1', hint: '1'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Total pills to load *'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _totalPillsController,
                                keyboardType: TextInputType.number,
                                decoration: AppStyles.inputDecoration('30', hint: '30'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Prescribed by (optional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _prescribedController,
                      decoration: AppStyles.inputDecoration('Dr. name', hint: 'Dr. Adia Fernandez'),
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Purpose / Condition'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _purposeController,
                      decoration: AppStyles.inputDecoration('Purpose', hint: 'Blood sugar management'),
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Doctor\'s notes (optional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: AppStyles.inputDecoration('Notes', hint: 'e.g. Take with food'),
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
                        builder: (_) => const AddMedicineStep2Screen(),
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        fontFamily: 'PlusJakartaSans',
      ),
    );
  }

  Widget _buildFormChip(String label) {
    final bool isSelected = _selectedForm == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedForm = label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEBF3FF) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : AppColors.borderGray,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
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
      ),
    );
  }
}
