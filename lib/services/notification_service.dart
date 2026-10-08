import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import 'dose_launch_router.dart';
import 'dose_reminder_scheduler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifs = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initialize() async {
    try {
      // 1. Request notification permissions
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('FCM Authorization status: ${settings.authorizationStatus}');

      // Android 13+ gates notifications behind a runtime grant, and 14+ gates
      // exact alarms separately. Without both, reminders are scheduled and
      // never fire — silently, which is the worst failure mode for this app.
      await DoseReminderScheduler().requestPermissions();

      // 2. Initialize local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _localNotifs.initialize(
        settings: initSettings,
        // A tapped dose reminder opens the alarm screen for that dose. The
        // payload is the schedule id (see DoseReminderScheduler).
        onDidReceiveNotificationResponse: (response) {
          DoseLaunchRouter.instance.open(response.payload);
        },
      );

      // Cold start: the app was closed and the patient opened it by tapping a
      // reminder. The tap above never fires in that case.
      final launch = await _localNotifs.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        DoseLaunchRouter.instance.open(launch!.notificationResponse?.payload);
      }

      // 3. Listen to foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          showLocalNotification(
            id: message.hashCode,
            title: message.notification?.title ?? 'HealthSync Reminder',
            body: message.notification?.body ?? '',
            payload: message.data['dose_log_id'],
          );
        }
      });
    } catch (e) {
      debugPrint('NotificationService initialization error: $e');
    }
  }

  // Save FCM Token to user document
  Future<void> saveTokenToUser(String uid) async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(uid).set({
          'fcm_token': token,
          'last_token_update': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  // Display immediate local notification
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'healthsync_dose_channel',
      'Medication Reminders',
      channelDescription: 'Notifications for scheduled medication doses and alerts',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const details = NotificationDetails(android: androidDetails);
    await _localNotifs.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  // Trigger 30-minute missed dose alert to caregiver
  Future<void> sendMissedDoseCaregiverAlert({
    required String caregiverUid,
    required String patientName,
    required String medicationName,
    required String doseLogId,
  }) async {
    final notif = NotificationModel(
      notifId: '',
      userRef: caregiverUid,
      doseLogRef: doseLogId,
      notificationType: 'missed_alert',
      title: 'Missed Dose Alert',
      message: '$patientName missed their scheduled dose of $medicationName.',
      sentAt: DateTime.now(),
      channel: 'fcm',
      createdAt: DateTime.now(),
    );

    final docRef = _firestore.collection('notifications').doc();
    await docRef.set(notif.copyWith(notifId: docRef.id).toMap());
  }

  /// Writes a low-stock notification for [userUid] and returns its id, so
  /// an undone dose can hide it again.
  Future<String> sendLowStockAlert({
    required String userUid,
    required String medicationName,
    required int remainingCount,
  }) async {
    final notif = NotificationModel(
      notifId: '',
      userRef: userUid,
      notificationType: 'low_stock',
      title: 'Low Medicine Stock',
      message: '$medicationName is running low ($remainingCount pills remaining).',
      sentAt: DateTime.now(),
      channel: 'in_app',
      createdAt: DateTime.now(),
    );

    final docRef = _firestore.collection('notifications').doc();
    await docRef.set(notif.copyWith(notifId: docRef.id).toMap());
    return docRef.id;
  }
}
