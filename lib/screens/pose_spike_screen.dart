import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../camera_status.dart';
import '../diag/breadcrumbs.dart';
import '../pose/benchmark.dart';
import '../pose/fps_meter.dart';
import '../pose/mlkit_pose_source.dart';
import '../pose/pose_models.dart';
import '../pose/skeleton_painter.dart';

/// Test 3: the pose go / no-go test. Shows the camera with the detected
/// skeleton on top, live speed numbers, and a 60 second speed test.
class PoseSpikeScreen extends StatefulWidget {
  const PoseSpikeScreen({super.key});

  @override
  State<PoseSpikeScreen> createState() => _PoseSpikeScreenState();
}

class _PoseSpikeScreenState extends State<PoseSpikeScreen>
    with WidgetsBindingObserver {
  final Breadcrumbs _crumbs = Breadcrumbs.instance;
  final ValueNotifier<PoseFrame?> _latestFrame = ValueNotifier<PoseFrame?>(null);
  final FpsMeter _fpsMeter = FpsMeter();
  final Stopwatch _clock = Stopwatch()..start();
  final Stopwatch _benchClock = Stopwatch();

  CameraController? _controller;
  MlKitPoseSource? _source;
  StreamSubscription<PoseFrame>? _subscription;
  Future<void>? _closing;
  Timer? _uiTimer;

  CameraProblem? _problem;
  String? _errorDetail;
  bool _starting = true;

  // Start with the fastest setup: if it cannot reach the target, the slower
  // ones will not either.
  PoseModelKind _model = PoseModelKind.fast;
  ResolutionPreset _resolution = ResolutionPreset.low;

  double _fps = 0;
  double _avgInferenceMs = 0;
  int _frames = 0;

  Benchmark? _benchmark;
  int _benchmarkSecondsLeft = 0;
  BenchmarkResult? _result;
  String _resultLabel = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _uiTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _refreshStats(),
    );
    unawaited(_open());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiTimer?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_shutdown(_source, _controller));
    _latestFrame.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // While the permission dialog is open the app goes inactive; the open
    // call is still running then, so we only react when it is not.
    if (_starting) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_close());
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      unawaited(_open());
    }
  }

  Future<void> _shutdown(
    MlKitPoseSource? source,
    CameraController? controller,
  ) async {
    _crumbs.add('test 3: shutting down');
    await source?.dispose();
    await controller?.dispose();
    _crumbs.add('test 3: shut down');
  }

  Future<void> _close() {
    final pending = _closeNow();
    _closing = pending;
    return pending;
  }

  Future<void> _closeNow() async {
    _stopBenchmark();
    await _subscription?.cancel();
    _subscription = null;
    final source = _source;
    final controller = _controller;
    _source = null;
    _controller = null;
    if (mounted) setState(() {});
    await _shutdown(source, controller);
  }

  Future<void> _open() async {
    await _closing;
    if (!mounted) return;
    setState(() {
      _starting = true;
      _problem = null;
      _errorDetail = null;
    });
    _fpsMeter.reset();
    _frames = 0;
    _avgInferenceMs = 0;
    _latestFrame.value = null;
    _crumbs.add(
      'test 3: opening (${_model.name} model, ${_resolution.name} resolution)',
    );

    CameraController? controller;
    MlKitPoseSource? source;
    try {
      _crumbs.add('test 3: listing cameras');
      final cameras = await availableCameras();
      final camera = pickFrontCamera(cameras);
      if (camera == null) {
        _crumbs.add('test 3: no front camera');
        if (mounted) {
          setState(() {
            _problem = CameraProblem.noCamera;
            _starting = false;
          });
        }
        return;
      }
      _crumbs.add('test 3: initializing camera (NV21)');
      controller = CameraController(
        camera,
        _resolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      _crumbs.add('test 3: camera ready');
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _crumbs.add('test 3: creating the pose detector');
      source = MlKitPoseSource(
        controller: controller,
        camera: camera,
        model: _model,
        trace: _crumbs.add,
      );
      _subscription = source.frames.listen(_onFrame);
      await source.start();
      if (!mounted) {
        await _subscription?.cancel();
        _subscription = null;
        await _shutdown(source, controller);
        return;
      }
      setState(() {
        _controller = controller;
        _source = source;
        _starting = false;
      });
      _crumbs.add('test 3: running');
    } on Object catch (error) {
      _crumbs.add('test 3: error $error');
      await _subscription?.cancel();
      _subscription = null;
      await source?.dispose();
      await controller?.dispose();
      if (mounted) {
        setState(() {
          _problem = classifyCameraError(error);
          _errorDetail = '$error';
          _starting = false;
        });
      }
    }
  }

  Future<void> _reopen() async {
    await _close();
    await _open();
  }

  void _changeModel(PoseModelKind kind) {
    if (kind == _model) return;
    setState(() => _model = kind);
    unawaited(_reopen());
  }

  void _changeResolution(ResolutionPreset preset) {
    if (preset == _resolution) return;
    setState(() => _resolution = preset);
    unawaited(_reopen());
  }

  void _onFrame(PoseFrame frame) {
    _latestFrame.value = frame;
    _fpsMeter.tick(_clock.elapsedMilliseconds);
    _avgInferenceMs = _frames == 0
        ? frame.inferenceMs.toDouble()
        : _avgInferenceMs * 0.9 + frame.inferenceMs * 0.1;
    _frames++;
    _benchmark?.addFrame(
      elapsedMs: _benchClock.elapsedMilliseconds,
      hasPose: frame.hasPose,
    );
  }

  void _refreshStats() {
    if (!mounted) return;
    final bench = _benchmark;
    if (bench != null) {
      final left =
          bench.durationSeconds - _benchClock.elapsedMilliseconds ~/ 1000;
      if (left <= 0) {
        _finishBenchmark();
        return;
      }
      _benchmarkSecondsLeft = left;
    }
    setState(() {
      _fps = _fpsMeter.fps(_clock.elapsedMilliseconds);
    });
  }

  void _startBenchmark() {
    if (_controller == null) return;
    final bench = Benchmark();
    _benchClock
      ..reset()
      ..start();
    _crumbs.add('test 3: 60 s speed test started');
    setState(() {
      _benchmark = bench;
      _benchmarkSecondsLeft = bench.durationSeconds;
      _result = null;
    });
  }

  void _finishBenchmark() {
    final bench = _benchmark;
    if (bench == null) return;
    _benchClock.stop();
    final modelName = _model == PoseModelKind.fast ? 'Fast' : 'Accurate';
    final result = bench.finish();
    _crumbs.add(
      'test 3: speed test done, ${result.passed ? 'PASS' : 'FAIL'}, '
      '${result.averageFps.toStringAsFixed(1)} FPS average',
    );
    setState(() {
      _result = result;
      _resultLabel = '$modelName model, ${_resolution.name} resolution';
      _benchmark = null;
    });
  }

  void _stopBenchmark() {
    _benchClock.stop();
    _benchmark = null;
  }

  void _cancelBenchmark() {
    setState(_stopBenchmark);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(child: _buildPreview()),
            _buildPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_starting) {
      return const Center(child: CircularProgressIndicator());
    }
    final problem = _problem;
    if (problem != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.videocam_off, size: 48),
              const SizedBox(height: 16),
              Text(
                problemMessage(problem),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_errorDetail != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  _errorDetail!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => unawaited(_open()),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return Center(
      child: AspectRatio(
        aspectRatio: 1 / controller.value.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CameraPreview(controller),
            CustomPaint(painter: SkeletonPainter(notifier: _latestFrame)),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel() {
    final source = _source;
    final frame = _latestFrame.value;
    final issue = source?.lastIssue;
    final result = _result;
    final bench = _benchmark;
    final person = frame == null ? '-' : (frame.hasPose ? 'yes' : 'no');
    final joints = frame == null ? 0 : frame.visibleCount();
    final controlsLocked = _starting || _controller == null;

    final headline = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: _fps >= 15 ? Colors.greenAccent : Colors.orangeAccent,
    );

    return Container(
      width: double.infinity,
      color: Colors.black87,
      constraints: const BoxConstraints(maxHeight: 300),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'FPS ${_fps.toStringAsFixed(1)}  |  '
              'model ${_avgInferenceMs.toStringAsFixed(0)} ms',
              style: headline,
            ),
            const SizedBox(height: 4),
            Text(
              'Person found: $person  |  joints visible: $joints of '
              '${Joint.values.length}  |  skipped frames: '
              '${source?.droppedFrames ?? 0}',
            ),
            Text('Frame: ${source?.frameInfo ?? '-'}'),
            if (issue != null)
              Text(
                'Issue: $issue',
                style: const TextStyle(color: Colors.redAccent),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                SegmentedButton<PoseModelKind>(
                  segments: const <ButtonSegment<PoseModelKind>>[
                    ButtonSegment<PoseModelKind>(
                      value: PoseModelKind.fast,
                      label: Text('Fast'),
                    ),
                    ButtonSegment<PoseModelKind>(
                      value: PoseModelKind.accurate,
                      label: Text('Accurate'),
                    ),
                  ],
                  selected: <PoseModelKind>{_model},
                  onSelectionChanged: controlsLocked
                      ? null
                      : (Set<PoseModelKind> s) => _changeModel(s.first),
                ),
                SegmentedButton<ResolutionPreset>(
                  segments: const <ButtonSegment<ResolutionPreset>>[
                    ButtonSegment<ResolutionPreset>(
                      value: ResolutionPreset.low,
                      label: Text('Low res'),
                    ),
                    ButtonSegment<ResolutionPreset>(
                      value: ResolutionPreset.medium,
                      label: Text('Medium res'),
                    ),
                  ],
                  selected: <ResolutionPreset>{_resolution},
                  onSelectionChanged: controlsLocked
                      ? null
                      : (Set<ResolutionPreset> s) => _changeResolution(s.first),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: controlsLocked
                  ? null
                  : (bench == null ? _startBenchmark : _cancelBenchmark),
              child: Text(
                bench == null
                    ? 'Start 60 s test'
                    : 'Stop test ($_benchmarkSecondsLeft s left)',
              ),
            ),
            if (bench == null && result == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Stand 2 to 3 m away with your whole body in view, '
                  'then start the test and keep moving.',
                ),
              ),
            if (result != null) ..._buildResult(result),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildResult(BenchmarkResult result) {
    final verdict = result.passed ? 'PASS' : 'FAIL';
    final percent = (result.poseRate * 100).round();
    return <Widget>[
      const SizedBox(height: 8),
      Text(
        '$verdict  |  $_resultLabel',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: result.passed ? Colors.greenAccent : Colors.redAccent,
        ),
      ),
      Text(
        'Average ${result.averageFps.toStringAsFixed(1)} FPS  |  '
        'slowest second ${result.minFps} FPS',
      ),
      Text('Person found in $percent% of frames'),
      const Text(
        'Pass rule (our starting choice): average at least 15 FPS and no '
        'second below 10 FPS.',
      ),
    ];
  }
}
