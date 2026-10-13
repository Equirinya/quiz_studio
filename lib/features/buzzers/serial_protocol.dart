/// The wire format of the Arduino buzzer box, and how readings become
/// presses. Plain Dart, no serial port involved.
library;

/// Highest analog reading the box sends (10-bit ADC).
const int kBuzzerMaxValue = 1023;
const int kDefaultBuzzerThreshold = 512;

/// Reassembles lines from the chunks a serial port delivers.
class SerialLineBuffer {
  String _partial = '';

  /// Characters held back, waiting for their line to end.
  int get pending => _partial.length;

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
/// value rises above its threshold, and again only after it was let go.
///
/// "Let go" means clearly below the threshold, not just under it: a reading
/// that hovers around the threshold would otherwise fire again and again.
class BuzzerEdgeDetector {
  BuzzerEdgeDetector({this.releaseRatio = 0.8});

  /// Threshold per buzzer id; [kDefaultBuzzerThreshold] where none is set.
  final Map<int, int> thresholds = {};

  /// A held buzzer counts as released once its value is under this share of
  /// its threshold.
  final double releaseRatio;
  final Set<int> _down = {};

  int thresholdOf(int id) => thresholds[id] ?? kDefaultBuzzerThreshold;

  /// The buzzers currently held down, as of the last [update].
  Set<int> get down => Set.unmodifiable(_down);

  /// Returns the ids newly pressed with these readings.
  List<int> update(Map<int, int> values) {
    final pressed = <int>[];
    values.forEach((id, value) {
      final threshold = thresholdOf(id);
      if (value > threshold) {
        if (_down.add(id)) pressed.add(id);
      } else if (value < threshold * releaseRatio) {
        _down.remove(id);
      }
    });
    return pressed;
  }

  /// Forgets what was held, e.g. after the box was unplugged.
  void reset() => _down.clear();
}

/// Finds a threshold per buzzer from two short observations: all buzzers
/// left alone, then each pressed once. The threshold lands halfway between
/// the highest reading at rest and the peak of the press.
class BuzzerCalibration {
  final Map<int, int> _rest = {};
  final Map<int, int> _peak = {};
  bool _pressing = false;

  /// Second step: from now on readings are taken as presses.
  void startPressing() => _pressing = true;

  void add(Map<int, int> values) {
    final target = _pressing ? _peak : _rest;
    values.forEach((id, value) {
      if (value > (target[id] ?? -1)) target[id] = value;
    });
  }

  /// Whether the press of [id] stood out clearly enough from its rest level
  /// to calibrate on.
  bool isClear(int id) {
    final rest = _rest[id] ?? 0;
    final peak = _peak[id];
    return peak != null && peak - rest >= 60;
  }

  /// The buzzers pressed clearly so far.
  Set<int> get calibrated => {
        for (final id in _peak.keys)
          if (isClear(id)) id,
      };

  /// Thresholds for every buzzer that was pressed clearly.
  Map<int, int> get thresholds => {
        for (final id in calibrated) id: ((_rest[id] ?? 0) + (_peak[id]! - (_rest[id] ?? 0)) / 2).round(),
      };
}
