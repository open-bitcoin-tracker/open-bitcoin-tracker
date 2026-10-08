import 'dart:collection';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';

import '../../../api/price_data.dart';
import '../../../api/price_series.dart';

/// Keeps historical chart geometry intact when only the live tail changes.
class ChartSpotCache {
  List<PricePoint>? _base;
  List<FlSpot> _linear = const [];
  List<FlSpot> _logarithmic = const [];

  (List<FlSpot>, List<FlSpot>) compute(List<PricePoint> data) {
    final base = data is LivePriceSeries ? data.base : data;
    if (!identical(base, _base)) {
      _base = base;
      _linear = List.unmodifiable([
        for (final p in base) FlSpot(p.t.toDouble(), p.price),
      ]);
      _logarithmic = List.unmodifiable([for (final p in base) _logSpot(p)]);
    }
    if (data is LivePriceSeries) {
      return (
        _SpotTail(_linear, FlSpot(data.tail.t.toDouble(), data.tail.price)),
        _SpotTail(_logarithmic, _logSpot(data.tail)),
      );
    }
    return (_linear, _logarithmic);
  }

  FlSpot _logSpot(PricePoint p) => FlSpot(
    p.t.toDouble(),
    p.price > 0 ? math.log(p.price) / math.ln10 : p.price,
  );
}

class _SpotTail extends ListBase<FlSpot> {
  _SpotTail(this._base, this._tail);
  final List<FlSpot> _base;
  final FlSpot _tail;
  @override
  int get length => _base.length + 1;
  @override
  FlSpot operator [](int index) {
    RangeError.checkValidIndex(index, this);
    return index == _base.length ? _tail : _base[index];
  }

  @override
  set length(int value) => throw UnsupportedError('Immutable chart geometry');
  @override
  void operator []=(int index, FlSpot value) =>
      throw UnsupportedError('Immutable chart geometry');
}
