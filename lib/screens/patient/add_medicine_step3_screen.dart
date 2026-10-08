import '../../constants/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../models/patient_medication_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/device_service.dart';
import '../../widgets/shared/compartment_picker.dart';
import 'add_medicine_success_screen.dart';
import '../../utils/snackbar_helper.dart';

/// What step 3 needs to know about the patient's box before it can offer
/// compartments.
class _BoxContext {
  final bool hasBox;
  final Map<int, String> occupied;

  const _BoxContext({required this.hasBox, required this.occupied});

  /// The lookup failed, so nothing is offered that depends on it.
  static const unknown = _BoxContext(hasBox: false, occupied: {});

  int? get firstFree {
    for (var column = 1; column <= 8; column++) {
      if (!occupied.containsKey(column)) return column;
    }
    return null;
  }
}

/// Step 3: where the medicine is kept, and how much of it there is.
///
/// The box is optional. With no box paired the compartment grid is not shown
/// at all and reminders are phone-only; with one paired the caregiver picks a
/// free compartment, or "Not in the box" for things that do not fit.
class AddMedicineStep3Screen extends StatefulWidget {
  const AddMedicineStep3Screen({super.key});

  @override
  State<AddMedicineStep3Screen> createState() => _AddMedicineStep3ScreenState();
}

class _AddMedicineStep3ScreenState extends State<AddMedicineStep3Screen> {
  final _pillsCountController = TextEditingController(text: '30');
  final _thresholdController = TextEditingController(text: '5');
  bool _isSaving = false;

  late final Future<_BoxContext> _box;

  /// Set once the caregiver makes a choice. Until then the default applies:
  /// the first free compartment if the medicine fits, otherwise none.
  bool _picked = false;
  int? _pickedColumn;

  @override
  void initState() {
    super.initState();
    _box = _loadBox();
  }

  Future<_BoxContext> _loadBox() async {
    final uid = context.read<AuthProvider>().currentUid;
    if (uid == null) return _BoxContext.unknown;
    final patientUid = context.read<ScheduleProvider>().resolveSaveUid(uid);
    final devices = DeviceService();
    final hasBox = await devices.hasPairedBox(patientUid);
    if (!hasBox) return const _BoxContext(hasBox: false, occupied: {});
    return _BoxContext(
      hasBox: true,
      occupied: await devices.occupiedCompartments(patientUid),
    );
  }

  bool get _fitsInBox => PatientMedicationModel.fitsInBoxForm(
        context.read<ScheduleProvider>().dosageForm,
      );

  int? _columnFor(_BoxContext box) {
    if (!box.hasBox) return null;
    if (_picked) return _pickedColumn;
    return _fitsInBox ? box.firstFree : null;
  }

  @override
  void dispose() {
    _pillsCountController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final authProvider = context.read<AuthProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();
    final uid = authProvider.currentUid;

    if (uid == null) {
      SnackbarHelper.showError(context, 'You are not signed in.');
      return;
    }

    final pills = int.tryParse(_pillsCountController.text.trim());
    final threshold = int.tryParse(_thresholdController.text.trim());
    if (pills == null || pills < 0 || threshold == null || threshold < 0) {
      SnackbarHelper.showWarning(
        context,
        'Enter the amount on hand and the low-stock alert as whole numbers.',
      );
      return;
    }

    // The lookup has finished by the time Save can be tapped. A failed one
    // means phone reminders, never a guessed compartment.
    _BoxContext box;
    try {
      box = await _box;
    } catch (_) {
      box = _BoxContext.unknown;
    }
    if (!mounted) return;
    final column = _columnFor(box);

    scheduleProvider.updateStep3(
      matBoxColumn: column,
      pillsRemaining: pills,
      lowStockThreshold: threshold,
    );

    // saveNewMedication() resets the form on success, so capture what the
    // success screen shows before it does.
    final savedName = scheduleProvider.medicationName.trim();
    final savedTimes = List<String>.from(scheduleProvider.scheduledTimes);

    setState(() => _isSaving = true);
    // A caregiver authoring for a patient saves to that patient's uid, not
    // their own.
    final success = await scheduleProvider.saveNewMedication(
      scheduleProvider.resolveSaveUid(uid),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AddMedicineSuccessScreen(
            medicineName: savedName,
            columnNumber: column,
            scheduledTimes: savedTimes,
            hasBox: box.hasBox,
          ),
          settings: const RouteSettings(name: addMedicineFlowRoute),
        ),
      );
    } else {
      SnackbarHelper.showError(
        context,
        scheduleProvider.errorMessage ?? 'Could not save this medication.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientName =
        context.read<ScheduleProvider>().targetPatientName?.split(' ').first;
    final whose = patientName ?? 'This patient';

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
          'Add Medicine · Step 3 of 3',
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
                  _StepBar(active: true),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'Storage & Stock',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 18),

              FutureBuilder<_BoxContext>(
                future: _box,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return const BoxInfoBanner(
                      icon: Icons.cloud_off_rounded,
                      color: AppColors.pendingAmber,
                      background: AppColors.pendingAmberBg,
                      message: 'Could not check for a medicine box. This '
                          'medicine will use phone reminders; you can place it '
                          'in a compartment later from the Smart box screen.',
                    );
                  }
                  return _storageSection(snapshot.data!, whose);
                },
              ),
              const SizedBox(height: 24),

              // Kept with or without a box: stock tracking, low-stock alerts
              // and the out-of-stock guard need no hardware.
              const Text(
                'STOCK',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pillsCountController,
                keyboardType: TextInputType.number,
                decoration: AppStyles.inputDecoration(
                  _fitsInBox ? 'Pills on hand' : 'Doses on hand',
                  hint: '30',
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _thresholdController,
                keyboardType: TextInputType.number,
                decoration: AppStyles.inputDecoration(
                  'Alert me when this many are left',
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
                          'Save Medication & Finish',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _storageSection(_BoxContext box, String whose) {
    if (!box.hasBox) {
      return BoxInfoBanner(
        icon: Icons.phone_android_rounded,
        message: '$whose has no medicine box paired yet, so reminders will '
            'come on the phone only. Once a box is paired you can place this '
            'medicine in a compartment from the Smart box screen.',
      );
    }

    if (!_fitsInBox && !_picked) {
      final form = context.read<ScheduleProvider>().dosageForm.toLowerCase();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BoxInfoBanner(
            message: 'A $form does not fit a pill compartment, so this '
                'medicine stays outside the box and is reminded on the phone.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() {
                _picked = true;
                _pickedColumn = box.firstFree;
              }),
              child: const Text('Put it in a compartment anyway'),
            ),
          ),
        ],
      );
    }

    final allFull = box.firstFree == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choose the compartment it goes in. It lights up at each dose time.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
        const SizedBox(height: 14),
        if (allFull) ...[
          const BoxInfoBanner(
            message: 'All 8 compartments are in use. This medicine will be '
                'reminded on the phone.',
          ),
          const SizedBox(height: 12),
        ],
        CompartmentPicker(
          selected: _columnFor(box),
          occupied: box.occupied,
          onChanged: (column) => setState(() {
            _picked = true;
            _pickedColumn = column;
          }),
        ),
      ],
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
