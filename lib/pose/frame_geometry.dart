/// Pure maths for turning raw camera frames into screen positions.
/// No Flutter or ML Kit imports, so it can be tested on its own.

/// Degrees (0, 90, 180 or 270) a raw camera frame must be rotated to be
/// upright. For the front camera the rule is
/// (sensorOrientation + deviceCompensation) % 360, where the compensation is
/// 0 when the phone is held upright. Our app is locked to portrait, so the
/// compensation is always 0.
int frameRotationDegrees({
  required int sensorOrientation,
  required int deviceCompensation,
  required bool isFrontCamera,
}) {
  if (isFrontCamera) {
    return (sensorOrientation + deviceCompensation) % 360;
  }
  return (sensorOrientation - deviceCompensation + 360) % 360;
}

/// Width and height of the frame after it has been rotated upright.
(double, double) uprightSize({
  required int rawWidth,
  required int rawHeight,
  required int rotationDegrees,
}) {
  final swapped = rotationDegrees == 90 || rotationDegrees == 270;
  if (swapped) {
    return (rawHeight.toDouble(), rawWidth.toDouble());
  }
  return (rawWidth.toDouble(), rawHeight.toDouble());
}

/// Converts a position in pixels of the upright frame into 0..1 mirror space.
/// [mirror] is true for the front camera, whose on-screen preview is flipped
/// left to right like a mirror while the frames given to the model are not.
(double, double) toMirrorSpace({
  required double x,
  required double y,
  required double uprightWidth,
  required double uprightHeight,
  required bool mirror,
}) {
  final nx = x / uprightWidth;
  final ny = y / uprightHeight;
  return (mirror ? 1.0 - nx : nx, ny);
}
