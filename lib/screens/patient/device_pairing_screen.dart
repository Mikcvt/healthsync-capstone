import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_styles.dart';
import '../../models/device_model.dart';
import '../../providers/patient_provider.dart';
import '../../utils/date_formatter.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/validators.dart';

/// Pairs a smart medicine box to this patient by serial number.
///
/// Serial entry rather than QR scanning: the box's serial is printed on the lid,
/// and camera scanning needs a plugin plus a runtime permission flow that
/// belongs with the rest of the hardware work in Phase 7. What matters now is
/// that pairing creates a real `devices` document — the previous version of
/// this screen called nothing at all, so no box was ever paired.
class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serial = TextEditingController();
  bool _isPairing = false;

  @override
  void dispose() {
    _serial.dispose();
    super.dispose();
  }

  Future<void> _onPair() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isPairing = true);
    final patient = context.read<PatientProvider>();
    final paired = await patient.pairSmartBox(_serial.text.trim().toUpperCase());

    if (!mounted) return;
    setState(() => _isPairing = false);

    if (paired) {
      _serial.clear();
      SnackbarHelper.showSuccess(context, AppStrings.devicePaired);
    } else {
      SnackbarHelper.showError(
        context,
        patient.errorMessage ?? AppStrings.devicePairFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = context.select<PatientProvider, DeviceModel?>((p) => p.device);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pair your medicine box',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connect your HealthSync smart medicine box so it can light '
                  'the right compartment at each dose time.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.6,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
                const SizedBox(height: 22),

                if (device != null) _PairedCard(device: device),
                if (device != null) const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AppStyles.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.patientBlue
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.medical_services_outlined,
                              color: AppColors.patientBlue,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              device == null
                                  ? 'Smart Medicine Box'
                                  : 'Pair another box',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                fontFamily: AppStyles.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _serial,
                        textCapitalization: TextCapitalization.characters,
                        decoration: AppStyles.inputDecoration(
                          'Serial number',
                          hint: 'Printed on the box lid',
                        ),
                        validator: Validators.deviceSerial,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isPairing ? null : _onPair,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.patientBlue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.borderGray,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isPairing
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
                const SizedBox(height: 20),

                const Text(
                  'How to pair the medicine box',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '1. Power on the HealthSync box and wait for the startup beep\n'
                  '2. Find the serial number printed on the inside of the lid\n'
                  '3. Type it above and tap Pair box',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.8,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderGray),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      device == null ? 'I will do this later' : 'Done',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppStyles.fontFamily,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The box already paired to this patient.
class _PairedCard extends StatelessWidget {
  final DeviceModel device;

  const _PairedCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final isOnline = device.status == 'online';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.caregiverGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.caregiverGreen, size: 30),
          const SizedBox(width: 14),
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
                const SizedBox(height: 3),
                Text(
                  '${device.serialNumber} · '
                  '${isOnline ? AppStrings.deviceOnline : AppStrings.deviceOffline}'
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
