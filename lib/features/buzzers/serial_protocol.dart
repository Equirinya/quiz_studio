/// The wire format of the Arduino buzzer box, and how readings become
/// presses. Plain Dart, no serial port involved.
library;

/// Highest analog reading the box sends (10-bit ADC).
const int kBuzzerMaxValue = 1023;
const int kDefaultBuzzerThreshold = 512;

/// Reassembles lines from the chunks a serial port delivers.
class SerialLineBuffer {
  String _partial = '';

  /// Adds received text and returns the lines it completed.
  List<String> add(String chunk) {
    final parts = (_partial + chunk).split('\n');
    _partial = parts.removeLast();
    // A box that never sends a newline must not grow this forever.
    if (_partial.length > 1024) _partial = '';
    return [for (final part in parts) if (part.trim().isNotEmpty) part.trim()];
  }
}

/// Parses one line of readings, `id:value,id:value,…`, e.g. `0:812,1:14`.
/// Returns null when nothing in the line is a reading.
Map<int, int>? parseBuzzerLine(String line) {
  final values = <int, int>{};
  for (final entry in line.split(',')) {
    final parts = entry.split(':');
    if (parts.length != 2) continue;
    final id = int.tryParse(parts[0].trim());
    final value = int.tryParse(parts[1].trim());
    if (id != null && value != null) values[id] = value;
  }
  return values.isEmpty ? null : values;
}

/// Turns a stream of readings into presses: a buzzer counts once when its
/// value rises above its threshold, and again only after it dropped below.
class BuzzerEdgeDetector {
  /// Threshold per buzzer id; [kDefaultBuzzerThreshold] where none is set.
  final Map<int, int> thresholds = {};
  final Set<int> _down = {};

  int thresholdOf(int id) => thresholds[id] ?? kDefaultBuzzerThreshold;

  /// The buzzers currently held down, as of the last [update].
  Set<int> get down => Set.unmodifiable(_down);

  /// Returns the ids newly pressed with these readings.
  List<int> update(Map<int, int> values) {
    final pressed = <int>[];
    values.forEach((id, value) {
      if (value > thresholdOf(id)) {
        if (_down.add(id)) pressed.add(id);
      } else {
        _down.remove(id);
      }
    });
    return pressed;
  }
}
