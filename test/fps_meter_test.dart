import 'package:flutter_test/flutter_test.dart';
import 'package:pose_runner/pose/fps_meter.dart';

void main() {
  test('ten ticks inside one second read as 10 fps', () {
    final meter = FpsMeter();
    for (var i = 0; i < 10; i++) {
      meter.tick(i * 100);
    }
    expect(meter.fps(900), closeTo(10, 1e-9));
  });

  test('old ticks drop out of the window', () {
    final meter = FpsMeter();
    for (var i = 0; i < 10; i++) {
      meter.tick(i * 100);
    }
    expect(meter.fps(5000), closeTo(0, 1e-9));
  });

  test('reset clears the ticks', () {
    final meter = FpsMeter();
    meter.tick(0);
    meter.tick(100);
    meter.reset();
    expect(meter.fps(200), closeTo(0, 1e-9));
  });
}
