import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quiz_show/features/buzzers/buzzer_link.dart';
import 'package:quiz_show/game/game.dart';

/// The buzzer box's serial port through libserialport.
class LibSerialBuzzerPort implements BuzzerPort {
  SerialPort? _port;

  @override
  List<String> listPorts() => SerialPort.availablePorts;

  @override
  bool open(String name) {
    close();
    final port = SerialPort(name);
    if (!port.openReadWrite()) {
      port.dispose();
      return false;
    }
    final config = port.config
      ..baudRate = 9600
      ..bits = 8
      ..stopBits = 1
      ..parity = 0;
    port.config = config;
    // Whatever piled up before the app was listening is old news.
    port.flush();
    _port = port;
    return true;
  }

  @override
  Uint8List readAvailable() {
    final port = _port;
    if (port == null || !port.isOpen) throw StateError('port closed');
    final waiting = port.bytesAvailable;
    if (waiting < 0) throw StateError('port lost');
    if (waiting == 0) return Uint8List(0);
    // A negative timeout makes this return at once with what is there. Zero
    // or more would block the whole app until that many bytes had arrived.
    return port.read(waiting > 4096 ? 4096 : waiting, timeout: -1);
  }

  @override
  void close() {
    final port = _port;
    _port = null;
    if (port == null) return;
    try {
      port.close();
    } catch (_) {}
    try {
      port.dispose();
    } catch (_) {}
  }
}

/// Assigns a pressed buzzer to a team. Pure, so it can be tested.
///
/// A buzzer that was assigned by hand belongs to that team for as long as
/// the team exists. Any other buzzer falls back to position: buzzer 1 is the
/// first team, buzzer 2 the second, and so on, which is right for a box whose
/// buzzers are handed out in order.
String? teamForBuzzer(int buzzerId, List<Team> teams, Map<int, String> assigned) {
  final teamId = assigned[buzzerId];
  if (teamId != null && teams.any((team) => team.id == teamId)) return teamId;
  // A team with a buzzer of its own does not also answer to one by position.
  final taken = {for (final entry in assigned.entries) if (teams.any((t) => t.id == entry.value)) entry.value};
  final team = teams.elementAtOrNull(buzzerId);
  return team == null || taken.contains(team.id) ? null : team.id;
}

/// The buzzer box plugged into this device, with everything remembered about
/// it: the port, how hard a press has to be, and which buzzer is whose.
class Buzzers {
  Buzzers._();

  static final Buzzers instance = Buzzers._();

  static bool get supported => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  final BuzzerLink link = BuzzerLink(supported ? LibSerialBuzzerPort() : null);

  SharedPreferences? _prefs;
  bool _started = false;

  /// Whether this device is meant to have a buzzer box. Without one nothing
  /// is connected and the big screen does not warn about a missing box.
  /// Remembered on the device; on for anyone who had already chosen a port.
  final ValueNotifier<bool> wanted = ValueNotifier(false);

  Future<void> setWanted(bool on) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setBool('buzzers_wanted', on);
    wanted.value = on;
    if (on) {
      _connect(prefs);
    } else {
      link.use(null);
    }
  }

  /// Loads the settings and connects to the remembered port. If none was
  /// chosen and exactly one port exists, that one is used.
  Future<void> start() async {
    if (!supported || _started) return;
    _started = true;
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    wanted.value = prefs.getBool('buzzers_wanted') ?? prefs.containsKey('serial_port');
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('buzzer_threshold.')) continue;
      final id = int.tryParse(key.substring('buzzer_threshold.'.length));
      final value = prefs.getInt(key);
      if (id != null && value != null) link.detector.thresholds[id] = value;
    }
    if (wanted.value) _connect(prefs);
  }

  void _connect(SharedPreferences prefs) {
    var port = prefs.getString('serial_port');
    if (port == null) {
      final ports = link.availablePorts;
      if (ports.length == 1) port = ports.single;
    }
    link.use(port);
  }

  Future<void> selectPort(String? name) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    name == null ? await prefs.remove('serial_port') : await prefs.setString('serial_port', name);
    link.use(name);
  }

  Future<void> setThreshold(int id, int threshold) async {
    link.detector.thresholds[id] = threshold;
    await (_prefs ??= await SharedPreferences.getInstance()).setInt('buzzer_threshold.$id', threshold);
  }

  /// Buzzers assigned by hand in [sessionId], as buzzer id to team id.
  Map<int, String> assignments(String sessionId) {
    final prefs = _prefs;
    if (prefs == null) return const {};
    final prefix = 'buzzer_team.$sessionId.';
    final result = <int, String>{};
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      final id = int.tryParse(key.substring(prefix.length));
      final teamId = prefs.getString(key);
      if (id != null && teamId != null) result[id] = teamId;
    }
    return result;
  }

  /// Gives [buzzerId] to [teamId], taking it from whoever had it; null frees it.
  Future<void> assign(String sessionId, int buzzerId, String? teamId) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final key = 'buzzer_team.$sessionId.$buzzerId';
    teamId == null ? await prefs.remove(key) : await prefs.setString(key, teamId);
  }

  String? teamFor(String sessionId, int buzzerId, List<Team> teams) =>
      teamForBuzzer(buzzerId, teams, assignments(sessionId));
}
