import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../camera_status.dart';
import '../diag/breadcrumbs.dart';

/// Test 1 (stream: false): front camera preview in the NV21 format.
/// Test 2 (stream: true): same, plus receiving camera frames, no pose model.
class CameraProbeScreen extends StatefulWidget {
  const CameraProbeScreen({super.key, required this.stream});

  final bool stream;

  @override
  State<CameraProbeScreen> createState() => _CameraProbeScreenState();
}

class _CameraProbeScreenState extends State<CameraProbeScreen> {
  final Breadcrumbs _crumbs = Breadcrumbs.instance;
  final Stopwatch _clock = Stopwatch()..start();

  CameraController? _controller;
  Timer? _timer;
  String? _error;
  String _status = 'Starting...';
  int _frames = 0;
  int _lastFrames = 0;
  int _lastMs = 0;
  double _fps = 0;
  String _frameInfo = '-';

  String get _label => widget.stream ? 'test 2' : 'test 1';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
    unawaited(_start());
  }

  @override
  void dispose() {
    _timer?.cancel();
    final controller = _controller;
    if (controller != null) {
      unawaited(_stop(controller));
    }
    super.dispose();
  }

  Future<void> _stop(CameraController controller) async {
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } on Object catch (_) {
      // Camera may already be closing.
    }
    try {
      await controller.dispose();
    } on Object catch (_) {
      // Already disposed.
    }
    _crumbs.add('$_label: camera closed');
  }

  Future<void> _start() async {
    try {
      _crumbs.add('$_label: listing cameras');
      final cameras = await availableCameras();
      final camera = pickFrontCamera(cameras);
      if (camera == null) {
        _crumbs.add('$_label: no front camera');
        if (mounted) setState(() => _error = 'This phone has no front camera.');
        return;
      }
      _crumbs.add('$_label: initializing camera (low resolution, NV21)');
      final controller = CameraController(
        camera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      _crumbs.add('$_label: camera ready');
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _status = 'Camera ready';
      });
      if (widget.stream) {
        _crumbs.add('$_label: starting frame stream');
        await controller.startImageStream(_onImage);
        _crumbs.add('$_label: stream started');
        if (mounted) setState(() => _status = 'Receiving frames');
      }
    } on Object catch (error) {
      _crumbs.add('$_label: error $error');
      if (mounted) setState(() => _error = '$error');
    }
  }

  void _onImage(CameraImage image) {
    _frames++;
    if (_frames == 1) {
      final bytes = image.planes.isEmpty ? 0 : image.planes.first.bytes.length;
      final expected = (image.width * image.height * 3) ~/ 2;
      _frameInfo = '${image.width} x ${image.height}, '
          'planes ${image.planes.length}, format ${image.format.raw}, '
          'bytes $bytes (NV21 needs $expected)';
      _crumbs.add('$_label: first frame $_frameInfo');
    }
  }

  void _tick() {
    if (!mounted) return;
    final now = _clock.elapsedMilliseconds;
    final elapsed = now - _lastMs;
    if (elapsed > 0) {
      _fps = (_frames - _lastFrames) * 1000 / elapsed;
    }
    _lastFrames = _frames;
    _lastMs = now;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: controller != null && controller.value.isInitialized
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: 1 / controller.value.aspectRatio,
                        child: CameraPreview(controller),
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
            Container(
              width: double.infinity,
              color: Colors.black87,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.stream
                        ? 'Test 2: camera + frame stream'
                        : 'Test 1: camera preview only',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('Status: $_status'),
                  if (widget.stream) ...<Widget>[
                    Text('Frames: $_frames  |  ${_fps.toStringAsFixed(1)} per second'),
                    Text('First frame: $_frameInfo'),
                  ],
                  if (_error != null)
                    Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  const SizedBox(height: 8),
                  const Text('Swipe back to return to the test list.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
