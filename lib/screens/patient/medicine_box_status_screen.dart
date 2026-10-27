import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_styles.dart';
import '../../providers/box_provider.dart';
import '../../providers/patient_provider.dart';
import '../../models/device_model.dart';
import '../../services/box_link_service.dart';
import '../../services/device_service.dart';
import '../../utils/date_formatter.dart';
import '../../utils/snackbar_helper.dart';
import 'device_pairing_screen.dart';
import '../../widgets/shared/floating_nav_bar.dart';
import '../../widgets/shared/medicine_badge.dart';

/// Live view of the physical 6-compartment box, and the Sync button.
///
/// Everything here comes from the `devices` and `schedules` streams. The
/// previous version reported "Online · 84% battery · 4 minutes ago" as fixed
/// text, for a device that may not have been paired at all.
class MedicineBoxStatusScreen extends StatelessWidget {
  const MedicineBoxStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<PatientProvider>();
    final device = patient.device;
    final compartments =
        DeviceService().buildCompartmentGrid(patient.schedules);
    // Medicines with no compartment on any of their dose times.
    final outside = patient.medications
        .where((m) => patient.schedules
            .where((s) => s.patMedRef == m.patMedId)
            .every((s) => s.matBoxColumn == null))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Medicine box',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontFamily: AppStyles.fontFamily,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // Clears the floating nav bar; this is a tab.
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            FloatingNavBar.contentPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: device == null
                ? const [_NoDeviceCard()]
                : [
                    _DeviceCard(device: device),
                    const SizedBox(height: 24),
                    const Text(
                      'Compartments',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontFamily: AppStyles.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (compartments.every((c) => !c.isAssigned))
                      const Text(
                        'Your care partner has not placed any medicine in the '
                        'box yet.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.5,
                          fontFamily: AppStyles.fontFamily,
                        ),
                      )
                    else
                      const _Legend(),
                    const SizedBox(height: 14),
                    GridView.count(
                      // Six compartments: two rows of three.
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 10,
                      // Tall enough for icon, column, a two-line name and the
                      // pill count on a 360dp-wide phone at 1.3x text.
                      childAspectRatio: 0.8,
                      children: [
                        for (final compartment in compartments)
                          _CompartmentTile(
                            compartment: compartment,
                            medicineName: compartment.schedule == null
                                ? ''
                                : patient
                                    .medicationNameFor(compartment.schedule!),
                          ),
                      ],
                    ),
                    if (outside.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Outside the box',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontFamily: AppStyles.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Kept in their own packs. Reminders for these come on '
                        'this phone only.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.5,
                          fontFamily: AppStyles.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final med in outside)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: AppStyles.cardDecoration,
                          child: Row(
                            children: [
                              MedicineBadge(
                                column: null,
                                dosageForm: med.dosageForm,
                                size: 40,
                                foreground: AppColors.patientBlue,
                                background: AppColors.blueLight,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  med.medicationName,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    fontFamily: AppStyles.fontFamily,
                                  ),
                                ),
                              ),
                              Text(
                                med.doseDescription,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                  fontFamily: AppStyles.fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
          ),
        ),
      ),
    );
  }
}

class _NoDeviceCard extends StatelessWidget {
  const _NoDeviceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.phone_android_rounded,
                  color: AppColors.patientBlue, size: 26),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No medicine box yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            AppStrings.noDevicePaired,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.55,
              color: AppColors.textSecondary,
              fontFamily: AppStyles.fontFamily,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DevicePairingScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.patientBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Pair a box',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The box on the account and this phone's Bluetooth link to it
/// (BoxProvider). The box is connect-on-demand, so there is no "online":
/// what matters is whether this phone is paired with it and when they last
/// synced.
class _DeviceCard extends StatelessWidget {
  final DeviceModel device;

  const _DeviceCard({required this.device});

  Future<void> _sync(BuildContext context) async {
    final result = await context.read<BoxProvider>().syncNow();
    if (!context.mounted) return;
    if (result.ok) {
      SnackbarHelper.showSuccess(context, result.message);
    } else {
      SnackbarHelper.showError(context, result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = context.watch<BoxProvider>();
    final error = box.lastError;
    final syncedRecently = device.lastSync != null &&
        DateTime.now().difference(device.lastSync!) < DeviceModel.onlineWindow;

    final String status;
    final Color dot;
    if (!box.isPairedHere) {
      status = 'Not paired with this phone';
      dot = AppColors.textMuted;
    } else if (box.pairedBoxMismatch) {
      status = 'Paired with another box';
      dot = AppColors.missedRed;
    } else if (box.isBusy) {
      status = 'Syncing with the box…';
      dot = AppColors.ledActive;
    } else if (error != null) {
      status = 'Last sync did not finish';
      dot = AppColors.missedRed;
    } else if (syncedRecently) {
      status = 'Synced';
      // Green is a status signal, so the dot keeps it; the rest of this
      // patient screen is patient blue.
      dot = AppColors.caregiverGreen;
    } else {
      status = 'Paired with this phone';
      dot = AppColors.patientBlue;
    }

    final String? detail = !box.isPairedHere
        ? 'Pair it so the box gets your schedule and the doses you take with '
            'its button reach the app.'
        : box.pairedBoxMismatch
            ? AppStrings.boxWrongSerial(
                box.pairedSerial ?? '', device.serialNumber)
            : !box.isBusy && error != null
                ? box.messageFor(error)
                : box.lastNote;
    final needsPairing = !box.isPairedHere ||
        box.pairedBoxMismatch ||
        error == BoxLinkError.notPaired;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
              ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(
              detail,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textSecondary,
                fontFamily: AppStyles.fontFamily,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _StatRow(label: 'Device', value: device.deviceName),
          const Divider(height: 22, color: AppColors.borderGray),
          _StatRow(label: 'Serial', value: device.serialNumber),
          const Divider(height: 22, color: AppColors.borderGray),
          _StatRow(
            label: 'Last sync',
            value: DateFormatter.lastSync(device.lastSync),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: needsPairing
                ? ElevatedButton.icon(
                    onPressed: box.isBusy
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DevicePairingScreen(),
                              ),
                            ),
                    icon: const Icon(Icons.bluetooth_rounded, size: 20),
                    label: Text(
                      box.isPairedHere ? 'Pair again' : 'Pair this phone',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFamily: AppStyles.fontFamily,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.patientBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: box.isBusy ? null : () => _sync(context),
                    icon: box.isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded, size: 20),
                    label: Text(
                      box.isBusy ? 'Syncing…' : 'Sync with box',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFamily: AppStyles.fontFamily,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.patientBlue,
                      side: const BorderSide(color: AppColors.patientBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontFamily: AppStyles.fontFamily,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFamily: AppStyles.fontFamily,
          ),
        ),
      ],
    );
  }
}

/// One compartment. Amber when lit (the colour of the LED on the box), blue
/// when in use, grey when empty; low stock is a red "Low" on the count. Keep
/// [_Legend] in step with any change here.
class _CompartmentTile extends StatelessWidget {
  final BoxCompartment compartment;
  final String medicineName;

  const _CompartmentTile({
    required this.compartment,
    required this.medicineName,
  });

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color accent;

    if (!compartment.isAssigned) {
      background = AppColors.ledEmpty;
      accent = AppColors.textMuted;
    } else if (compartment.ledActive) {
      background = AppColors.ledActiveBg;
      accent = AppColors.ledActive;
    } else {
      // A filled compartment, not lit: patient blue. Lit stays amber, the
      // colour of the real LED on the box. Low stock used to be a second,
      // near-identical amber that the legend never explained (BUG-024); it
      // is now a red "Low" on the pill count instead.
      background = AppColors.blueLight;
      accent = AppColors.patientBlue;
    }
    final lowStock = compartment.isAssigned && compartment.isLowStock;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            compartment.ledActive
                ? Icons.lightbulb
                : Icons.lightbulb_outline_rounded,
            color: accent,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            'Col ${compartment.columnNumber}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: accent,
              fontFamily: AppStyles.fontFamily,
            ),
          ),
          const SizedBox(height: 3),
          // Flexible lets a long name give up its second line instead of
          // pushing the pill count off the bottom of the tile.
          Flexible(
            child: Text(
              compartment.isAssigned ? medicineName : 'Empty',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                height: 1.25,
                fontFamily: AppStyles.fontFamily,
              ),
            ),
          ),
          if (compartment.isAssigned) ...[
            const SizedBox(height: 3),
            Text(
              lowStock
                  ? '${compartment.pillsRemaining} left · Low'
                  : '${compartment.pillsRemaining} left',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: lowStock ? AppColors.missedRed : AppColors.textMuted,
                fontFamily: AppStyles.fontFamily,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What the tile colours mean (BUG-024). The old single line explained only
/// amber, so a lit tile next to a blue one looked like a colour change.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _LegendItem(
          color: AppColors.ledActive,
          background: AppColors.ledActiveBg,
          label: 'Lit on the box now',
        ),
        _LegendItem(
          color: AppColors.patientBlue,
          background: AppColors.blueLight,
          label: 'In use',
        ),
        _LegendItem(
          color: AppColors.textMuted,
          background: AppColors.ledEmpty,
          label: 'Empty',
        ),
        _LegendItem(
          color: AppColors.missedRed,
          background: AppColors.missedRedBg,
          label: '"Low": refill soon',
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final Color background;
  final String label;

  const _LegendItem({
    required this.color,
    required this.background,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontFamily: AppStyles.fontFamily,
          ),
        ),
      ],
    );
  }
}
