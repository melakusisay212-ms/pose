/// Outcome of one timed speed test.
class BenchmarkResult {
  const BenchmarkResult({
    required this.averageFps,
    required this.minFps,
    required this.poseRate,
    required this.secondsCounted,
    required this.passed,
  });

  /// Average frames per second over the counted seconds.
  final double averageFps;

  /// Frames in the slowest counted second.
  final int minFps;

  /// Share of counted frames (0 to 1) in which a person was found.
  final double poseRate;

  /// Seconds that counted, after the warm-up seconds are left out.
  final int secondsCounted;

  final bool passed;
}

/// Collects frame times during a timed test and judges them.
///
/// The pass rule is a design choice, not a fact about the technology:
/// the average must reach [targetFps] and no counted second may fall below
/// [floorFps]. The first [warmupSeconds] are left out because the model and
/// camera are still starting.
class Benchmark {
  Benchmark({
    this.durationSeconds = 60,
    this.warmupSeconds = 2,
    this.targetFps = 15,
    this.floorFps = 10,
  }) : assert(warmupSeconds < durationSeconds);

  final int durationSeconds;
  final int warmupSeconds;
  final int targetFps;
  final int floorFps;

  late final List<int> _perSecond = List<int>.filled(durationSeconds, 0);
  int _poseFrames = 0;

  /// Record a frame that arrived [elapsedMs] after the test started.
  void addFrame({required int elapsedMs, required bool hasPose}) {
    final second = elapsedMs ~/ 1000;
    if (second < warmupSeconds || second >= durationSeconds) return;
    _perSecond[second]++;
    if (hasPose) _poseFrames++;
  }

  BenchmarkResult finish() {
    final counted = _perSecond.sublist(warmupSeconds);
    var total = 0;
    var slowest = counted.first;
    for (final frames in counted) {
      total += frames;
      if (frames < slowest) slowest = frames;
    }
    final average = total / counted.length;
    final poseRate = total == 0 ? 0.0 : _poseFrames / total;
    return BenchmarkResult(
      averageFps: average,
      minFps: slowest,
      poseRate: poseRate,
      secondsCounted: counted.length,
      passed: average >= targetFps && slowest >= floorFps,
    );
  }
}
