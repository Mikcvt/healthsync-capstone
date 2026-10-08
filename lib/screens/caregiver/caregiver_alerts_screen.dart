import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_styles.dart';
import '../../models/notification_model.dart';
import '../../providers/caregiver_provider.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/shared/floating_nav_bar.dart';

/// The caregiver's alert feed.
///
/// Reads the `notifications` collection, which the Cloudflare Worker writes
/// for every caregiver alert: running late and missed doses from the cron
/// sweep; confirmations, skips, corrections and low stock from `/dose-events`.
/// The previous version listed five invented alerts, two of which reported
/// heart rates from a sensor this build does not have.
class CaregiverAlertsScreen extends StatelessWidget {
  const CaregiverAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final caregiver = context.watch<CaregiverProvider>();
    final alerts = caregiver.notifications;
    final unread = caregiver.unreadNotificationCount;
    final grouped = _groupByDay(alerts);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Alerts',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontFamily: AppStyles.fontFamily,
          ),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: caregiver.markAllNotificationsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: AppColors.caregiverGreen,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: alerts.isEmpty
            ? const _EmptyAlerts()
            : ListView(
                // Clears the floating nav bar, which otherwise hides the
                // oldest alert.
                padding: const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  FloatingNavBar.contentPadding,
                ),
                children: [
                  Text(
                    unread > 0 ? '$unread unread' : 'All caught up',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final entry in grouped.entries) ...[
                    _SectionHeader(label: entry.key),
                    const SizedBox(height: 10),
                    for (final alert in entry.value) ...[
                      _AlertCard(
                        alert: alert,
                        onTap: alert.isRead
                            ? null
                            : () => caregiver
                                .markNotificationRead(alert.notifId),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 8),
                  ],
                ],
              ),
      ),
    );
  }

  Map<String, List<NotificationModel>> _groupByDay(
    List<NotificationModel> alerts,
  ) {
    final grouped = <String, List<NotificationModel>>{};
    for (final alert in alerts) {
      grouped
          .putIfAbsent(DateFormatter.toRelativeDay(alert.sentAt), () => [])
          .add(alert);
    }
    return grouped;
  }
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 52, color: AppColors.textMuted),
            SizedBox(height: 14),
            Text(
              AppStrings.noAlerts,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                fontFamily: AppStyles.fontFamily,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Missed doses and low stock will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.5,
                fontFamily: AppStyles.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
        fontFamily: AppStyles.fontFamily,
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final NotificationModel alert;
  final VoidCallback? onTap;

  const _AlertCard({required this.alert, this.onTap});

  (IconData, Color, Color) get _appearance {
    switch (alert.notificationType) {
      case 'missed':
      case 'missed_alert':
        return (
          Icons.error_outline_rounded,
          AppColors.missedRed,
          AppColors.missedRedBg
        );
      case 'confirmed':
        return (
          Icons.check_circle_outline_rounded,
          AppColors.takenGreen,
          AppColors.takenGreenBg
        );
      case 'late':
        return (
          Icons.schedule_rounded,
          AppColors.pendingAmber,
          AppColors.pendingAmberBg
        );
      case 'skipped':
        return (
          Icons.do_not_disturb_on_outlined,
          AppColors.textSecondary,
          AppColors.background
        );
      case 'correction':
        return (
          Icons.edit_note_rounded,
          AppColors.upcomingBlue,
          AppColors.upcomingBlueBg
        );
      case 'low_stock':
        return (
          Icons.inventory_2_outlined,
          AppColors.pendingAmber,
          AppColors.pendingAmberBg
        );
      default:
        return (
          Icons.notifications_active_outlined,
          AppColors.upcomingBlue,
          AppColors.upcomingBlueBg
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, accent, background) = _appearance;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppStyles.cardDecoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: alert.isRead
                                ? FontWeight.w700
                                : FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontFamily: AppStyles.fontFamily,
                          ),
                        ),
                      ),
                      if (!alert.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.caregiverGreen,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textSecondary,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormatter.toRelativeTime(alert.sentAt),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
