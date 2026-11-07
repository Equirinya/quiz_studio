import 'dart:typed_data';

import 'package:quiz_show/features/buzzers/buzzer_link.dart';

/// A serial port driven by the test.
class FakePort implements BuzzerPort {
  bool plugged = true;
  bool isOpen = false;
  bool failReads = false;
  int opens = 0;
  final StringBuffer _incoming = StringBuffer();

  void send(String text) => _incoming.write(text);

  @override
  List<String> listPorts() => plugged ? ['COM3'] : [];

  @override
  bool open(String name) {
    opens++;
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
