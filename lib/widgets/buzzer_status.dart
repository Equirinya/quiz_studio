import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quiz_show/serial_connection.dart';

class BuzzerStatusIndicator extends StatefulWidget {
  const BuzzerStatusIndicator({super.key});

  @override
  State<BuzzerStatusIndicator> createState() => _BuzzerStatusIndicatorState();
}

class _BuzzerStatusIndicatorState extends State<BuzzerStatusIndicator> {
  final SerialConnection _serial = SerialConnection();
  List<String> lines = List.empty(growable: true);
  StreamSubscription<String>? _serialSubscription;
  Timer? _timer;
  bool _emptyLines = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _timer?.cancel();
    _serialSubscription?.cancel();
    IconData icon;
    String tooltip;
    switch (_serial.status) {
      case SerialStatus.notConfigured:
        icon = Icons.rule;
        tooltip = "Buzzer Connection not configured";
      case SerialStatus.disconnected:
        icon = Icons.link_off;
        tooltip = "Buzzer Connection disconnected";
      case SerialStatus.connected:
        _serialSubscription = _serial.serialStream.listen((event) {
          lines.add(event);
          if (lines.length > 5) {
            if(_emptyLines) {
              setState(() {
                _emptyLines = false;
              });
            }
            lines.removeAt(0);
          }
        });
        if(_emptyLines) {
          icon = Icons.hourglass_empty;
          tooltip = "No Buzzer Data receiving...";
        }
        else {
          _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (lines.isEmpty) {
              setState(() {
                _emptyLines = true;
              });
            }
            else {
              lines.removeAt(0);
            }
          });
          return Icon(Icons.check, color: Theme
              .of(context)
              .colorScheme
              .surfaceContainerLowest);
        }
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          _serial.createSerialStream();
          setState(() {});
        },
        child: Tooltip(
          message: tooltip,
          child: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            child: Icon(icon),
          ),
        ),
      ),
    );

  }
}
