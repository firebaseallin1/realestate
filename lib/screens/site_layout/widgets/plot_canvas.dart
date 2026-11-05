import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/site.dart';

/// Colors for plot status on the layout and in the plot list.
Color plotStatusColor(PlotStatus status) {
  switch (status) {
    case PlotStatus.available:
      return AppColors.success;
    case PlotStatus.booked:
      return AppColors.accentGold;
    case PlotStatus.sold:
      return AppColors.brandDark;
  }
}

/// PlotCanvas is the mapped view of a site: the site map image (or graph
/// paper when there is none) with every plot drawn on top, colored by
/// status and labelled with its number, size and facing arrow.
///
/// While [drawing] is on, dragging draws a new plot box and reports it
/// through [onDrawn]; otherwise tapping a plot calls [onPlotTap].
/// The canvas keeps a fixed 4:3 shape so plot positions stay put.
class PlotCanvas extends StatefulWidget {
  final Site site;
  final bool drawing;
  final ValueChanged<Rect> onDrawn;
  final ValueChanged<Plot> onPlotTap;

  const PlotCanvas({
    super.key,
    required this.site,
    required this.drawing,
    required this.onDrawn,
    required this.onPlotTap,
  });

  static const double aspectRatio = 4 / 3;

  @override
  State<PlotCanvas> createState() => _PlotCanvasState();
}

class _PlotCanvasState extends State<PlotCanvas> {
  /// Smallest box (as a share of the canvas side) that counts as a plot.
  static const double _minSide = 0.02;

  Offset? _dragStart;
  Offset? _dragNow;

  Offset _normalize(Offset local, Size size) => Offset(
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0),
      );

  Rect? get _dragRect =>
      _dragStart == null || _dragNow == null ? null : Rect.fromPoints(_dragStart!, _dragNow!);

  void _endDrag() {
    final rect = _dragRect;
    setState(() {
      _dragStart = null;
      _dragNow = null;
    });
    if (rect != null && rect.width >= _minSide && rect.height >= _minSide) {
      widget.onDrawn(rect);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: PlotCanvas.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final map = widget.site.siteMap;

            return Stack(
              children: [
                // Background: site map or graph paper
                Positioned.fill(
                  child: map != null && map.isImage
                      ? ColoredBox(
                          color: AppColors.pureWhite,
                          child: Image.memory(
                            map.bytes,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const _GraphPaper(),
                          ),
                        )
                      : const _GraphPaper(),
                ),

                // Plots
                for (final plot in widget.site.plots)
                  Positioned(
                    key: ValueKey('plot-${plot.id}'),
                    left: plot.rect.left * size.width,
                    top: plot.rect.top * size.height,
                    width: plot.rect.width * size.width,
                    height: plot.rect.height * size.height,
                    child: _PlotBox(
                      plot: plot,
                      onTap: widget.drawing ? null : () => widget.onPlotTap(plot),
                    ),
                  ),

                // Box being drawn
                if (_dragRect case final rect?)
                  Positioned(
                    left: rect.left * size.width,
                    top: rect.top * size.height,
                    width: rect.width * size.width,
                    height: rect.height * size.height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.18),
                        border: Border.all(color: AppColors.primary, width: 2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                const Positioned(top: 10, right: 10, child: _NorthArrow()),

                // Drawing layer on top while drawing is on
                if (widget.drawing)
                  Positioned.fill(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.precise,
                      child: GestureDetector(
                        key: const ValueKey('plot-draw-layer'),
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (d) => setState(() {
                          _dragStart = _normalize(d.localPosition, size);
                          _dragNow = _dragStart;
                        }),
                        onPanUpdate: (d) => setState(() => _dragNow = _normalize(d.localPosition, size)),
                        onPanEnd: (_) => _endDrag(),
                        onPanCancel: () => setState(() {
                          _dragStart = null;
                          _dragNow = null;
                        }),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlotBox extends StatelessWidget {
  final Plot plot;
  final VoidCallback? onTap;

  const _PlotBox({required this.plot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = plotStatusColor(plot.status);

    return Tooltip(
      message: 'Plot ${plot.number} • ${plot.sizeLabel} • ${plot.facing.label} facing • ${plot.status.label}',
      child: Material(
        color: color.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: BorderSide(color: color, width: 1.6),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(3),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    plot.number,
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    plot.sizeLabel,
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      color: AppColors.textPrimaryLight,
                      height: 1.1,
                    ),
                  ),
                  Transform.rotate(
                    angle: plot.facing.degrees * math.pi / 180,
                    child: Icon(Icons.navigation_rounded, size: 14, color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Light grid used when a site has no map image.
class _GraphPaper extends StatelessWidget {
  const _GraphPaper();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter(), child: const SizedBox.expand());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.pureWhite);
    final minor = Paint()
      ..color = AppColors.mint.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = AppColors.sageSoft.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    final step = size.width / 40;
    var i = 0;
    for (double x = 0; x <= size.width; x += step, i++) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), i % 5 == 0 ? major : minor);
    }
    i = 0;
    for (double y = 0; y <= size.height; y += step, i++) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), i % 5 == 0 ? major : minor);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small compass so facing arrows read correctly (north is up).
class _NorthArrow extends StatelessWidget {
  const _NorthArrow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.pureWhite.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.navigation_rounded, size: 14, color: AppColors.brandDark),
          Text(
            'N',
            style: AppTypography.caption.copyWith(
              fontSize: 9,
              height: 1,
              color: AppColors.brandDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
