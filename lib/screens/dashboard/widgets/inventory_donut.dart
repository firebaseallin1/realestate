import 'dart:math' as math;
import 'package:flutter/material.dart';

/// DonutSegment is one colored slice of an [InventoryDonut].
class DonutSegment {
  final double value;
  final Color color;

  const DonutSegment(this.value, this.color);
}

/// InventoryDonut draws a ring split into colored segments (for example
/// sold / booked / available units) with any widget in the middle.
class InventoryDonut extends StatelessWidget {
  final List<DonutSegment> segments;
  final double size;
  final double strokeWidth;
  final Color trackColor;
  final Widget? center;

  const InventoryDonut({
    super.key,
    required this.segments,
    required this.size,
    this.strokeWidth = 12,
    this.trackColor = const Color(0x14000000),
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, progress, child) => CustomPaint(
          painter: _DonutPainter(
            segments: segments,
            strokeWidth: strokeWidth,
            trackColor: trackColor,
            progress: progress,
          ),
          child: child,
        ),
        child: center == null ? null : Center(child: center),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSegment> segments;
  final double strokeWidth;
  final Color trackColor;
  final double progress;

  _DonutPainter({
    required this.segments,
    required this.strokeWidth,
    required this.trackColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = trackColor);

    final total = segments.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) return;

    final visible = segments.where((s) => s.value > 0).toList();
    // Small gap between segments, only when there is more than one.
    final gap = visible.length > 1 ? 0.035 : 0.0;
    var start = -math.pi / 2;
    for (final segment in visible) {
      final sweep = (segment.value / total) * math.pi * 2 * progress;
      final drawn = math.max(0.0, sweep - gap);
      if (drawn > 0) {
        canvas.drawArc(rect, start + gap / 2, drawn, false, paint..color = segment.color);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress ||
      old.segments != segments ||
      old.strokeWidth != strokeWidth ||
      old.trackColor != trackColor;
}
