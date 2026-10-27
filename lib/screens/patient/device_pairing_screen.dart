import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_styles.dart';
import '../../models/device_model.dart';
import '../../providers/box_provider.dart';
import '../../providers/patient_provider.dart';
import '../../services/box_link_service.dart';
import '../../utils/date_formatter.dart';
import '../../utils/snackbar_helper.dart';

/// Pairs the patient's medicine box with this phone over Bluetooth
/// (BLE_CONNECT_ON_DEMAND.md, M7, decided Oct 27, 2026).
///
/// Scan → tap the box → Android asks for the 6-digit code printed under the
/// box → the app reads the serial from the box itself and saves the box to
/// the account. Typing the serial is gone: the box reports it. The box
/// accepts a new phone only while its pairing mode is open (button held 5 s,
/// lights running), which is what step 2 says.
class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  StreamSubscription<List<FoundBox>>? _scan;
  List<FoundBox> _found = const [];
  bool _scanning = false;
  bool _searchedOnce = false;
  String? _pairingId;

  @override
  void dispose() {
    _scan?.cancel();
    super.dispose();
  }

  void _search() {
    _scan?.cancel();
    setState(() {
      _scanning = true;
      _searchedOnce = true;
      _found = const [];
    });
    final box = context.read<BoxProvider>();
    _scan = box.scan().listen(
      (list) {
        if (mounted) setState(() => _found = list);
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _scanning = false);
        SnackbarHelper.showError(
          context,
          e is BoxLinkException ? box.messageFor(e.error) : AppStrings.genericError,
        );
      },
      onDone: () {
        if (mounted) setState(() => _scanning = false);
      },
    );
  }

  Future<void> _pair(FoundBox found) async {
    await _scan?.cancel();
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _pairingId = found.remoteId;
    });
    final result = await context.read<BoxProvider>().pair(found);
    if (!mounted) return;
    setState(() => _pairingId = null);
    if (result.ok) {
      // Compartments are the care partner's to set: the security rules let
      // a patient change only the LED flag and stock count on a schedule.
      SnackbarHelper.showSuccess(
        context,
        '${result.message} Your care partner chooses a compartment for each '
        'medicine.',
      );
      Navigator.of(context).pop();
    } else {
      SnackbarHelper.showError(context, result.message);
    }
  }

  Future<void> _forget() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Forget the box on this phone?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: const Text(
          'This phone stops syncing with the box. The box stays on your '
          'account and keeps its reminders; doses you take with its button '
          'reach the app again once you pair this phone again.',
          style: TextStyle(
            height: 1.5,
            color: AppColors.textSecondary,
            fontFamily: AppStyles.fontFamily,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Forget',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.missedRed,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<BoxProvider>().forgetOnThisPhone();
  }

  @override
  Widget build(BuildContext context) {
    final device = context.select<PatientProvider, DeviceModel?>((p) => p.device);
    final box = context.watch<BoxProvider>();
    final busy = _pairingId != null;

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
          onPressed: busy ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
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
                'Connect your HealthSync box to this phone over Bluetooth, so '
                'it lights the right compartment at each dose time and the '
                'doses you take with its button reach the app. It is '
                'optional: without one, every dose is reminded on this phone.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.6,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
              const SizedBox(height: 22),

              if (device != null) ...[
                _PairedCard(device: device, pairedHere: box.isPairedHere),
                const SizedBox(height: 18),
              ],

              const _StepsCard(),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _scanning || busy || box.isBusy ? null : _search,
                  icon: _scanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.bluetooth_searching_rounded),
                  label: Text(
                    _scanning
                        ? 'Searching…'
                        : _searchedOnce
                            ? 'Search again'
                            : 'Search for my box',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.patientBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.patientBlue.withValues(alpha: 0.55),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              for (final found in _found)
                _FoundBoxTile(
                  found: found,
                  isAccountBox: device != null &&
                      found.serial ==
                          DeviceModel.normaliseSerial(device.serialNumber),
                  pairing: _pairingId == found.remoteId,
                  enabled: !busy,
                  onTap: () => _pair(found),
                ),
              if (_searchedOnce && !_scanning && _found.isEmpty && !busy)
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    AppStrings.boxNotFound,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textSecondary,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    'Pairing… When Android asks, type the 6-digit code from '
                    'the label under the box.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.patientBlue,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => Navigator.of(context).popUntil((r) => r.isFirst),
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
              if (box.isPairedHere) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: busy || box.isBusy ? null : _forget,
                    child: const Text(
                      'Forget the box on this phone',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontFamily: AppStyles.fontFamily,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppStyles.cardDecoration,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to pair',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: AppStyles.fontFamily,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '1. Switch the box on and keep it near this phone.\n'
            '2. Hold the button on the box for 5 seconds, until the lights '
            'run one after another. The box now accepts a new phone for 2 '
            'minutes.\n'
            '3. Tap Search for my box, then tap your box.\n'
            '4. Android asks for a code: type the 6-digit code from the label '
            'under the box.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.7,
              fontFamily: AppStyles.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _FoundBoxTile extends StatelessWidget {
  final FoundBox found;
  final bool isAccountBox;
  final bool pairing;
  final bool enabled;
  final VoidCallback onTap;

  const _FoundBoxTile({
    required this.found,
    required this.isAccountBox,
    required this.pairing,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final serial = found.serial;
    // Signal strength in words: the number means nothing to a patient.
    final signal = found.rssi >= -65
        ? 'Very close'
        : found.rssi >= -80
            ? 'Nearby'
            : 'Far away';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppStyles.cardDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.blueLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    color: AppColors.patientBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serial == null ? 'HealthSync box' : 'Box $serial',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontFamily: AppStyles.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAccountBox ? '$signal · Your box' : signal,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontFamily: AppStyles.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
                if (pairing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                else
                  const Text(
                    'Pair',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.patientBlue,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The box on this patient's account, and whether this phone is paired
/// with it.
class _PairedCard extends StatelessWidget {
  final DeviceModel device;
  final bool pairedHere;

  const _PairedCard({required this.device, required this.pairedHere});

  @override
  Widget build(BuildContext context) {
    final connection = !pairedHere
        ? 'Not paired with this phone yet'
        : device.lastSync == null
            ? 'Paired with this phone · not synced yet'
            : 'Paired with this phone · synced '
                '${DateFormatter.toRelativeTime(device.lastSync!)}';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pairedHere ? AppColors.greenLight : AppColors.blueLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (pairedHere ? AppColors.caregiverGreen : AppColors.patientBlue)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            pairedHere ? Icons.check_circle_rounded : Icons.bluetooth_rounded,
            color: pairedHere ? AppColors.caregiverGreen : AppColors.patientBlue,
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${device.deviceName} · ${device.serialNumber}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  connection,
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
