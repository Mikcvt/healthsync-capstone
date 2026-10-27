import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/box_messages.dart';

/// Why talking to the box failed, in terms a screen can explain.
enum BoxLinkError {
  /// This phone has no Bluetooth Low Energy.
  unsupported,

  /// Bluetooth is off and the patient did not turn it on.
  bluetoothOff,

  /// A Bluetooth (or, on Android 11 and older, location) permission was
  /// refused.
  permissionDenied,

  /// No box answered: out of range, switched off, or busy with another phone.
  notFound,

  /// Pairing did not finish: wrong code, pairing mode not open, or too slow
  /// (the box drops a phone that has not paired within 30 seconds).
  pairingFailed,

  /// This phone is not paired with the box any more (the phone or the box
  /// forgot it). Fixed by pairing again.
  notPaired,

  /// The connection dropped, or the box stopped answering.
  connectionLost,

  /// The box answered with something the app does not understand, or with
  /// an error.
  protocol,
}

class BoxLinkException implements Exception {
  final BoxLinkError error;
  final String detail;

  const BoxLinkException(this.error, [this.detail = '']);

  @override
  String toString() => 'BoxLinkException($error${detail.isEmpty ? '' : ': $detail'})';
}

/// A box seen in a scan.
class FoundBox {
  final BluetoothDevice device;

  /// From the advertised name (`HealthSync-0001` → `HS-0001`), or null if the
  /// name has not arrived yet. The box itself confirms it in `hello`.
  final String? serial;
  final int rssi;

  const FoundBox({required this.device, this.serial, this.rssi = 0});

  String get remoteId => device.remoteId.str;
}

/// The Bluetooth link to the HealthSync box, connect-on-demand
/// (BLE_CONNECT_ON_DEMAND.md; protocol firmware/healthsync_box/BLE_PROTOCOL.md).
///
/// The box is the peripheral: one service, a "command" characteristic the
/// phone writes one JSON message to, and a "reply" characteristic it notifies
/// one JSON message on. Both need an encrypted link with a paired (bonded)
/// phone. Pairing uses the 6-digit code on the box label, typed into Android's
/// own dialog; the app never sees or stores the code.
///
/// Everything here is transport. What a sync does is BoxProvider.
class BoxLinkService {
  static final Guid serviceUuid = Guid('908a611a-cdae-4717-843a-8929f91d551b');
  static final Guid commandUuid = Guid('a8672cae-3524-49a5-9a57-696fd57e7b72');
  static final Guid replyUuid = Guid('c7b37ff8-2e2b-4156-8130-34df10d433e5');

  /// Every reply fits one notification at this packet size; at the default
  /// 23 the box cannot answer at all.
  static const int mtu = 247;

  static final _namePattern = RegExp(r'^HealthSync-(\d{4})$');

  /// `HealthSync-0001` → `HS-0001`.
  static String? serialFromName(String name) {
    final match = _namePattern.firstMatch(name.trim());
    return match == null ? null : 'HS-${match.group(1)}';
  }

  /// Bluetooth is supported and on. Off: asks Android to turn it on (a
  /// system dialog) and waits for it, or with [askToTurnOn] false (a sync
  /// nobody asked for) fails quietly instead.
  Future<void> ensureReady({bool askToTurnOn = true}) async {
    if (!await FlutterBluePlus.isSupported) {
      throw const BoxLinkException(BoxLinkError.unsupported);
    }
    var state = FlutterBluePlus.adapterStateNow;
    if (state == BluetoothAdapterState.unknown) {
      state = await FlutterBluePlus.adapterState
          .where((s) => s != BluetoothAdapterState.unknown)
          .first
          .timeout(const Duration(seconds: 3),
              onTimeout: () => BluetoothAdapterState.unknown);
    }
    if (state == BluetoothAdapterState.on) return;
    if (!askToTurnOn) throw const BoxLinkException(BoxLinkError.bluetoothOff);
    try {
      await FlutterBluePlus.turnOn(timeout: 30);
    } catch (e) {
      throw _classify(e, fallback: BoxLinkError.bluetoothOff);
    }
  }

  /// Boxes nearby, updated as they are found, for [timeout]. Asks for the
  /// scan permission the first time (Android shows its own dialog).
  Stream<List<FoundBox>> scan({
    Duration timeout = const Duration(seconds: 12),
    bool askToTurnOn = true,
  }) {
    final controller = StreamController<List<FoundBox>>();
    StreamSubscription<List<ScanResult>>? results;
    StreamSubscription<bool>? scanning;

    Future<void> start() async {
      try {
        await ensureReady(askToTurnOn: askToTurnOn);
        results = FlutterBluePlus.onScanResults.listen((list) {
          controller.add([
            for (final r in list)
              FoundBox(
                device: r.device,
                serial: serialFromName(r.advertisementData.advName.isNotEmpty
                    ? r.advertisementData.advName
                    : r.device.advName),
                rssi: r.rssi,
              ),
          ]..sort((a, b) => b.rssi.compareTo(a.rssi)));
        });
        await FlutterBluePlus.startScan(
          withServices: [serviceUuid],
          timeout: timeout,
        );
        // startScan returns once the scan is under way; the stream ends
        // when it stops.
        scanning = FlutterBluePlus.isScanning.listen((on) {
          if (!on && !controller.isClosed) controller.close();
        });
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(_classify(e, fallback: BoxLinkError.notFound));
          await controller.close();
        }
      }
    }

    controller.onListen = start;
    controller.onCancel = () async {
      await results?.cancel();
      await scanning?.cancel();
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    };
    return controller.stream;
  }

  /// Looks for the box [serial] nearby, for when a direct connection to the
  /// remembered address fails. Null if it was not seen.
  Future<FoundBox?> find(
    String serial, {
    Duration timeout = const Duration(seconds: 8),
    bool askToTurnOn = true,
  }) async {
    await for (final list
        in scan(timeout: timeout, askToTurnOn: askToTurnOn)) {
      final found = list.where((b) => b.serial == serial).firstOrNull;
      if (found != null) return found;
    }
    return null;
  }

  /// Connects to [device], makes sure the link is paired and encrypted, and
  /// returns a session ready for commands.
  ///
  /// [allowNewPairing]: true only on the pairing screen, where Android's
  /// pairing dialog is expected. A sync of an already paired box never
  /// starts a pairing: an unpaired phone there means the pairing was lost,
  /// and the box (outside pairing mode) would refuse it anyway.
  Future<BoxSession> open(
    BluetoothDevice device, {
    bool allowNewPairing = false,
    bool askToTurnOn = true,
    Duration connectTimeout = const Duration(seconds: 12),
  }) async {
    await ensureReady(askToTurnOn: askToTurnOn);
    try {
      await device.connect(timeout: connectTimeout, mtu: mtu);
    } catch (e) {
      try {
        await device.disconnect();
      } catch (_) {}
      throw _classify(e, fallback: BoxLinkError.notFound);
    }

    try {
      await _ensureBonded(device, allowNewPairing: allowNewPairing);
      final session = await BoxSession._attach(device);
      return session;
    } catch (e) {
      try {
        await device.disconnect();
      } catch (_) {}
      if (e is BoxLinkException) rethrow;
      throw _classify(e, fallback: BoxLinkError.connectionLost);
    }
  }

  Future<void> _ensureBonded(
    BluetoothDevice device, {
    required bool allowNewPairing,
  }) async {
    final current = await device.bondState.first;
    if (current == BluetoothBondState.bonded) return;
    if (!allowNewPairing) {
      throw const BoxLinkException(BoxLinkError.notPaired);
    }

    // The box asks for encryption the moment a phone connects, so Android
    // may already be showing its pairing dialog. createBond covers a phone
    // that waits to be asked; either way the outcome arrives on bondState.
    final result = Completer<bool>();
    var sawBonding = current == BluetoothBondState.bonding;
    final bondSub = device.bondState.listen((state) {
      if (result.isCompleted) return;
      if (state == BluetoothBondState.bonding) {
        sawBonding = true;
      } else if (state == BluetoothBondState.bonded) {
        result.complete(true);
      } else if (sawBonding) {
        result.complete(false);   // bonding → none: wrong code or refused
      }
    });
    // The box drops a phone that has not paired within 30 seconds.
    final linkSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected &&
          !result.isCompleted) {
        result.complete(false);
      }
    });
    try {
      unawaited(device.createBond(timeout: 60).catchError((Object e) {
        debugPrint('createBond: $e');
      }));
      final ok = await result.future
          .timeout(const Duration(seconds: 60), onTimeout: () => false);
      if (!ok) throw const BoxLinkException(BoxLinkError.pairingFailed);
    } finally {
      await bondSub.cancel();
      await linkSub.cancel();
    }
  }

  /// Forgets the pairing on this phone (Android). The box keeps its side
  /// until it is reset or pairs three newer phones.
  Future<void> forget(String remoteId) async {
    try {
      await BluetoothDevice.fromId(remoteId).removeBond();
    } catch (e) {
      debugPrint('removeBond: $e');
    }
  }

  static BoxLinkException _classify(Object e, {required BoxLinkError fallback}) {
    if (e is BoxLinkException) return e;
    final text = (e is PlatformException
            ? '${e.code} ${e.message}'
            : e is FlutterBluePlusException
                ? '${e.function} ${e.description}'
                : e.toString())
        .toLowerCase();
    if (text.contains('permission')) {
      return BoxLinkException(BoxLinkError.permissionDenied, text);
    }
    if (text.contains('turned on') ||
        text.contains('adapter is off') ||
        text.contains('user rejected') ||
        text.contains('turnon')) {
      return BoxLinkException(BoxLinkError.bluetoothOff, text);
    }
    return BoxLinkException(fallback, text);
  }
}

/// One open connection to the box. Commands go one at a time: the box
/// answers each with exactly one reply (`events` with several).
class BoxSession {
  final BluetoothDevice device;
  final BluetoothCharacteristic _command;
  final StreamSubscription<List<int>> _notifications;
  final StreamSubscription<BluetoothConnectionState> _linkWatch;
  final _replies = StreamController<Map<String, dynamic>>.broadcast();
  bool _closed = false;

  /// One command at a time, even when callers overlap.
  Future<void> _queue = Future.value();

  BoxSession._(
    this.device,
    this._command,
    this._notifications,
    this._linkWatch,
  );

  static Future<BoxSession> _attach(BluetoothDevice device) async {
    final services = await device.discoverServices();
    final service =
        services.where((s) => s.uuid == BoxLinkService.serviceUuid).firstOrNull;
    if (service == null) {
      throw const BoxLinkException(
          BoxLinkError.protocol, 'not a HealthSync box (service missing)');
    }
    BluetoothCharacteristic? find(Guid id) =>
        service.characteristics.where((c) => c.uuid == id).firstOrNull;
    final command = find(BoxLinkService.commandUuid);
    final reply = find(BoxLinkService.replyUuid);
    if (command == null || reply == null) {
      throw const BoxLinkException(
          BoxLinkError.protocol, 'characteristics missing');
    }

    late final BoxSession session;
    final notifications = reply.onValueReceived.listen((bytes) {
      session._onNotification(bytes);
    });
    final linkWatch = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        session._onDisconnected();
      }
    });
    session = BoxSession._(device, command, notifications, linkWatch);
    try {
      await reply.setNotifyValue(true);
    } catch (_) {
      await session.close();
      rethrow;
    }
    return session;
  }

  bool get isOpen => !_closed && device.isConnected;

  void _onNotification(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, dynamic>) _replies.add(decoded);
    } catch (e) {
      debugPrint('Box sent something that is not JSON: $e');
    }
  }

  void _onDisconnected() {
    if (_replies.isClosed) return;
    _replies.addError(const BoxLinkException(BoxLinkError.connectionLost));
  }

  /// Sends [command] and returns the box's reply. An `{"op":"error"}` reply
  /// throws [BoxLinkError.protocol] with the box's message.
  Future<Map<String, dynamic>> send(
    Map<String, dynamic> command, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    return _serial(() async {
      // Listening before the write, so a fast reply is not missed. ignore():
      // a reply that fails while the write is still going is not "uncaught";
      // awaiting it below still sees the error.
      final reply = _replies.stream.first.timeout(timeout)..ignore();
      await _write(command);
      final Map<String, dynamic> answer;
      try {
        answer = await reply;
      } on BoxLinkException {
        rethrow;
      } catch (_) {
        // Timed out, or the stream closed with the connection.
        throw BoxLinkException(
            BoxLinkError.connectionLost, 'no reply to ${command['op']}');
      }
      if (answer['op'] == 'error') {
        throw BoxLinkException(
            BoxLinkError.protocol, answer['msg'] as String? ?? 'error');
      }
      return answer;
    });
  }

  /// `events`: every `event` reply until `events_end`.
  Future<({List<BoxEvent> events, int sent, int last})> events({
    int? after,
    int max = 20,
  }) {
    return _serial(() async {
      final events = <BoxEvent>[];
      final done = Completer<Map<String, dynamic>>();
      final sub = _replies.stream.listen((reply) {
        if (done.isCompleted) return;
        switch (reply['op']) {
          case 'event':
            final e = reply['e'];
            if (e is Map<String, dynamic>) events.add(BoxEvent.fromJson(e));
          case 'events_end':
            done.complete(reply);
          case 'error':
            done.completeError(BoxLinkException(
                BoxLinkError.protocol, reply['msg'] as String? ?? 'error'));
        }
      }, onError: (Object e) {
        if (!done.isCompleted) done.completeError(e);
      });
      try {
        await _write({
          'op': 'events',
          'after': ?after,
          'max': max,
        });
        // About 15 ms per event on the box; generous for a slow link.
        final end = await done.future.timeout(const Duration(seconds: 10),
            onTimeout: () => throw const BoxLinkException(
                BoxLinkError.connectionLost, 'events did not finish'));
        return (
          events: events,
          sent: (end['sent'] as num?)?.toInt() ?? events.length,
          last: (end['last'] as num?)?.toInt() ?? 0,
        );
      } finally {
        await sub.cancel();
      }
    });
  }

  Future<T> _serial<T>(Future<T> Function() task) {
    final run = _queue.then((_) {
      if (!isOpen) {
        throw const BoxLinkException(BoxLinkError.connectionLost);
      }
      return task();
    });
    _queue = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  Future<void> _write(Map<String, dynamic> command) async {
    final bytes = utf8.encode(jsonEncode(command));
    try {
      await _command.write(bytes, timeout: 5);
    } catch (e) {
      // A write the box refuses for want of encryption means this phone's
      // pairing is not accepted any more.
      final text = e.toString().toLowerCase();
      if (text.contains('auth') || text.contains('encrypt')) {
        throw BoxLinkException(BoxLinkError.notPaired, text);
      }
      throw BoxLinkException(BoxLinkError.connectionLost, text);
    }
  }

  /// Disconnects. Safe to call twice.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _notifications.cancel();
    await _linkWatch.cancel();
    await _replies.close();
    try {
      await device.disconnect();
    } catch (e) {
      debugPrint('Box disconnect: $e');
    }
  }
}
