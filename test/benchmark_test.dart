import 'package:flutter_test/flutter_test.dart';
import 'package:pose_runner/pose/benchmark.dart';

/// Feeds [frames] evenly spaced frames into the given whole [second].
void feed(Benchmark b, int second, int frames, {bool hasPose = true}) {
  for (var i = 0; i < frames; i++) {
    b.addFrame(
      elapsedMs: second * 1000 + (i * 1000) ~/ frames,
      hasPose: hasPose,
    );
  }
}

void main() {
  Benchmark shortRun() => Benchmark(durationSeconds: 12, warmupSeconds: 2);

  test('steady 20 fps passes', () {
    final b = shortRun();
    for (var s = 0; s < 12; s++) {
      feed(b, s, 20);
    }
    final r = b.finish();
    expect(r.averageFps, closeTo(20, 1e-9));
    expect(r.minFps, 20);
    expect(r.secondsCounted, 10);
    expect(r.poseRate, closeTo(1.0, 1e-9));
    expect(r.passed, isTrue);
  });

  test('steady 8 fps fails on the average', () {
    final b = shortRun();
    for (var s = 0; s < 12; s++) {
      feed(b, s, 8);
    }
    final r = b.finish();
    expect(r.averageFps, closeTo(8, 1e-9));
    expect(r.passed, isFalse);
  });

  test('one very slow second fails even when the average is fine', () {
    final b = shortRun();
    for (var s = 0; s < 12; s++) {
      feed(b, s, s == 5 ? 5 : 20);
    }
    final r = b.finish();
    expect(r.averageFps, closeTo(18.5, 1e-9));
    expect(r.minFps, 5);
    expect(r.passed, isFalse);
  });

  test('warm-up seconds are ignored', () {
    final b = shortRun();
    feed(b, 0, 2);
    feed(b, 1, 2);
    for (var s = 2; s < 12; s++) {
      feed(b, s, 20);
    }
    final r = b.finish();
    expect(r.averageFps, closeTo(20, 1e-9));
    expect(r.passed, isTrue);
  });

  test('frames after the end are ignored', () {
    final b = shortRun();
    for (var s = 0; s < 12; s++) {
      feed(b, s, 20);
    }
    feed(b, 12, 100);
    expect(b.finish().averageFps, closeTo(20, 1e-9));
  });

  test('no frames at all fails', () {
    final r = shortRun().finish();
    expect(r.averageFps, 0);
    expect(r.minFps, 0);
    expect(r.poseRate, 0);
    expect(r.passed, isFalse);
  });

  test('pose rate is the share of frames with a person', () {
    final b = shortRun();
    for (var s = 0; s < 12; s++) {
      feed(b, s, 20, hasPose: s.isEven);
    }
    expect(b.finish().poseRate, closeTo(0.5, 1e-9));
  });
}
