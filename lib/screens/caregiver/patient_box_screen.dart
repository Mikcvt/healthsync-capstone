import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_styles.dart';
import '../../models/device_model.dart';
import '../../models/patient_medication_model.dart';
import '../../models/schedule_model.dart';
import '../../providers/caregiver_provider.dart';
import '../../services/device_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/date_formatter.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/validators.dart';
import '../../widgets/shared/compartment_picker.dart';

/// A patient's smart box, from the caregiver's side: pair one, then decide
/// which compartment each medicine goes in.
///
/// The box is optional. Everything a patient needs works on the phone alone;
/// this is where they move onto the box when they get one. Compartments are
/// set here, per medicine, rather than per dose time, because a medicine's
/// 8am and 8pm doses come out of the same compartment.
class PatientBoxScreen extends StatefulWidget {
  final String patientUid;
  final String patientName;

  const PatientBoxScreen({
    super.key,
    required this.patientUid,
    required this.patientName,
  });

  @override
  State<PatientBoxScreen> createState() => _PatientBoxScreenState();
}

class _PatientBoxScreenState extends State<PatientBoxScreen> {
  final _firestore = FirestoreService();

  late final Stream<DeviceModel?> _device =
      DeviceService().streamDeviceForPatient(widget.patientUid);
  late final Stream<List<PatientMedicationModel>> _medications =
      _firestore.streamPatientMedications(widget.patientUid);
  late final Stream<List<ScheduleModel>> _schedules =
      _firestore.streamPatientSchedules(widget.patientUid);

  String get _firstName => widget.patientName.split(' ').first;

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          "$_firstName's smart box",
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            fontFamily: AppStyles.fontFamily,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<DeviceModel?>(
          stream: _device,
          builder: (context, deviceSnapshot) {
            if (deviceSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2.4),
              );
            }
            if (deviceSnapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: BoxInfoBanner(
                  icon: Icons.cloud_off_rounded,
                  color: AppColors.pendingAmber,
                  background: AppColors.pendingAmberBg,
                  message: AppStrings.offlineGeneric,
                ),
              );
            }

            final device = deviceSnapshot.data;
            if (device == null) {
              return _PairForm(
                patientUid: widget.patientUid,
                firstName: _firstName,
              );
            }

            return StreamBuilder<List<PatientMedicationModel>>(
              stream: _medications,
              builder: (context, medSnapshot) {
                return StreamBuilder<List<ScheduleModel>>(
                  stream: _schedules,
                  builder: (context, scheduleSnapshot) {
                    final loading = !medSnapshot.hasData ||
                        !scheduleSnapshot.hasData;
                    return _Compartments(
                      device: device,
                      firstName: _firstName,
                      loading: loading,
                      medications: medSnapshot.data ?? const [],
                      schedules: scheduleSnapshot.data ?? const [],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// No box yet: say what that means, and offer to pair one.
class _PairForm extends StatefulWidget {
  final String patientUid;
  final String firstName;

  const _PairForm({required this.patientUid, required this.firstName});

  @override
  State<_PairForm> createState() => _PairFormState();
}

class _PairFormState extends State<_PairForm> {
  final _formKey = GlobalKey<FormState>();
  final _serial = TextEditingController();
  bool _pairing = false;

  @override
  void dispose() {
    _serial.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _pairing = true);
    final caregiver = context.read<CaregiverProvider>();
    final ok = await caregiver.pairSmartBox(
      patientUid: widget.patientUid,
      serialNumber: _serial.text.trim().toUpperCase(),
    );
    if (!mounted) return;
    setState(() => _pairing = false);
    if (ok) {
      // The device stream flips this screen to the compartment list.
      SnackbarHelper.showSuccess(context, AppStrings.devicePaired);
    } else {
      SnackbarHelper.showError(
        context,
        caregiver.errorMessage ?? AppStrings.devicePairFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          BoxInfoBanner(
            icon: Icons.phone_android_rounded,
            message: '${widget.firstName} has no medicine box yet, and that is '
                'fine — every dose is reminded on the phone, and doses, '
                'missed alerts, stock and reports all work without one.',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppStyles.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Pair a medicine box',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Once paired, you choose a compartment for each medicine and '
                  'it lights up at dose time.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _serial,
                  textCapitalization: TextCapitalization.characters,
                  decoration: AppStyles.inputDecoration(
                    'Serial number',
                    hint: 'Printed inside the box lid',
                  ),
                  validator: Validators.deviceSerial,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _pairing ? null : _pair,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.caregiverGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.borderGray,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _pairing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Pair box',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              fontFamily: AppStyles.fontFamily,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Box paired: one row per medicine, showing where it lives.
class _Compartments extends StatelessWidget {
  final DeviceModel device;
  final String firstName;
  final bool loading;
  final List<PatientMedicationModel> medications;
  final List<ScheduleModel> schedules;

  const _Compartments({
    required this.device,
    required this.firstName,
    required this.loading,
    required this.medications,
    required this.schedules,
  });

  List<ScheduleModel> _schedulesOf(PatientMedicationModel med) =>
      schedules.where((s) => s.patMedRef == med.patMedId).toList();

  /// A medicine's compartment. Its dose times normally share one; if older
  /// data split them, the first one found is shown and a save reunites them.
  int? _columnOf(PatientMedicationModel med) {
    for (final s in _schedulesOf(med)) {
      if (s.matBoxColumn != null) return s.matBoxColumn;
    }
    return null;
  }

  Map<int, String> _occupiedExcept(PatientMedicationModel? except) {
    final occupied = <int, String>{};
    for (final med in medications) {
      if (med.patMedId == except?.patMedId) continue;
      final column = _columnOf(med);
      if (column != null) occupied[column] = med.medicationName;
    }
    return occupied;
  }

  Future<void> _choose(BuildContext context, PatientMedicationModel med) async {
    final occupied = _occupiedExcept(med);
    var selected = _columnOf(med);

    final result = await showModalBottomSheet<({int? column})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Where is ${med.medicationName} kept?',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
                if (!med.fitsInBox) ...[
                  const SizedBox(height: 10),
                  BoxInfoBanner(
                    message: 'This is a ${med.dosageForm.toLowerCase()}, which '
                        'usually does not fit a pill compartment.',
                  ),
                ],
                const SizedBox(height: 16),
                CompartmentPicker(
                  selected: selected,
                  occupied: occupied,
                  accent: AppColors.caregiverGreen,
                  onChanged: (column) => setSheet(() => selected = column),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(sheetContext, (column: selected)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.caregiverGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == null || !context.mounted) return;
    await _assign(context, med, result.column);
  }

  Future<void> _assign(
    BuildContext context,
    PatientMedicationModel med,
    int? column,
  ) async {
    final caregiver = context.read<CaregiverProvider>();
    final ok = await caregiver.assignCompartment(
      scheduleIds: _schedulesOf(med).map((s) => s.scheduleId).toList(),
      column: column,
    );
    if (!context.mounted) return;
    if (ok) {
      SnackbarHelper.showSuccess(
        context,
        column == null
            ? '${med.medicationName} will be reminded on the phone.'
            : '${med.medicationName} is now in compartment $column.',
      );
    } else {
      SnackbarHelper.showError(
        context,
        caregiver.errorMessage ?? AppStrings.genericError,
      );
    }
  }

  /// Places every unplaced tablet or capsule into the free compartments, in
  /// order — the common case right after a box is paired.
  Future<void> _fillEmpty(BuildContext context) async {
    final free = [
      for (var c = 1; c <= 8; c++)
        if (!_occupiedExcept(null).containsKey(c)) c,
    ];
    final unplaced = medications
        .where((m) => m.fitsInBox && _columnOf(m) == null)
        .toList();
    final caregiver = context.read<CaregiverProvider>();

    var placed = 0;
    for (var i = 0; i < unplaced.length && i < free.length; i++) {
      final ok = await caregiver.assignCompartment(
        scheduleIds:
            _schedulesOf(unplaced[i]).map((s) => s.scheduleId).toList(),
        column: free[i],
      );
      if (!ok) break;
      placed++;
    }
    if (!context.mounted) return;

    if (placed == 0) {
      SnackbarHelper.showError(
        context,
        caregiver.errorMessage ?? AppStrings.genericError,
      );
    } else if (placed < unplaced.length) {
      SnackbarHelper.showInfo(
        context,
        'Placed $placed. The rest stay on phone reminders — the box is full.',
      );
    } else {
      SnackbarHelper.showSuccess(
        context,
        'Placed $placed medicine${placed == 1 ? '' : 's'}. Put each one in its '
        'compartment before the next dose.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final placedCount = medications.where((m) => _columnOf(m) != null).length;
    final canFill = medications.any((m) => m.fitsInBox && _columnOf(m) == null) &&
        _occupiedExcept(null).length < 8;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _DeviceCard(device: device),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'COMPARTMENTS',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
            ),
            Text(
              '$placedCount of 8 used',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                fontFamily: AppStyles.fontFamily,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
          )
        else if (medications.isEmpty)
          BoxInfoBanner(
            message: '$firstName has no medicines yet. Add one and choose its '
                'compartment in the last step.',
          )
        else ...[
          if (canFill) ...[
            OutlinedButton.icon(
              onPressed: () => _fillEmpty(context),
              icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: const Text(
                'Fill empty compartments',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.caregiverGreen,
                minimumSize: const Size(0, 46),
                side: const BorderSide(color: AppColors.caregiverGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (final med in medications) ...[
            _MedicineRow(
              medication: med,
              column: _columnOf(med),
              onTap: () => _choose(context, med),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceModel device;

  const _DeviceCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final online = device.status == 'online';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.caregiverGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.caregiverGreen, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.deviceName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${device.serialNumber} · '
                  '${online ? AppStrings.deviceOnline : AppStrings.deviceOffline}'
                  ' · synced ${DateFormatter.toRelativeTime(device.lastSync)}',
                  style: const TextStyle(
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
    );
  }
}

class _MedicineRow extends StatelessWidget {
  final PatientMedicationModel medication;
  final int? column;
  final VoidCallback onTap;

  const _MedicineRow({
    required this.medication,
    required this.column,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inBox = column != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppStyles.cardDecoration,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: inBox ? AppColors.ledActiveBg : AppColors.blueLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: inBox
                  ? Text(
                      '$column',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ledActive,
                        fontFamily: AppStyles.fontFamily,
                      ),
                    )
                  : const Icon(Icons.phone_android_rounded,
                      color: AppColors.patientBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medication.medicationName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    inBox
                        ? 'Compartment $column · lights up at dose time'
                        : 'Not in the box · phone reminders',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
