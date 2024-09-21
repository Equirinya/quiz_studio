import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SerialStatus { notConfigured, disconnected, connected }

class SerialConnection {
  static final SerialConnection _singleton = SerialConnection._internal();

  factory SerialConnection() {
    return _singleton;
  }

  SharedPreferences? _prefs;

  //three streams: raw serial(String), allActive Buzzers(List<int>), buzzerPressed(int)
  SerialStatus status = SerialStatus.notConfigured;
  List<int> buzzerSensitivity = List.filled(100, 512);
  List<int> _previouslyBuzzered = List.empty(growable: true);

  late Stream<String> serialStream;
  late Stream<List<int>> activeBuzzerStream;
  late Stream<int> buzzerPressed;

  String _partialSerial = "";
  SerialPort? _port;

  SerialConnection._internal() {
    () async {
      _prefs = await SharedPreferences.getInstance();
      createSerialStream();
    }();
  }

  void createSerialStream() {
    _port?.close();
    status = SerialStatus.disconnected;
    String? portString = _prefs?.getString("serial_port");
    if (portString == null || !Platform.isWindows) {
      status = SerialStatus.notConfigured;
      print("Port String is null");
      return;
    }
    _port = SerialPort(portString);
    _port?.close();
    _port?.openReadWrite();
    if(_port == null || !_port!.isOpen) {
      return;
    }
    var config = _port?.config;
    if(config == null) {
      print("Port config is null");
      return;
    }
    config.baudRate = 9600;
    _port!.config = config;

    _port!.config.bits = 8;
    _port!.config.stopBits = 1;
    _port!.config.parity = 0;

    _port!.config = config;
    Stream<String> originalStream = Stream.periodic(
      const Duration(milliseconds: 5),
      (computationCount) {
        if (_port == null || !_port!.isOpen) return null;
        Uint8List data = _port!.read(100);
        String text = String.fromCharCodes(data);
        if (text.contains("\n")) {
          String fullLine = _partialSerial + text.split("\n").first;
          _partialSerial = text.split("\n").sublist(1).join("\n");
          return fullLine;
        } else {
          _partialSerial += text;
          return null;
        }
      },
    ).transform(StreamTransformer.fromHandlers(handleData: (data, sink) {
      if (data != null && data.isNotEmpty) sink.add(data);
    }));
    serialStream = originalStream.asBroadcastStream();

    activeBuzzerStream = serialStream
        .map((event) => event
            .split(",")
            .map((e) => e.split(":").map((e) => int.tryParse(e) ?? 0))
            .indexed
            .where((e) => e.$2.last > buzzerSensitivity[e.$1])
            .map((e) => e.$2.first)
            .toList())
        .asBroadcastStream();
    buzzerPressed = activeBuzzerStream.transform<int>(StreamTransformer.fromHandlers(handleData: (data, sink) {
      data.where((element) => !_previouslyBuzzered.contains(element)).forEach((element) {
        sink.add(element);
      });
      _previouslyBuzzered = data;
    })).asBroadcastStream();
    status = SerialStatus.connected;
  }

//TODO include methods to send color data to different buzzers
}
