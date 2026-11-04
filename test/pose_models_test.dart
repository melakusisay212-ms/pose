import 'package:flutter_test/flutter_test.dart';
import 'package:pose_runner/pose/pose_models.dart';

void main() {
  test('visibleCount counts joints at or above the threshold', () {
    const frame = PoseFrame(
      points: <Joint, PosePoint>{
        Joint.nose: PosePoint(x: 0.5, y: 0.2, visibility: 0.9),
        Joint.leftHip: PosePoint(x: 0.4, y: 0.6, visibility: 0.5),
        Joint.rightHip: PosePoint(x: 0.6, y: 0.6, visibility: 0.2),
      },
      inferenceMs: 30,
      timestampMs: 1000,
    );
    expect(frame.hasPose, isTrue);
    expect(frame.visibleCount(), 2);
    expect(frame.visibleCount(threshold: 0.8), 1);
  });

  test('a frame without points has no pose', () {
    const frame = PoseFrame(
      points: <Joint, PosePoint>{},
      inferenceMs: 20,
      timestampMs: 0,
    );
    expect(frame.hasPose, isFalse);
    expect(frame.visibleCount(), 0);
  });

  test('every bone joins two different joints', () {
    for (final (a, b) in skeletonBones) {
      expect(a, isNot(b));
    }
  });
}
