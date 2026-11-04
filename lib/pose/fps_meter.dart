/// Counts how many frames arrived during the last [windowMs] milliseconds.
class FpsMeter {
  FpsMeter({this.windowMs = 1000});

  final int windowMs;
  final List<int> _stamps = <int>[];

  /// Record one frame at time [nowMs] (any steady clock, in milliseconds).
  void tick(int nowMs) {
    _stamps.add(nowMs);
    _trim(nowMs);
  }

  /// Frames per second as seen at time [nowMs].
  double fps(int nowMs) {
    _trim(nowMs);
    return _stamps.length * 1000 / windowMs;
  }

  void reset() => _stamps.clear();

  void _trim(int nowMs) {
    while (_stamps.isNotEmpty && nowMs - _stamps.first >= windowMs) {
      _stamps.removeAt(0);
    }
  }
}
