import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notifId;
  final String userRef;
  final String? doseLogRef;
  final String notificationType; // 'dose_reminder', 'missed_alert', 'low_stock', 'caregiver_link'
  final String title;
  final String message;
  final DateTime sentAt;
  final DateTime? readAt;
  final String channel; // 'fcm', 'in_app'
  final DateTime createdAt;
  final bool isActive;

  const NotificationModel({
    required this.notifId,
    required this.userRef,
    this.doseLogRef,
    required this.notificationType,
    required this.title,
    required this.message,
    required this.sentAt,
    this.readAt,
    this.channel = 'in_app',
    required this.createdAt,
    this.isActive = true,
  });

  bool get isRead => readAt != null;

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return NotificationModel.fromMap(data, doc.id);
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return NotificationModel(
      notifId: id ?? (map['notif_id'] as String? ?? ''),
      userRef: map['user_ref'] as String? ?? '',
      doseLogRef: map['dose_log_ref'] as String?,
      notificationType: map['notification_type'] as String? ?? 'dose_reminder',
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      sentAt: map['sent_at'] is Timestamp
          ? (map['sent_at'] as Timestamp).toDate()
          : (map['sent_at'] != null
              ? DateTime.tryParse(map['sent_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
      readAt: map['read_at'] is Timestamp
          ? (map['read_at'] as Timestamp).toDate()
          : (map['read_at'] != null
              ? DateTime.tryParse(map['read_at'].toString())
              : null),
      channel: map['channel'] as String? ?? 'in_app',
      createdAt: map['created_at'] is Timestamp
          ? (map['created_at'] as Timestamp).toDate()
          : (map['created_at'] != null
              ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notif_id': notifId,
      'user_ref': userRef,
      'dose_log_ref': doseLogRef,
      'notification_type': notificationType,
      'title': title,
      'message': message,
      'sent_at': Timestamp.fromDate(sentAt),
      'read_at': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'channel': channel,
      'created_at': Timestamp.fromDate(createdAt),
      'is_active': isActive,
    };
  }

  NotificationModel copyWith({
    String? notifId,
    String? userRef,
    String? doseLogRef,
    String? notificationType,
    String? title,
    String? message,
    DateTime? sentAt,
    DateTime? readAt,
    String? channel,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return NotificationModel(
      notifId: notifId ?? this.notifId,
      userRef: userRef ?? this.userRef,
      doseLogRef: doseLogRef ?? this.doseLogRef,
      notificationType: notificationType ?? this.notificationType,
      title: title ?? this.title,
      message: message ?? this.message,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
      channel: channel ?? this.channel,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
