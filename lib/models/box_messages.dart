/// The messages the medicine box sends and accepts over Bluetooth.
///
/// The protocol is firmware/healthsync_box/BLE_PROTOCOL.md (firmware 0.4.x):
/// one JSON object per write or notification, each with an "op". These types
/// only parse and build those objects; the Bluetooth link itself is
/// BoxLinkService.
library;

/// The box's answer to `{"op":"hello"}`.
class BoxHello {
  /// `HS-0001`, the same serial as the `devices` document id.
  final String serial;
  final String firmware;

  /// The box clock, UTC seconds. Meaningless while [clockOk] is false.
  final int utc;

  /// False after the DS3231 lost power: the box cannot alarm until the phone
  /// sets the time.
  final bool clockOk;

  /// The version the phone sent with the stored schedule, "" before any.
  final String scheduleVersion;
  final int scheduleCount;

  /// Events the box logged ([lastSeq]) and how many of them the phone has
  /// stored ([acked]).
  final int lastSeq;
  final int acked;
  final int pending;

  /// False when the box logs to flash because the microSD card is missing.
  final bool sdCard;

  const BoxHello({
    required this.serial,
    this.firmware = '',
    this.utc = 0,
    this.clockOk = false,
    this.scheduleVersion = '',
    this.scheduleCount = 0,
    this.lastSeq = 0,
    this.acked = 0,
    this.pending = 0,
    this.sdCard = false,
  });

  factory BoxHello.fromJson(Map<String, dynamic> json) {
    int number(String key) => (json[key] as num?)?.toInt() ?? 0;
    return BoxHello(
      serial: json['serial'] as String? ?? '',
      firmware: json['fw'] as String? ?? '',
      utc: number('utc'),
      clockOk: json['clock_ok'] as bool? ?? false,
      scheduleVersion: json['sched_ver'] as String? ?? '',
      scheduleCount: number('count'),
      lastSeq: number('last_seq'),
      acked: number('acked'),
      pending: number('pending'),
      sdCard: json['sd'] as bool? ?? false,
    );
  }
}

/// One dose time as the box stores it (`sched_item`).
class BoxScheduleItem {
  /// The `schedules` document id, at most 24 characters.
  final String scheduleId;

  /// 1–6.
  final int compartment;

  /// 24-hour `HH:MM`.
  final String time;

  /// 1 = Monday … 7 = Sunday, like `days_of_week`. Empty = every day.
  final List<int> days;

  const BoxScheduleItem({
    required this.scheduleId,
    required this.compartment,
    required this.time,
    required this.days,
  });

  Map<String, dynamic> toCommand() => {
        'op': 'sched_item',
        'sid': scheduleId,
        'comp': compartment,
        'time': time,
        'days': days,
      };

  @override
  bool operator ==(Object other) =>
      other is BoxScheduleItem &&
      other.scheduleId == scheduleId &&
      other.compartment == compartment &&
      other.time == time &&
      other.days.join(',') == days.join(',');

  @override
  int get hashCode => Object.hash(scheduleId, compartment, time, days.join(','));
}

/// A dose the box logged by itself: the button was pressed (`taken`), or
/// nobody pressed it within 60 minutes (`missed`).
class BoxEvent {
  final int seq;
  final String type;
  final int compartment;

  /// The dose's Manila date (`2026-10-24`) and time (`08:00`).
  final String date;
  final String time;

  /// When the button was pressed, or the dose was marked missed.
  final DateTime? at;

  /// `on_time` or `late` for a press; empty for missed.
  final String timing;

  /// The schedule id the phone sent. Empty for dose times added from the
  /// bench console, which no dose log can belong to.
  final String scheduleId;

  const BoxEvent({
    required this.seq,
    required this.type,
    this.compartment = 0,
    this.date = '',
    this.time = '',
    this.at,
    this.timing = '',
    this.scheduleId = '',
  });

  bool get isTaken => type == 'taken';
  bool get isMissed => type == 'missed';

  /// The dose log id, `{sid}_{date}_{time}`, the same one the Worker and the
  /// app give this dose (DoseLogModel.idFor). Null when the event cannot
  /// belong to a dose log.
  String? get doseLogId {
    if (scheduleId.isEmpty || date.isEmpty || time.isEmpty) return null;
    return '${scheduleId}_${date}_$time';
  }

  /// The dose's own date and time as a local instant, or null if either
  /// field is not in the expected form.
  DateTime? get scheduledAt {
    final d = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(date);
    final t = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(time);
    if (d == null || t == null) return null;
    return DateTime(
      int.parse(d.group(1)!),
      int.parse(d.group(2)!),
      int.parse(d.group(3)!),
      int.parse(t.group(1)!),
      int.parse(t.group(2)!),
    );
  }

  /// [json] is the `e` object of an `{"op":"event","e":{…}}` reply.
  factory BoxEvent.fromJson(Map<String, dynamic> json) {
    final rawAt = json['at'] as String?;
    return BoxEvent(
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? '',
      compartment: (json['comp'] as num?)?.toInt() ?? 0,
      date: json['date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      at: rawAt == null ? null : DateTime.tryParse(rawAt)?.toLocal(),
      timing: json['timing'] as String? ?? '',
      scheduleId: json['sid'] as String? ?? '',
    );
  }
}
