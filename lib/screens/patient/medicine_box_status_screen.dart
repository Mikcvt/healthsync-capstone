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
import '../../widgets/shared/floating_nav_bar.dart';
import '../../widgets/shared/medicine_badge.dart';

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
                    Text(
                      compartments.every((c) => !c.isAssigned)
                          ? 'Your caregiver has not placed any medicine in the '
                              'box yet.'
                          : 'An amber light means that compartment is lit on '
                              'the box right now.',
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
                      crossAxisSpacing: 10,
                      // Tall enough for icon, column, a two-line name and the
                      // pill count on a 360dp-wide phone; 0.82 overflowed.
                      childAspectRatio: 0.66,
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
              '${compartment.pillsRemaining} left',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
