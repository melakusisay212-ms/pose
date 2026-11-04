import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_runner/camera_status.dart';

void main() {
  final back = CameraDescription(
    name: 'back0',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
  );
  final front = CameraDescription(
    name: 'front1',
    lensDirection: CameraLensDirection.front,
    sensorOrientation: 270,
  );

  group('pickFrontCamera', () {
    test('returns the front camera when the phone has one', () {
      expect(pickFrontCamera(<CameraDescription>[back, front]), front);
    });

    test('returns null when there is no front camera', () {
      expect(pickFrontCamera(<CameraDescription>[back]), isNull);
      expect(pickFrontCamera(<CameraDescription>[]), isNull);
    });
  });

  group('classifyCameraError', () {
    test('permission codes become permissionDenied', () {
      expect(
        classifyCameraError(CameraException('CameraAccessDenied', 'no')),
        CameraProblem.permissionDenied,
      );
      expect(
        classifyCameraError(
          CameraException('CameraAccessDeniedWithoutPrompt', 'no'),
        ),
        CameraProblem.permissionDenied,
      );
      expect(
        classifyCameraError(CameraException('CameraAccessRestricted', 'no')),
        CameraProblem.permissionDenied,
      );
    });

    test('other errors become initFailed', () {
      expect(
        classifyCameraError(CameraException('cameraInUse', 'busy')),
        CameraProblem.initFailed,
      );
      expect(classifyCameraError(StateError('x')), CameraProblem.initFailed);
    });
  });

  test('every problem has a message', () {
    for (final problem in CameraProblem.values) {
      expect(problemMessage(problem), isNotEmpty);
    }
  });
}
