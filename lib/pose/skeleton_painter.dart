import 'package:flutter/material.dart';

import 'pose_models.dart';

/// Draws the detected skeleton over the camera preview. Repaints whenever
/// [notifier] gets a new frame, without rebuilding any widgets.
class SkeletonPainter extends CustomPainter {
  SkeletonPainter({required this.notifier, this.minVisibility = 0.5})
      : super(repaint: notifier);

  final ValueNotifier<PoseFrame?> notifier;
  final double minVisibility;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = notifier.value;
    if (frame == null) return;

    final bonePaint = Paint()
      ..color = const Color(0xCC00E676)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final strongJoint = Paint()..color = const Color(0xFFFFC107);
    final weakJoint = Paint()..color = const Color(0x88FF5252);

    Offset toCanvas(PosePoint p) => Offset(p.x * size.width, p.y * size.height);

    for (final (from, to) in skeletonBones) {
      final a = frame.points[from];
      final b = frame.points[to];
      if (a == null || b == null) continue;
      if (a.visibility < minVisibility || b.visibility < minVisibility) {
        continue;
      }
      canvas.drawLine(toCanvas(a), toCanvas(b), bonePaint);
    }
    for (final point in frame.points.values) {
      canvas.drawCircle(
        toCanvas(point),
        6,
        point.visibility >= minVisibility ? strongJoint : weakJoint,
      );
    }
  }

  @override
  bool shouldRepaint(SkeletonPainter oldDelegate) {
    return oldDelegate.notifier != notifier ||
        oldDelegate.minVisibility != minVisibility;
  }
}
