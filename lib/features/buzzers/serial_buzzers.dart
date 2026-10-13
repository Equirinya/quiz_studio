import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quiz_show/features/buzzers/serial_protocol.dart';

enum SerialStatus { unsupported, notConfigured, disconnected, connected }

/// The buzzer box on a USB serial port of the presenting device. Port,
/// thresholds and the buzzer-to-team mapping are remembered per device,
/// because they describe hardware plugged into it.
class SerialBuzzers {
  SerialBuzzers._();

  static final SerialBuzzers instance = SerialBuzzers._();

  static bool get supported => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  final ValueNotifier<SerialStatus> status =
      ValueNotifier(supported ? SerialStatus.notConfigured : SerialStatus.unsupported);

  /// The latest reading of every buzzer seen so far.
  final ValueNotifier<Map<int, int>> values = ValueNotifier(const {});

  final StreamController<int> _pressed = StreamController<int>.broadcast();
  final BuzzerEdgeDetector _detector = BuzzerEdgeDetector();
  final SerialLineBuffer _lines = SerialLineBuffer();

  SharedPreferences? _prefs;
  SerialPort? _port;
  Timer? _poll;

  /// Ids of buzzers as they are pressed.
  Stream<int> get pressed => _pressed.stream;

  List<String> get availablePorts {
    if (!supported) return const [];
    try {
      return SerialPort.availablePorts;
    } catch (error) {
      if (kDebugMode) print('Serial: could not list ports: $error');
      return const [];
    }
  }

  String? get portName => _prefs?.getString('serial_port');

  int thresholdOf(int id) => _detector.thresholdOf(id);

  /// Position of the team this buzzer belongs to; by default buzzer n is
  /// team n.
  int teamIndexOf(int id) => _prefs?.getInt('buzzer_team.$id') ?? id;

  Future<void> setThreshold(int id, int threshold) async {
    _detector.thresholds[id] = threshold;
    await _prefs?.setInt('buzzer_threshold.$id', threshold);
  }

  Future<void> setTeamIndex(int id, int teamIndex) async => _prefs?.setInt('buzzer_team.$id', teamIndex);

  /// Loads the settings and connects to the remembered port, if any.
  Future<void> start() async {
    if (!supported) return;
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('buzzer_threshold.')) continue;
      final id = int.tryParse(key.substring('buzzer_threshold.'.length));
      final value = prefs.getInt(key);
      if (id != null && value != null) _detector.thresholds[id] = value;
    }
    connect();
  }

  Future<void> selectPort(String? name) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    name == null ? await prefs.remove('serial_port') : await prefs.setString('serial_port', name);
    connect();
  }

  /// (Re)opens the remembered port.
  void connect() {
    _close();
    final name = portName;
    if (name == null) {
      status.value = SerialStatus.notConfigured;
      return;
    }
    try {
      final port = SerialPort(name);
      if (!port.openReadWrite()) {
        status.value = SerialStatus.disconnected;
        return;
      }
      final config = port.config
        ..baudRate = 9600
        ..bits = 8
        ..stopBits = 1
        ..parity = 0;
      port.config = config;
      _port = port;
      status.value = SerialStatus.connected;
      _poll = Timer.periodic(const Duration(milliseconds: 10), (_) => _read());
    } catch (error) {
      if (kDebugMode) print('Serial: could not open $name: $error');
      status.value = SerialStatus.disconnected;
    }
  }

  void _read() {
    final port = _port;
    if (port == null) return;
    try {
      if (!port.isOpen) throw StateError('port closed');
      final data = port.read(256, timeout: 0);
      if (data.isEmpty) return;
      for (final line in _lines.add(String.fromCharCodes(data))) {
        final reading = parseBuzzerLine(line);
        if (reading == null) continue;
        values.value = {...values.value, ...reading};
        _detector.update(reading).forEach(_pressed.add);
      }
    } catch (error) {
      // Unplugged mid-show: say so instead of polling a dead port.
      if (kDebugMode) print('Serial: read failed: $error');
      _close();
      status.value = SerialStatus.disconnected;
    }
  }

  void _close() {
    _poll?.cancel();
    _poll = null;
    try {
      _port?.close();
    } catch (_) {}
    _port = null;
  }

  void stop() {
    _close();
    if (supported) status.value = portName == null ? SerialStatus.notConfigured : SerialStatus.disconnected;
  }
}
