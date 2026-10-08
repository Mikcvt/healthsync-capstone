import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_styles.dart';
import '../../models/notification_model.dart';
import '../../providers/patient_provider.dart';
import '../../utils/date_formatter.dart';

/// Every alert this patient has received, newest first.
///
/// Reads the `notifications` collection, which the Cloudflare Worker writes
/// when it pushes to a device. This screen previously showed two invented rows,
/// which is why the collection had a writer but no reader.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<PatientProvider>();
    final notifications = patient.notifications;
    final hasUnread = patient.unreadNotificationCount > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontFamily: AppStyles.fontFamily,
          ),
        ),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: patient.markAllNotificationsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: AppColors.patientBlue,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppStyles.fontFamily,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: patient.isLoading && notifications.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : notifications.isEmpty
                ? const _EmptyNotifications()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    itemCount: notifications.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            hasUnread
                                ? '${patient.unreadNotificationCount} unread'
                                : 'All caught up',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              fontFamily: AppStyles.fontFamily,
                            ),
                          ),
                        );
                      }
                      final notification = notifications[index - 1];
                      return _NotificationTile(
                        notification: notification,
                        onTap: notification.isRead
                            ? null
                            : () => patient
                                .markNotificationRead(notification.notifId),
                      );
                    },
                  ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

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
              AppStrings.noNotifications,
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
              'Dose reminders and alerts will appear here.',
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

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;

  const _NotificationTile({required this.notification, this.onTap});

  /// Icon and colour are driven by `notification_type`, which is written by the
  /// Worker — so a missed-dose alert looks the same here as it does in the
  /// system tray.
  (IconData, Color, Color) get _appearance {
    switch (notification.notificationType) {
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
      case 'low_stock':
        return (
          Icons.inventory_2_outlined,
          AppColors.pendingAmber,
          AppColors.pendingAmberBg
        );
      case 'streak':
        return (
          Icons.local_fire_department_outlined,
          AppColors.streakPurple,
          AppColors.streakPurpleLight
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
                          notification.title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: notification.isRead
                                ? FontWeight.w700
                                : FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontFamily: AppStyles.fontFamily,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.patientBlue,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textSecondary,
                      fontFamily: AppStyles.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormatter.toRelativeTime(notification.sentAt),
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
