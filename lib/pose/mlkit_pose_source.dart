import 'dart:async';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'frame_geometry.dart';
import 'pose_models.dart';
import 'pose_source.dart';

/// Which ML Kit pose model to run.
enum PoseModelKind { fast, accurate }

/// Reads camera frames from [controller], runs ML Kit pose detection on them
/// one at a time, and publishes the result as [PoseFrame]s in mirror space.
class MlKitPoseSource implements PoseSource {
  MlKitPoseSource({
    required CameraController controller,
    required CameraDescription camera,
    required PoseModelKind model,
    void Function(String message)? trace,
  })  : _controller = controller,
        _camera = camera,
        _trace = trace,
        _detector = PoseDetector(
          options: PoseDetectorOptions(
            mode: PoseDetectionMode.stream,
            model: model == PoseModelKind.fast
                ? PoseDetectionModel.base
                : PoseDetectionModel.accurate,
          ),
        ) {
    _trace?.call('pose: detector object created (${model.name} model)');
  }

  /// Which ML Kit landmark feeds which of our joints.
  static const Map<Joint, PoseLandmarkType> _landmarkFor =
      <Joint, PoseLandmarkType>{
    Joint.nose: PoseLandmarkType.nose,
    Joint.leftShoulder: PoseLandmarkType.leftShoulder,
    Joint.rightShoulder: PoseLandmarkType.rightShoulder,
    Joint.leftElbow: PoseLandmarkType.leftElbow,
    Joint.rightElbow: PoseLandmarkType.rightElbow,
    Joint.leftWrist: PoseLandmarkType.leftWrist,
    Joint.rightWrist: PoseLandmarkType.rightWrist,
    Joint.leftHip: PoseLandmarkType.leftHip,
    Joint.rightHip: PoseLandmarkType.rightHip,
    Joint.leftKnee: PoseLandmarkType.leftKnee,
    Joint.rightKnee: PoseLandmarkType.rightKnee,
    Joint.leftAnkle: PoseLandmarkType.leftAnkle,
    Joint.rightAnkle: PoseLandmarkType.rightAnkle,
  };

  final CameraController _controller;
  final CameraDescription _camera;
  final PoseDetector _detector;
  final void Function(String message)? _trace;
  final StreamController<PoseFrame> _out =
      StreamController<PoseFrame>.broadcast();
  final Stopwatch _clock = Stopwatch()..start();

  bool _running = false;
  bool _busy = false;
  bool _tracedFirstFrame = false;
  bool _tracedFirstResult = false;
  int _dropped = 0;
  String? _lastIssue;
  String _frameInfo = '-';

  @override
  Stream<PoseFrame> get frames => _out.stream;

  @override
  int get droppedFrames => _dropped;

  @override
  String? get lastIssue => _lastIssue;

  @override
  String get frameInfo => _frameInfo;

  bool get _isFront => _camera.lensDirection == CameraLensDirection.front;

  // The app is locked to portrait, so the device-orientation compensation
  // is always 0.
  int get _rotationDegrees => frameRotationDegrees(
        sensorOrientation: _camera.sensorOrientation,
        deviceCompensation: 0,
        isFrontCamera: _isFront,
      );

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;
    _trace?.call('pose: starting frame stream');
    await _controller.startImageStream(_onImage);
    _trace?.call('pose: frame stream started');
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    try {
      if (_controller.value.isStreamingImages) {
        await _controller.stopImageStream();
      }
    } on Object catch (_) {
      // The camera may already be shutting down; nothing more to stop.
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    try {
      await _detector.close();
    } on Object catch (_) {
      // Already closed.
    }
    await _out.close();
  }

  void _onImage(CameraImage image) {
    if (!_running) return;
    if (!_tracedFirstFrame) {
      _tracedFirstFrame = true;
      _trace?.call(
        'pose: first camera frame ${image.width} x ${image.height}, '
        '${image.planes.length} plane(s), format ${image.format.raw}',
      );
    }
    if (_busy) {
      _dropped++;
      return;
    }
    _busy = true;
    _process(image).whenComplete(() {
      _busy = false;
    });
  }

  Future<void> _process(CameraImage image) async {
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      if (!_tracedFirstResult) {
        _trace?.call('pose: first processImage call (loads the model)');
      }
      final watch = Stopwatch()..start();
      final poses = await _detector.processImage(input);
      watch.stop();
      if (!_tracedFirstResult) {
        _tracedFirstResult = true;
        _trace?.call(
          'pose: first result ok, ${poses.length} person(s), '
          '${watch.elapsedMilliseconds} ms',
        );
      }
      if (!_running || _out.isClosed) return;
      _out.add(_toFrame(poses, image, watch.elapsedMilliseconds));
    } on Object catch (error) {
      _lastIssue = 'Detection error: $error';
      _trace?.call('pose: detection error $error');
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final degrees = _rotationDegrees;
    _frameInfo = '${image.width} x ${image.height} raw, rotated $degrees deg';
    if (image.planes.length != 1) {
      _lastIssue = 'Unsupported frame: ${image.planes.length} planes, '
          'format ${image.format.raw}. Expected 1 plane (NV21).';
      return null;
    }
    final rotation = InputImageRotationValue.fromRawValue(degrees);
    if (rotation == null) {
      _lastIssue = 'Unsupported rotation: $degrees';
      return null;
    }
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  PoseFrame _toFrame(List<Pose> poses, CameraImage image, int inferenceMs) {
    final nowMs = _clock.elapsedMilliseconds;
    if (poses.isEmpty) {
      return PoseFrame(
        points: const <Joint, PosePoint>{},
        inferenceMs: inferenceMs,
        timestampMs: nowMs,
      );
    }
    final (width, height) = uprightSize(
      rawWidth: image.width,
      rawHeight: image.height,
      rotationDegrees: _rotationDegrees,
    );
    final landmarks = poses.first.landmarks;
    final points = <Joint, PosePoint>{};
    for (final entry in _landmarkFor.entries) {
      final landmark = landmarks[entry.value];
      if (landmark == null) continue;
      final (x, y) = toMirrorSpace(
        x: landmark.x,
        y: landmark.y,
        uprightWidth: width,
        uprightHeight: height,
        mirror: _isFront,
      );
      points[entry.key] = PosePoint(
        x: x,
        y: y,
        visibility: landmark.likelihood,
      );
    }
    return PoseFrame(
      points: points,
      inferenceMs: inferenceMs,
      timestampMs: nowMs,
    );
  }
}
