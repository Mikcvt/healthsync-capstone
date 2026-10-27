import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' show BluetoothDevice;

import '../constants/app_strings.dart';
import '../models/box_messages.dart';
import '../models/device_model.dart';
import '../services/box_link_service.dart';
import '../services/device_service.dart';
import '../services/preferences_service.dart';
import '../utils/box_schedule.dart';
import 'patient_provider.dart';

/// What a pairing or a sync the patient asked for came to, for a SnackBar.
class BoxActionResult {
  final bool ok;
  final String message;

  const BoxActionResult(this.ok, this.message);
}

/// The patient's phone and their medicine box, over Bluetooth,
/// connect-on-demand (BLE_CONNECT_ON_DEMAND.md).
///
/// Decided Oct 27, 2026: only the patient's phone talks to the box (M1). It
/// connects when the app opens, after a Done or Skip in the app, and on the
/// Sync button (M2), then disconnects. Each sync:
///
///   hello → set_time → the schedule if it changed → the box's logged doses,
///   saved to Firestore, then acked → app_done for doses decided in the app
///
/// Box mode itself is still derived from the `devices` document
/// (PatientProvider.hasBox); this only adds the Bluetooth link of this phone.
class BoxProvider extends ChangeNotifier {
  final PatientProvider _patient;
  final BoxLinkService _link = BoxLinkService();
  final PreferencesService _prefs = PreferencesService();
  final DeviceService _devices = DeviceService();

  String? _uid;
  ({String remoteId, String serial})? _paired;
  bool _loaded = false;

  bool _busy = false;
  bool _again = false;
  bool _openSyncWanted = false;
  DateTime? _lastAttempt;
  DateTime? _lastSyncedAt;
  BoxLinkError? _lastError;
  String? _lastNote;

  StreamSubscription<String>? _finalizedSub;

  BoxProvider(this._patient) {
    _patient.addListener(_onPatientChanged);
    _finalizedSub = _patient.doseFinalized.listen(_onDoseFinalized);
    _onPatientChanged();
  }

  /// This phone is paired with a box over Bluetooth for this account.
  bool get isPairedHere => _paired != null;
  String? get pairedSerial => _paired?.serial;
  bool get isBusy => _busy;

  /// When this phone last completed a sync with the box, this session.
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Why the last sync failed, until one succeeds.
  BoxLinkError? get lastError => _lastError;

  /// A note from the last sync worth showing (dose times left out).
  String? get lastNote => _lastNote;

  /// The account's box and the one paired here differ: the care partner
  /// paired another box from their phone.
  bool get pairedBoxMismatch {
    final paired = _paired;
    final device = _patient.device;
    return paired != null &&
        device != null &&
        DeviceModel.normaliseSerial(device.serialNumber) != paired.serial;
  }

  String messageFor(BoxLinkError error) => switch (error) {
        BoxLinkError.unsupported => AppStrings.boxUnsupported,
        BoxLinkError.bluetoothOff => AppStrings.boxBluetoothOff,
        BoxLinkError.permissionDenied => AppStrings.boxPermissionDenied,
        BoxLinkError.notFound => AppStrings.boxNotFound,
        BoxLinkError.pairingFailed => AppStrings.boxPairingFailed,
        BoxLinkError.notPaired => AppStrings.boxNotPaired,
        BoxLinkError.connectionLost => AppStrings.boxConnectionLost,
        BoxLinkError.protocol => AppStrings.boxProtocolError,
      };

  // ── account changes ─────────────────────────────────────────────────────

  void _onPatientChanged() {
    final uid = _patient.patientUid;
    if (uid != _uid) {
      _uid = uid;
      _paired = null;
      _loaded = false;
      _lastSyncedAt = null;
      _lastError = null;
      _lastNote = null;
      if (uid != null) unawaited(_load(uid));
      return;
    }
    _maybeRunOpenSync();
  }

  Future<void> _load(String uid) async {
    final paired = await _prefs.pairedBox(uid);
    if (_uid != uid) return;
    _paired = paired;
    _loaded = true;
    notifyListeners();
    _maybeRunOpenSync();
  }

  // ── triggers (M2) ───────────────────────────────────────────────────────

  /// The app was opened or brought back. Syncs quietly once the account's
  /// data has loaded, at most once every two minutes. Never asks for
  /// anything: no Bluetooth prompt, no message.
  void syncOnOpen() {
    _openSyncWanted = true;
    _maybeRunOpenSync();
  }

  void _maybeRunOpenSync() {
    if (!_openSyncWanted || !_loaded || _paired == null) return;
    if (_patient.isLoading || _patient.device == null) return;
    _openSyncWanted = false;
    final last = _lastAttempt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 2)) {
      return;
    }
    unawaited(_sync(quiet: true));
  }

  /// A Done or Skip became final: the box may be beeping for that dose.
  void _onDoseFinalized(String scheduleId) {
    if (_paired == null) return;
    final schedule = _patient.scheduleById(scheduleId);
    if (schedule == null || !_patient.showsCompartment(schedule)) return;
    unawaited(_sync(quiet: true));
  }

  /// The Sync button.
  Future<BoxActionResult> syncNow() => _sync(quiet: false);

  // ── pairing (M7) ────────────────────────────────────────────────────────

  /// Boxes nearby, for the pairing screen.
  Stream<List<FoundBox>> scan() => _link.scan();

  /// Pairs [box] with this phone (Android asks for the 6-digit code on the
  /// label), saves it to the account under the serial the box reports, and
  /// runs the first sync in the same connection.
  Future<BoxActionResult> pair(FoundBox box) async {
    final uid = _uid;
    if (uid == null) return const BoxActionResult(false, AppStrings.genericError);
    if (_busy) return const BoxActionResult(false, AppStrings.boxConnectionLost);
    _busy = true;
    notifyListeners();

    BoxSession? session;
    try {
      session = await _link.open(box.device, allowNewPairing: true);
      final hello = await _hello(session);
      final serial = DeviceModel.normaliseSerial(hello.serial);
      if (!DeviceModel.serialPattern.hasMatch(serial)) {
        throw const BoxLinkException(BoxLinkError.protocol, 'bad serial');
      }

      final device = _patient.device;
      if (device == null ||
          DeviceModel.normaliseSerial(device.serialNumber) != serial) {
        // pairDevice reads and commits online; offline it would wait while
        // the box drops the idle connection, so give up after 15 seconds.
        final saved = await _patient
            .pairSmartBox(serial)
            .timeout(const Duration(seconds: 15), onTimeout: () => false);
        if (!saved) {
          return BoxActionResult(
            false,
            _patient.errorMessage == AppStrings.devicePairedElsewhere
                ? AppStrings.devicePairedElsewhere
                : AppStrings.boxPairNeedsInternet,
          );
        }
      }

      await _prefs.setPairedBox(uid, remoteId: box.remoteId, serial: serial);
      _paired = (remoteId: box.remoteId, serial: serial);
      _loaded = true;

      final saved = await _runSync(session, hello);
      return BoxActionResult(
        true,
        saved > 0
            ? '${AppStrings.devicePaired} ${AppStrings.boxSyncedWithPresses(saved)}'
            : AppStrings.devicePaired,
      );
    } on BoxLinkException catch (e) {
      debugPrint('Box pairing failed: $e');
      _lastError = e.error;
      return BoxActionResult(false, messageFor(e.error));
    } finally {
      await session?.close();
      _busy = false;
      notifyListeners();
      // A Done or Skip during pairing still needs its app_done.
      if (_again && _paired != null) {
        _again = false;
        unawaited(_sync(quiet: true));
      }
    }
  }

  /// Forgets the box on this phone: the stored pairing and Android's bond.
  /// The account keeps the box (that is the care partner's to change).
  Future<void> forgetOnThisPhone() async {
    final uid = _uid;
    final paired = _paired;
    if (uid == null || paired == null) return;
    await _link.forget(paired.remoteId);
    await _prefs.clearPairedBox(uid);
    _paired = null;
    _lastSyncedAt = null;
    _lastError = null;
    notifyListeners();
  }

  // ── a sync ──────────────────────────────────────────────────────────────

  Future<BoxActionResult> _sync({required bool quiet}) async {
    final paired = _paired;
    if (paired == null) {
      return const BoxActionResult(false, AppStrings.boxNotPaired);
    }
    if (pairedBoxMismatch) {
      return BoxActionResult(
        false,
        AppStrings.boxWrongSerial(
            paired.serial, _patient.device?.serialNumber ?? ''),
      );
    }
    if (_busy) {
      // A sync is running: one more after it picks up whatever changed.
      _again = true;
      return const BoxActionResult(true, AppStrings.boxSynced);
    }
    _busy = true;
    _lastAttempt = DateTime.now();
    notifyListeners();

    BoxSession? session;
    try {
      session = await _openPaired(paired, quiet: quiet);
      final hello = await _hello(session);
      if (DeviceModel.normaliseSerial(hello.serial) != paired.serial) {
        throw const BoxLinkException(BoxLinkError.notPaired, 'other box');
      }
      final saved = await _runSync(session, hello);
      return BoxActionResult(
        true,
        saved > 0 ? AppStrings.boxSyncedWithPresses(saved) : AppStrings.boxSynced,
      );
    } on BoxLinkException catch (e) {
      debugPrint('Box sync failed: $e');
      _lastError = e.error;
      return BoxActionResult(false, messageFor(e.error));
    } catch (e) {
      debugPrint('Box sync failed: $e');
      _lastError = BoxLinkError.connectionLost;
      return const BoxActionResult(false, AppStrings.boxConnectionLost);
    } finally {
      await session?.close();
      _busy = false;
      notifyListeners();
      if (_again) {
        _again = false;
        unawaited(_sync(quiet: true));
      }
    }
  }

  /// The remembered box: straight to its address first (no scan needed), or
  /// found by name if the address did not answer.
  Future<BoxSession> _openPaired(
    ({String remoteId, String serial}) paired, {
    required bool quiet,
  }) async {
    try {
      return await _link.open(
        BluetoothDevice.fromId(paired.remoteId),
        askToTurnOn: !quiet,
        connectTimeout: const Duration(seconds: 8),
      );
    } on BoxLinkException catch (e) {
      if (e.error != BoxLinkError.notFound) rethrow;
    }
    final found = await _link.find(paired.serial, askToTurnOn: !quiet);
    if (found == null) throw const BoxLinkException(BoxLinkError.notFound);
    final uid = _uid;
    if (found.remoteId != paired.remoteId && uid != null) {
      await _prefs.setPairedBox(uid,
          remoteId: found.remoteId, serial: paired.serial);
      _paired = (remoteId: found.remoteId, serial: paired.serial);
    }
    return _link.open(found.device, askToTurnOn: !quiet);
  }

  /// `hello`, retried: right after pairing or reconnecting, the link may
  /// still be encrypting, and the box ignores writes until it is.
  Future<BoxHello> _hello(BoxSession session) async {
    BoxLinkException? last;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final reply = await session.send({'op': 'hello'},
            timeout: const Duration(seconds: 4));
        return BoxHello.fromJson(reply);
      } on BoxLinkException catch (e) {
        last = e;
        if (e.error != BoxLinkError.connectionLost || !session.isOpen) break;
      }
    }
    throw last ?? const BoxLinkException(BoxLinkError.connectionLost);
  }

  /// Everything after hello. Returns how many button presses were saved.
  Future<int> _runSync(BoxSession session, BoxHello hello) async {
    final now = DateTime.now();

    // The phone's clock is the reference, every sync.
    await session.send({
      'op': 'set_time',
      'utc': now.toUtc().millisecondsSinceEpoch ~/ 1000,
    });

    // The schedule, only if it changed (M4: the phone wins).
    final plan = BoxSchedulePlan.build(_patient.schedules, today: now);
    if (hello.scheduleVersion != plan.version) {
      await session.send({
        'op': 'sched_begin',
        'ver': plan.version,
        'count': plan.items.length,
      });
      for (final item in plan.items) {
        await session.send(item.toCommand());
      }
      await session.send({'op': 'sched_commit'});
    }
    _lastNote = plan.leftOut > 0
        ? AppStrings.boxTooManyDoseTimes(plan.leftOut)
        : null;

    final saved = await _collectEvents(session, hello.acked);
    await _sendAppDone(session, now);

    _lastSyncedAt = DateTime.now();
    _lastError = null;
    _recordSync(plan);
    return saved;
  }

  /// The doses the box logged since the last ack, saved to Firestore and
  /// then acked, so the box can forget them. Stops at the first one that
  /// could not be saved; the next sync starts from there.
  Future<int> _collectEvents(BoxSession session, int acked) async {
    var saved = 0;
    for (var round = 0; round < 10; round++) {
      final batch = await session.events(after: acked);
      if (batch.events.isEmpty) break;

      var stored = acked;
      var failed = false;
      for (final event in batch.events) {
        if (event.seq <= stored) continue;
        if (!await _patient.recordBoxPress(event)) {
          failed = true;
          break;
        }
        stored = event.seq;
        if (event.isTaken && event.doseLogId != null) saved++;
      }
      if (stored > acked) {
        await session.send({'op': 'ack', 'seq': stored});
        acked = stored;
      }
      if (failed || acked >= batch.last) break;
    }
    return saved;
  }

  /// Doses already decided in the app whose box alarm could still sound,
  /// from an hour ago (the box alarms for 60 minutes) onward. The box stops
  /// or skips those alarms and logs nothing for them. A box that does not
  /// hold that dose time answers with an error, which is fine.
  Future<void> _sendAppDone(BoxSession session, DateTime now) async {
    final since = now.subtract(const Duration(minutes: 60));
    final slots = [
      ..._patient.slotsForDay(now.subtract(const Duration(days: 1))),
      ..._patient.slotsForDay(now),
    ];
    for (final slot in slots) {
      final log = slot.log;
      if (log == null || log.isCancelled || log.isOpen) continue;
      if (log.confirmedVia == 'button') continue;
      if (slot.schedule.matBoxColumn == null) continue;
      if (slot.scheduledAt.isBefore(since)) continue;
      String two(int v) => v.toString().padLeft(2, '0');
      final at = slot.scheduledAt;
      try {
        await session.send({
          'op': 'app_done',
          'sid': slot.schedule.scheduleId,
          'date': '${at.year}-${two(at.month)}-${two(at.day)}',
          'time': '${two(at.hour)}:${two(at.minute)}',
        });
      } on BoxLinkException catch (e) {
        if (e.error != BoxLinkError.protocol) rethrow;
      }
    }
  }

  /// Marks the box as just synced on its `devices` document, which is what
  /// the Box tab and the care partner's screens show. Not awaited: offline
  /// it waits on the phone and is sent later, and the sync is done anyway.
  void _recordSync(BoxSchedulePlan plan) {
    final serial = _paired?.serial;
    if (serial == null || _patient.device == null) return;
    final compartments = plan.items.map((i) => i.compartment).toSet().length;
    unawaited(_devices
        .recordHeartbeat(
          deviceId: _patient.device!.deviceId,
          activeColumnsCount: compartments,
        )
        .catchError((Object e) => debugPrint('Box sync not recorded: $e')));
  }

  @override
  void dispose() {
    _patient.removeListener(_onPatientChanged);
    _finalizedSub?.cancel();
    super.dispose();
  }
}
