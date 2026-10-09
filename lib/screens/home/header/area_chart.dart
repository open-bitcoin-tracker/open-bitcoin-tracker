import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../api/api.dart';
import 'chart_spot_cache.dart';
import 'chart_motion.dart';

class AreaChart extends StatefulWidget {
  const AreaChart({
    super.key,
    required this.data,
    required this.windowStartMs,
    required this.windowEndMs,
    required this.color,
    required this.logScale,
    required this.rangeKey,
    required this.onHover,
    this.seriesKey = 'daily',
    this.selectionEnabled = true,
  });

  final List<PricePoint> data;
  final int windowStartMs;
  final int windowEndMs;
  final Color color;
  final bool logScale;
  // Opaque identity used only to trigger the zoom tween when the caller
  // switches what time window is being displayed (e.g. 1M → 3M on the price
  // card). Compared via `!=` in
  // didUpdateWidget; the chart never reads any semantics off it.
  final Object rangeKey;
  final ValueChanged<PricePoint?> onHover;
  final Object seriesKey;
  final bool selectionEnabled;

  @override
  State<AreaChart> createState() => _AreaChartState();
}

class _AreaChartState extends State<AreaChart> with TickerProviderStateMixin {
  final ChartSpotCache _spotCache = ChartSpotCache();
  List<PricePoint>? _spotsForData;
  late List<FlSpot> _spots;
  List<FlSpot>? _linearSpots;
  List<FlSpot>? _logSpots;
  late final ChartMotion _motion = ChartMotion(this);
  bool _reduceMotion = false;

  // Index into _spots/data of the point under the user's finger, or null when
  // not touching. Drives both the visual indicator (showingIndicators) and
  // the onHover callback. Updated from raw pointer events, not fl_chart's
  // touch pipeline — see the comment in build().
  int? _touchedIndex;

  // Drives the orange ripple that radiates out of the selected-point circle.
  // Repeats for as long as a point is touched; stopped (and reset) on release
  // so it isn't burning frames while idle.
  // Duration of one ring's full 0→1 expansion. Set on the controller in
  // _handleTouch (not only here) so hot reload picks up tweaks — a late final
  // field initializer runs once and won't re-read a changed constant.
  static const Duration _rippleDuration = Duration(milliseconds: 4200);

  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: _rippleDuration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _motion.finish();
      _ripple.stop();
      _ripple.reset();
    }
    _updateMotion();
  }

  @override
  void dispose() {
    _motion.dispose();
    _ripple.dispose();
    super.dispose();
  }

  void _rebuildCache() {
    final data = widget.data;
    final (linear, logarithmic) = _spotCache.compute(data);
    _linearSpots = linear;
    _logSpots = logarithmic;
    _spotsForData = data;
    _spots = widget.logScale ? _logSpots! : _linearSpots!;
  }

  // Min/max y over spots whose x falls inside [startX, endX], with 5% padding.
  // Spots are sorted by x, so we can scan linearly; lists are small enough.
  (double, double) _windowYFit(List<FlSpot> spots, double startX, double endX) {
    double? minY, maxY;
    for (final s in spots) {
      if (s.x < startX) continue;
      if (s.x > endX) break;
      if (minY == null || s.y < minY) minY = s.y;
      if (maxY == null || s.y > maxY) maxY = s.y;
    }
    if (minY == null || maxY == null) {
      minY = spots.isNotEmpty ? spots.first.y : 0.0;
      maxY = spots.isNotEmpty ? spots.first.y : 1.0;
    }
    if (minY == maxY) maxY = minY + 1;
    final pad = (maxY - minY) * 0.05;
    return (minY - pad, maxY + pad);
  }

  // Maps a touch position to the nearest data point and shows the indicator
  // there. Pixel→value mapping mirrors fl_chart's: linear over [minX, maxX]
  // across the full widget width (all titles/borders are hidden, so the plot
  // area is the whole box).
  void _handleTouch(Offset localPosition) {
    if (_motion.animating ||
        !widget.selectionEnabled ||
        _motion.scene?.rangeKey != widget.rangeKey) {
      _clearTouch();
      return;
    }
    final width = context.size?.width ?? 0;
    if (width <= 0 || _spots.isEmpty) return;
    final x =
        widget.windowStartMs +
        (localPosition.dx / width) *
            (widget.windowEndMs - widget.windowStartMs);
    // Binary search for the first spot at or right of x; spots are sorted.
    var lo = 0;
    var hi = _spots.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_spots[mid].x < x) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final i = (lo > 0 && x - _spots[lo - 1].x < _spots[lo].x - x) ? lo - 1 : lo;
    if (!_ripple.isAnimating) {
      _ripple.duration = _rippleDuration;
      if (!_reduceMotion) _ripple.repeat();
    }
    if (i == _touchedIndex) return;
    setState(() => _touchedIndex = i);
    if (i < widget.data.length) widget.onHover(widget.data[i]);
  }

  void _clearTouch() {
    _ripple.stop();
    _ripple.reset();
    if (_touchedIndex == null) return;
    setState(() => _touchedIndex = null);
    widget.onHover(null);
  }

  void _updateMotion() {
    if (!identical(_spotsForData, widget.data) || _linearSpots == null) {
      _rebuildCache();
    }
    // Empty incoming ranges leave the outgoing scene intact while loading.
    if (widget.data.length < 2) return;
    _spots = widget.logScale ? _logSpots! : _linearSpots!;
    final start = widget.windowStartMs.toDouble();
    final end = widget.windowEndMs.toDouble();
    final (bottom, top) = _windowYFit(_spots, start, end);
    _motion.update(
      ChartScene(
        spots: _spots,
        camera: ChartCamera(start, end, bottom, top),
        logScale: widget.logScale,
        rangeKey: widget.rangeKey,
        seriesKey: widget.seriesKey,
      ),
      immediate: _reduceMotion,
    );
  }

  @override
  void didUpdateWidget(covariant AreaChart old) {
    super.didUpdateWidget(old);
    if (old.rangeKey != widget.rangeKey ||
        old.logScale != widget.logScale ||
        !widget.selectionEnabled) {
      _clearTouch();
    }
    _updateMotion();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.color;

    // Scrubbing is deliberately NOT done through fl_chart's touch pipeline.
    // Its internal PanGestureRecognizer needs kPanSlop (~2× kTouchSlop) of
    // travel to claim the gesture, so any single-axis drag recognizer in the
    // arena — an ancestor scrollable, or our own spoilers below — beats it to
    // the claim and fl_chart gets a cancel: the indicator appeared on
    // touch-down and then vanished the moment the finger actually moved.
    //
    // Instead, the Listener reads raw pointer events (which bypass the
    // gesture arena entirely, so nobody can steal them), maps the finger to
    // the nearest data point, and drives the indicator via showingIndicators.
    // The no-op drag recognizer pair below stays purely as an arena spoiler:
    // it claims drags that start on the chart so ancestor scrollables (the
    // vertical CustomScrollView) don't scroll the page while the user scrubs.
    // fl_chart itself registers no recognizers here because lineTouchData
    // has enabled: false and no touchCallback.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _handleTouch(e.localPosition),
      onPointerMove: (e) => _handleTouch(e.localPosition),
      onPointerUp: (_) => _clearTouch(),
      onPointerCancel: (_) => _clearTouch(),
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: <Type, GestureRecognizerFactory>{
          VerticalDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                VerticalDragGestureRecognizer
              >(() => VerticalDragGestureRecognizer(), (instance) {
                // No callbacks: just an arena spoiler against ancestor vertical
                // scrolls that would otherwise grab pointers over the chart.
              }),
          HorizontalDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                HorizontalDragGestureRecognizer
              >(() => HorizontalDragGestureRecognizer(), (instance) {
                // No callbacks: arena spoiler against any ancestor horizontal
                // scroll.
              }),
        },
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) {
            final scene = _motion.scene;
            if (scene == null) return const SizedBox.shrink();
            final camera = scene.camera;
            final minX = camera.start;
            final maxX = camera.end;
            final minY = camera.bottom;
            final maxY = camera.top;
            final spots = scene.spots;
            // Value-space coordinates of the dot fl_chart is painting for the
            // touched point, used to position the ripple overlay. Null when not
            // scrubbing or the index is out of range for the current curve.
            final selectedIndex = _motion.animating || !widget.selectionEnabled
                ? null
                : _touchedIndex;
            final touched = switch (selectedIndex) {
              final i? when i < spots.length => spots[i],
              _ => null,
            };
            final chart = LineChart(
              duration: Duration.zero,
              LineChartData(
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineTouchData: LineTouchData(
                  // Touch handling is done by the Listener above; fl_chart only
                  // paints the indicator for the showingIndicators we set on the bar.
                  enabled: false,
                  handleBuiltInTouches: false,
                  getTouchLineStart: (_, _) => double.negativeInfinity,
                  getTouchLineEnd: (_, _) => double.infinity,
                  getTouchedSpotIndicator: (_, indicators) => [
                    for (final _ in indicators)
                      TouchedSpotIndicatorData(
                        FlLine(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              cs.onSurfaceVariant.withValues(alpha: 0),
                              cs.onSurfaceVariant,
                              cs.onSurfaceVariant,
                              cs.onSurfaceVariant.withValues(alpha: 0),
                            ],
                            stops: const [0.0, 0.15, 0.85, 1.0],
                          ),
                          strokeWidth: 1,
                          dashArray: const [4, 4],
                        ),
                        FlDotData(
                          show: true,
                          getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                            radius: 5,
                            color: color,
                            strokeWidth: 1.5,
                            strokeColor: cs.onSurface,
                          ),
                        ),
                      ),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    showingIndicators: switch (selectedIndex) {
                      final i? when i < spots.length => [i],
                      _ => const [],
                    },
                    isCurved: false,
                    color: color,
                    barWidth: 1.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.18),
                          color.withValues(alpha: 0.12),
                          color.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            );
            // The ripple needs both the value→pixel mapping (this frame's
            // min/max, the box size) and a clock independent of the zoom tween,
            // so it rides on _ripple via its own AnimatedBuilder and paints on
            // top of the chart. RepaintBoundary keeps the pulsing repaints from
            // dirtying the chart layer.
            return Opacity(
              opacity: _motion.opacity,
              child: ClipRect(
                clipper: _PlotClipper(MediaQuery.sizeOf(context).height),
                child: Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    chart,
                    if (touched != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _ripple,
                              builder: (context, _) => CustomPaint(
                                painter: _RipplePainter(
                                  spotX: touched.x,
                                  spotY: touched.y,
                                  minX: minX,
                                  maxX: maxX,
                                  minY: minY,
                                  maxY: maxY,
                                  progress: _ripple.value,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Clip horizontally and below the plot, while allowing the curve to rise
// behind the price. The header clips that overflow at its own outer boundary.
class _PlotClipper extends CustomClipper<Rect> {
  const _PlotClipper(this.screenHeight);
  final double screenHeight;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, -screenHeight, size.width, size.height);

  @override
  bool shouldReclip(_PlotClipper oldClipper) =>
      oldClipper.screenHeight != screenHeight;
}

// Concentric orange rings expanding out of the selected point on the chart.
// progress is one 0→1 sweep of the repeating ripple controller; we stagger a
// few rings across that phase so there's always a wave mid-flight.
class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.spotX,
    required this.spotY,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.progress,
    required this.color,
  });

  // Value-space position of the dot and the visible value window, used to map
  // the spot to a pixel offset the same way fl_chart lays out the plot area
  // (the whole box, since all titles/borders are hidden).
  final double spotX;
  final double spotY;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final double progress;
  final Color color;

  static const int _ringCount = 3;
  static const double _maxRadius = 26;
  // Matches the FlDotCirclePainter radius the chart paints for the selected
  // point. Rings are clipped outside this disc so none of the ripple shows on
  // top of the black dot.
  static const double _dotRadius = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final spanX = maxX - minX;
    final spanY = maxY - minY;
    if (spanX == 0 || spanY == 0) return;
    final dx = (spotX - minX) / spanX * size.width;
    // y is inverted: high value sits near the top of the box.
    final dy = (1 - (spotY - minY) / spanY) * size.height;
    final center = Offset(dx, dy);

    // Clip out the dot so the rings only ever appear around it, never over it.
    canvas.save();
    canvas.clipPath(
      Path()
        ..addRect(Offset.zero & size)
        ..addOval(Rect.fromCircle(center: center, radius: _dotRadius))
        ..fillType = PathFillType.evenOdd,
    );

    for (var i = 0; i < _ringCount; i++) {
      // Each ring is offset in phase so they trail one another; wrap into 0..1.
      final t = (progress + i / _ringCount) % 1.0;
      final radius = t * _maxRadius;
      // Fade out as the ring grows; ease the alpha so it lingers small and
      // dies off gently at the rim.
      final alpha = (1 - t) * (1 - t);
      if (alpha <= 0.01) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * (1 - t) + 0.5
        ..color = color.withValues(alpha: alpha * 0.55);
      canvas.drawCircle(center, radius, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.progress != progress ||
      old.spotX != spotX ||
      old.spotY != spotY ||
      old.minX != minX ||
      old.maxX != maxX ||
      old.minY != minY ||
      old.maxY != maxY ||
      old.color != color;
}
