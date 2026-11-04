import 'package:flutter_test/flutter_test.dart';
import 'package:pose_runner/pose/frame_geometry.dart';

void main() {
  group('frameRotationDegrees', () {
    test('front camera adds the compensation', () {
      expect(
        frameRotationDegrees(
          sensorOrientation: 270,
          deviceCompensation: 0,
          isFrontCamera: true,
        ),
        270,
      );
      expect(
        frameRotationDegrees(
          sensorOrientation: 270,
          deviceCompensation: 90,
          isFrontCamera: true,
        ),
        0,
      );
    });

    test('back camera subtracts the compensation', () {
      expect(
        frameRotationDegrees(
          sensorOrientation: 90,
          deviceCompensation: 0,
          isFrontCamera: false,
        ),
        90,
      );
      expect(
        frameRotationDegrees(
          sensorOrientation: 90,
          deviceCompensation: 180,
          isFrontCamera: false,
        ),
        270,
      );
    });
  });

  group('uprightSize', () {
    test('swaps width and height for 90 and 270 degrees', () {
      expect(
        uprightSize(rawWidth: 720, rawHeight: 480, rotationDegrees: 270),
        (480.0, 720.0),
      );
      expect(
        uprightSize(rawWidth: 720, rawHeight: 480, rotationDegrees: 90),
        (480.0, 720.0),
      );
    });

    test('keeps width and height for 0 and 180 degrees', () {
      expect(
        uprightSize(rawWidth: 720, rawHeight: 480, rotationDegrees: 0),
        (720.0, 480.0),
      );
      expect(
        uprightSize(rawWidth: 720, rawHeight: 480, rotationDegrees: 180),
        (720.0, 480.0),
      );
    });
  });

  group('toMirrorSpace', () {
    test('flips x when mirroring', () {
      final (x, y) = toMirrorSpace(
        x: 120,
        y: 360,
        uprightWidth: 480,
        uprightHeight: 720,
        mirror: true,
      );
      expect(x, closeTo(0.75, 1e-9));
      expect(y, closeTo(0.5, 1e-9));
    });

    test('keeps x when not mirroring', () {
      final (x, y) = toMirrorSpace(
        x: 120,
        y: 180,
        uprightWidth: 480,
        uprightHeight: 720,
        mirror: false,
      );
      expect(x, closeTo(0.25, 1e-9));
      expect(y, closeTo(0.25, 1e-9));
    });

    test('lets positions outside the frame fall outside 0..1', () {
      final (x, _) = toMirrorSpace(
        x: -48,
        y: 0,
        uprightWidth: 480,
        uprightHeight: 720,
        mirror: false,
      );
      expect(x, closeTo(-0.1, 1e-9));
    });
  });
}
