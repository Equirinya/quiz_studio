/// How far this device's clock is from the presenting device's, so that a
/// countdown here ends when the host's does.
///
/// Every state the host sends carries its clock at the moment it was made
/// (`SessionState.clockMillis`). On arrival the difference to this device's
/// clock is the offset plus however long the state took to get here; the
/// smallest difference among the recent ones is the closest to the offset.
/// A state that waited (sent again, read from a cache) only ever gives a
/// larger one, so it never counts.
class HostClock {
  HostClock._();

  static final List<int> _samples = [];

  /// Recent states only: a new presenting device, or a clock set anew,
  /// takes over after this many states.
  static const int _keep = 30;

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  /// Notes a state made at [hostMillis] on the host, arriving now.
  static void sample(int? hostMillis, {int? now}) {
    if (hostMillis == null) return;
    _samples.add((now ?? _now()) - hostMillis);
    if (_samples.length > _keep) _samples.removeAt(0);
  }

  /// This device's clock minus the host's; null before any state came in.
  static int? get offset => _samples.isEmpty ? null : _samples.reduce((a, b) => a < b ? a : b);

  /// For tests.
  static void reset() => _samples.clear();
}
