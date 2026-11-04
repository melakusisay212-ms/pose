import 'package:camera/camera.dart';

/// Why the camera screen cannot show a preview.
enum CameraProblem { noCamera, permissionDenied, initFailed }

/// Returns the first front-facing camera, or null if the phone has none.
CameraDescription? pickFrontCamera(List<CameraDescription> cameras) {
  for (final camera in cameras) {
    if (camera.lensDirection == CameraLensDirection.front) {
      return camera;
    }
  }
  return null;
}

/// Turns an error thrown while starting the camera into a [CameraProblem].
CameraProblem classifyCameraError(Object error) {
  if (error is CameraException) {
    final code = error.code;
    if (code.startsWith('CameraAccessDenied') ||
        code == 'CameraAccessRestricted') {
      return CameraProblem.permissionDenied;
    }
  }
  return CameraProblem.initFailed;
}

/// Plain-language message shown to the player for each problem.
String problemMessage(CameraProblem problem) {
  return switch (problem) {
    CameraProblem.noCamera => 'This phone has no front camera.',
    CameraProblem.permissionDenied =>
      'Camera permission is off. Open Settings, Apps, Pose Runner, '
          'Permissions, and allow Camera.',
    CameraProblem.initFailed =>
      'The camera could not start. Close other apps that use the camera '
          'and try again.',
  };
}
