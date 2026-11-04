import 'pose_models.dart';

/// Anything that produces [PoseFrame]s. The game and the control detectors
/// depend on this, not on a particular library, so the pose engine can be
/// swapped (for example for a native MediaPipe module) without touching them.
abstract class PoseSource {
  /// One event per analysed camera frame, with an empty pose when nobody
  /// is in view.
  Stream<PoseFrame> get frames;

  /// Camera frames skipped because the previous one was still being analysed.
  int get droppedFrames;

  /// Most recent problem worth showing on the debug screen, if any.
  String? get lastIssue;

  /// Short description of the raw frames, for the debug screen.
  String get frameInfo;

  Future<void> start();

  Future<void> stop();

  Future<void> dispose();
}
