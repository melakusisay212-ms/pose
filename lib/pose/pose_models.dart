/// The joints the game cares about. This is a subset of the 33 landmarks that
/// ML Kit returns; more are added when a control needs them.
enum Joint {
  nose,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
}

/// Pairs of joints joined by a line when the skeleton is drawn.
const List<(Joint, Joint)> skeletonBones = <(Joint, Joint)>[
  (Joint.leftShoulder, Joint.rightShoulder),
  (Joint.leftShoulder, Joint.leftElbow),
  (Joint.leftElbow, Joint.leftWrist),
  (Joint.rightShoulder, Joint.rightElbow),
  (Joint.rightElbow, Joint.rightWrist),
  (Joint.leftShoulder, Joint.leftHip),
  (Joint.rightShoulder, Joint.rightHip),
  (Joint.leftHip, Joint.rightHip),
  (Joint.leftHip, Joint.leftKnee),
  (Joint.leftKnee, Joint.leftAnkle),
  (Joint.rightHip, Joint.rightKnee),
  (Joint.rightKnee, Joint.rightAnkle),
];

/// One joint position in "mirror space": the picture you see on screen when
/// the phone acts like a mirror. x is 0 at the left edge and 1 at the right
/// edge, y is 0 at the top and 1 at the bottom. Values can fall slightly
/// outside 0..1 when the joint is near or past the edge of the frame.
/// [visibility] is how sure the model is that the joint is in view (0 to 1).
class PosePoint {
  const PosePoint({
    required this.x,
    required this.y,
    required this.visibility,
  });

  final double x;
  final double y;
  final double visibility;
}

/// The result of analysing one camera frame.
class PoseFrame {
  const PoseFrame({
    required this.points,
    required this.inferenceMs,
    required this.timestampMs,
  });

  /// Empty when no person was found in the frame.
  final Map<Joint, PosePoint> points;

  /// How long the pose model took for this frame.
  final int inferenceMs;

  /// Milliseconds since the pose source started.
  final int timestampMs;

  bool get hasPose => points.isNotEmpty;

  /// How many joints the model is at least [threshold] sure about.
  int visibleCount({double threshold = 0.5}) {
    var count = 0;
    for (final point in points.values) {
      if (point.visibility >= threshold) count++;
    }
    return count;
  }
}
