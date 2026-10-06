import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_styles.dart';
import '../../providers/patient_provider.dart';
import '../../models/device_model.dart';
import '../../services/device_service.dart';
import '../../utils/date_formatter.dart';
import 'device_pairing_screen.dart';

/// Live view of the physical 8-compartment box.
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (device == null)
                const _NoDeviceCard()
              else
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
              Text(
                patient.schedules.isEmpty
                    ? 'No compartments assigned yet.'
                    : 'An amber light means that compartment is lit on the box '
                        'right now.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.5,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
              const SizedBox(height: 14),

              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
                children: [
                  for (final compartment in compartments)
                    _CompartmentTile(
                      compartment: compartment,
                      medicineName: compartment.schedule == null
                          ? ''
                          : patient.medicationNameFor(compartment.schedule!),
                    ),
                ],
              ),
              const SizedBox(height: 16),
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
              Icon(Icons.inbox_outlined, color: AppColors.textMuted, size: 26),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppStrings.noDevicePaired,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                    fontFamily: AppStyles.fontFamily,
                  ),
                ),
              ),
            ],
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

class _DeviceCard extends StatelessWidget {
  final DeviceModel device;

  const _DeviceCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final isOnline = device.isOnline;
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isOnline ? AppColors.caregiverGreen : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isOnline ? AppStrings.deviceOnline : AppStrings.deviceOffline,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isOnline
                      ? AppColors.caregiverGreen
                      : AppColors.textSecondary,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StatRow(label: 'Device', value: device.deviceName),
          const Divider(height: 22, color: AppColors.borderGray),
          _StatRow(label: 'Serial', value: device.serialNumber),
          const Divider(height: 22, color: AppColors.borderGray),
          _StatRow(
            label: 'Last sync',
            value: DateFormatter.toRelativeTime(device.lastSync),
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

/// One of the eight compartments. Colour follows the LED column palette in
/// `AppColors`: amber when lit, green when stocked and idle, grey when unused.
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
    } else if (compartment.isLowStock) {
      background = AppColors.pendingAmberBg;
      accent = AppColors.pendingAmber;
    } else {
      background = AppColors.ledDoneBg;
      accent = AppColors.ledDone;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            compartment.ledActive
                ? Icons.lightbulb
                : Icons.lightbulb_outline_rounded,
            color: accent,
            size: 22,
          ),
          const SizedBox(height: 6),
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
          Text(
            compartment.isAssigned ? medicineName : 'Empty',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              height: 1.3,
              fontFamily: AppStyles.fontFamily,
            ),
          ),
          if (compartment.isAssigned) ...[
            const SizedBox(height: 3),
            Text(
              '${compartment.pillsRemaining} left',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                fontFamily: AppStyles.fontFamily,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
