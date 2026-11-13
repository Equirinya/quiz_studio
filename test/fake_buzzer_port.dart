import 'dart:typed_data';

import 'package:quiz_show/features/buzzers/buzzer_link.dart';

/// A serial port driven by the test.
class FakePort implements BuzzerPort {
  bool plugged = true;
  bool isOpen = false;
  bool failReads = false;

  /// The port is there but the user may not open it, as on Linux outside
  /// the dialout group.
  bool denied = false;
  int opens = 0;
  final StringBuffer _incoming = StringBuffer();

  void send(String text) => _incoming.write(text);

  @override
  List<String> listPorts() => plugged ? ['COM3'] : [];

  @override
  bool open(String name) {
    opens++;
    if (denied) throw BuzzerPortDenied(name);
    isOpen = plugged;
    return plugged;
  }

  @override
  Uint8List readAvailable() {
    if (!isOpen || failReads) throw StateError('gone');
    final data = Uint8List.fromList(_incoming.toString().codeUnits);
    _incoming.clear();
    return data;
  }

  @override
  void close() => isOpen = false;
}
