import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:quiz_show/features/buzzers/serial_protocol.dart';

/// The serial port as the buzzer link needs it. The real one wraps
/// libserialport; tests use a scripted one.
abstract class BuzzerPort {
  List<String> listPorts();

  /// Opens [name] at 9600 8N1. Returns false, or throws, when it cannot.
  bool open(String name);

  /// Everything received since the last call, without waiting. Throws when
  /// the port is gone.
  Uint8List readAvailable();

  void close();
}

enum BuzzerStatus {
  /// This device has no serial ports to offer.
  unsupported,

  /// No port chosen yet.
  notConfigured,

  /// The port cannot be opened; retrying.
  disconnected,

  /// The port is open but nothing has arrived for a while; retrying.
  silent,

  /// Readings are coming in.
  connected,
}

/// Keeps the buzzer box talking for the length of a show.
///
/// What makes it hold up over hours:
///   * Every poll takes everything the port has and handles every complete
///     line in it. Nothing is left for "next time", so a box that sends
///     faster than the poll runs cannot build up a backlog that turns into
///     seconds of delay later.
///   * Reads never wait. A quiet box cannot freeze the app.
///   * A port that fails or goes quiet is closed and reopened on a steady
///     retry, for as long as it takes; unplugging and replugging the box
///     needs no action in the app.
///   * Listeners are attached once. Nothing subscribes and unsubscribes with
///     the state of the game.
class BuzzerLink {
  BuzzerLink(
    this._port, {
    int Function()? clock,
    this.pollInterval = const Duration(milliseconds: 10),
    this.silenceAfter = const Duration(seconds: 3),
    this.retryEvery = const Duration(seconds: 2),
    this.publishEvery = const Duration(milliseconds: 60),
  }) : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final BuzzerPort? _port;
  final int Function() _clock;
  final Duration pollInterval;

  /// How long an open port may stay quiet before it is treated as dead.
  final Duration silenceAfter;
  final Duration retryEvery;

  /// How often [values] is refreshed for the screen. Presses are not held
  /// back by this; they are reported the moment their line is read.
  final Duration publishEvery;

  late final ValueNotifier<BuzzerStatus> status =
      ValueNotifier(_port == null ? BuzzerStatus.unsupported : BuzzerStatus.notConfigured);

  /// The latest reading of every buzzer seen so far.
  final ValueNotifier<Map<int, int>> values = ValueNotifier(const {});

  final BuzzerEdgeDetector detector = BuzzerEdgeDetector();
  final SerialLineBuffer _lines = SerialLineBuffer();
  final StreamController<int> _pressed = StreamController<int>.broadcast(sync: true);
  final StreamController<Map<int, int>> _readings = StreamController<Map<int, int>>.broadcast(sync: true);

  String? _portName;
  bool _open = false;
  Timer? _poll;
  final Map<int, int> _latest = {};
  bool _dirty = false;
  int _lastPublish = 0;
  int _lastData = 0;
  int _lastAttempt = 0;
  int _openedAt = 0;

  // Diagnostics, shown on the buzzer page.
  int linesTotal = 0;

  /// The last lines the box sent, exactly as they came, newest last.
  final List<String> recentLines = [];
  static const int _keptLines = 40;
  int reconnects = 0;
  int _windowStart = 0;
  int _windowLines = 0;

  /// Readings per second over the last second or so.
  final ValueNotifier<int> rate = ValueNotifier(0);

  /// Ids of buzzers, the moment they are pressed.
  Stream<int> get pressed => _pressed.stream;

  /// Every reading as it comes in; for calibration.
  Stream<Map<int, int>> get readings => _readings.stream;

  String? get portName => _portName;

  List<String> get availablePorts {
    try {
      return _port?.listPorts() ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// Milliseconds since the last reading, or null when there never was one.
  int? get millisSinceData => _lastData == 0 ? null : _clock() - _lastData;

  /// Milliseconds the current connection has been up.
  int get uptimeMillis => _open ? _clock() - _openedAt : 0;

  /// Chooses the port and starts (or stops, with null) the link.
  void use(String? name) {
    _close();
    _portName = name;
    if (_port == null) return;
    if (name == null) {
      _poll?.cancel();
      _poll = null;
      status.value = BuzzerStatus.notConfigured;
      return;
    }
    _tryOpen();
    _poll ??= Timer.periodic(pollInterval, (_) => _tick());
  }

  /// Closes and reopens the port right away.
  void reconnect() {
    if (_portName == null) return;
    _close();
    _tryOpen();
  }

  void _tryOpen() {
    _lastAttempt = _clock();
    var opened = false;
    try {
      opened = _port!.open(_portName!);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      status.value = BuzzerStatus.disconnected;
      return;
    }
    _open = true;
    _openedAt = _lastAttempt;
    _windowStart = _lastAttempt;
    _windowLines = 0;
    // Counted from now, so a slow box gets the full grace period.
    _lastData = _lastAttempt;
    status.value = BuzzerStatus.silent;
  }

  void _close() {
    if (_open) {
      try {
        _port?.close();
      } catch (_) {}
    }
    _open = false;
    // A buzzer held while the box dropped out must not stay "held".
    detector.reset();
  }

  /// Characters received but not yet part of a complete line. Stays small
  /// however long the link runs; shown as a health figure.
  int get pendingChars => _lines.pending;

  /// One round of reading and housekeeping. The link calls this itself on
  /// its timer; tests call it directly to run hours of show in a moment.
  @visibleForTesting
  void poll() => _tick();

  void _tick() {
    if (_portName == null) return;
    final now = _clock();
    if (!_open) {
      if (now - _lastAttempt >= retryEvery.inMilliseconds) {
        reconnects++;
        _tryOpen();
      }
      return;
    }
    Uint8List data;
    try {
      data = _port!.readAvailable();
    } catch (_) {
      // Unplugged, or the driver gave up: start over.
      _close();
      status.value = BuzzerStatus.disconnected;
      _lastAttempt = now;
      return;
    }
    if (data.isNotEmpty) {
      for (final line in _lines.add(String.fromCharCodes(data))) {
        recentLines.add(line);
        if (recentLines.length > _keptLines) recentLines.removeAt(0);
        final reading = parseBuzzerLine(line);
        if (reading == null) continue;
        linesTotal++;
        _windowLines++;
        _lastData = now;
        _latest.addAll(reading);
        _dirty = true;
        _readings.add(reading);
        for (final id in detector.update(reading)) {
          _pressed.add(id);
        }
      }
      if (_lastData == now && status.value != BuzzerStatus.connected) status.value = BuzzerStatus.connected;
    }
    if (now - _lastData >= silenceAfter.inMilliseconds) {
      // Open but mute: often a port that died without an error. Reopen it.
      status.value = BuzzerStatus.silent;
      if (now - _lastAttempt >= retryEvery.inMilliseconds) {
        reconnects++;
        _close();
        _tryOpen();
        if (_open) status.value = BuzzerStatus.silent;
      }
    }
    if (_dirty && now - _lastPublish >= publishEvery.inMilliseconds) {
      _dirty = false;
      _lastPublish = now;
      values.value = Map.of(_latest);
    }
    if (now - _windowStart >= 1000) {
      rate.value = (_windowLines * 1000 / (now - _windowStart)).round();
      _windowStart = now;
      _windowLines = 0;
    }
  }

  void dispose() {
    _poll?.cancel();
    _close();
    _pressed.close();
    _readings.close();
    status.dispose();
    values.dispose();
    rate.dispose();
  }
}
