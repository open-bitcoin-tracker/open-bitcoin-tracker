import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

@immutable
class ChartCamera {
  const ChartCamera(this.start, this.end, this.bottom, this.top);

  final double start, end, bottom, top;
  double get span => end - start;

  ChartCamera lerp(ChartCamera to, double t) => ChartCamera(
    start + (to.start - start) * t,
    end + (to.end - end) * t,
    bottom + (to.bottom - bottom) * t,
    top + (to.top - top) * t,
  );
}

@immutable
class ChartScene {
  const ChartScene({
    required this.spots,
    required this.camera,
    required this.logScale,
    required this.rangeKey,
    required this.seriesKey,
  });

  final List<FlSpot> spots;
  final ChartCamera camera;
  final bool logScale;
  final Object rangeKey, seriesKey;
}

/// Camera motion only: held/merged samples never enter the price data model.
/// Controllers use Flutter's native clock and curves, matching the web chart.
class ChartMotion extends ChangeNotifier {
  ChartMotion(TickerProvider vsync) {
    _zoom = AnimationController(vsync: vsync, duration: zoomDuration)
      ..addListener(() {
        // The controller can reach value 1 one tick before its completed
        // status (floating-point clock rounding). Adopt exact target samples
        // on that frame, alongside the camera reaching its destination.
        if (_zoom.value == 1) _clearZoom();
        notifyListeners();
      });
    _fade = AnimationController(vsync: vsync, duration: fadeDuration)
      ..addListener(() {
        if (_fade.value == 1) {
          if (_fadingOut == true) {
            _settled = _target;
            _startFade(false, 0);
          } else {
            _fadingOut = null;
            _settled = _target;
          }
        }
        notifyListeners();
      });
  }

  static const zoomDuration = Duration(milliseconds: 450);
  static const fadeDuration = Duration(milliseconds: 150);
  late final AnimationController _zoom, _fade;
  ChartScene? _target, _settled;
  ChartCamera? _from;
  List<FlSpot>? _held;
  Object? _heldSeriesKey;
  bool? _fadingOut;
  double _fadeFrom = 1;

  bool get animating => _from != null || _fadingOut != null;
  double get opacity => _fadingOut == null
      ? 1
      : _fadeFrom +
            ((_fadingOut! ? 0 : 1) - _fadeFrom) *
                Curves.easeInOut.transform(_fade.value);

  ChartScene? get scene {
    final target = _target;
    if (target == null) return null;
    if (_fadingOut != null) return _fadingOut! ? _settled : target;
    final from = _from;
    if (from == null) return target;
    return ChartScene(
      spots: _held ?? target.spots,
      camera: from.lerp(
        target.camera,
        Curves.easeInOutCubic.transform(_zoom.value),
      ),
      logScale: target.logScale,
      rangeKey: target.rangeKey,
      seriesKey: _heldSeriesKey ?? target.seriesKey,
    );
  }

  void update(ChartScene target, {bool immediate = false}) {
    final displayed = scene;
    final previous = _target;
    final displayedOpacity = opacity;
    _target = target;
    if (displayed == null || immediate) {
      finish();
    } else if (previous?.logScale != target.logScale) {
      _zoom.stop();
      _clearZoom();
      _settled = displayed;
      _startFade(displayed.logScale != target.logScale, displayedOpacity);
    } else if (previous?.rangeKey != target.rangeKey && _fadingOut == null) {
      final zoomingIn = target.camera.span < displayed.camera.span;
      final changingSeries = displayed.seriesKey != target.seriesKey;
      _from = displayed.camera;
      _held = zoomingIn || changingSeries
          ? (!zoomingIn && changingSeries
                ? _zoomOutSpots(displayed.spots, target.spots)
                : displayed.spots)
          : null;
      _heldSeriesKey = _held == null ? null : displayed.seriesKey;
      _zoom.forward(from: 0);
    }
    // Same-range ticks can update the destination, but never reset the clock.
  }

  List<FlSpot> _zoomOutSpots(List<FlSpot> outgoing, List<FlSpot> incoming) {
    final start = outgoing.first.x;
    final end = outgoing.last.x;
    return List.unmodifiable([
      ...incoming.where((spot) => spot.x < start),
      ...outgoing,
      ...incoming.where((spot) => spot.x > end),
    ]);
  }

  void _startFade(bool out, double from) {
    _fadingOut = out;
    _fadeFrom = from;
    _fade.duration = Duration(
      microseconds: (fadeDuration.inMicroseconds * (out ? from : 1 - from))
          .round(),
    );
    _fade.forward(from: 0);
  }

  void _clearZoom() {
    _from = null;
    _held = null;
    _heldSeriesKey = null;
  }

  void finish() {
    _zoom.stop();
    _fade.stop();
    _clearZoom();
    _fadingOut = null;
    _settled = _target;
  }

  @override
  void dispose() {
    _zoom.dispose();
    _fade.dispose();
    super.dispose();
  }
}
