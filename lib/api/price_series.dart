import 'dart:collection';

import 'price_data.dart';

/// An immutable historical curve, snapshotted once when its source changes.
class ImmutablePriceSeries extends ListBase<PricePoint> {
  ImmutablePriceSeries(Iterable<PricePoint> points)
    : _points = List.unmodifiable(points);
  final List<PricePoint> _points;
  @override
  int get length => _points.length;
  @override
  PricePoint operator [](int index) => _points[index];
  @override
  set length(int value) => throw UnsupportedError('Immutable price series');
  @override
  void operator []=(int index, PricePoint value) =>
      throw UnsupportedError('Immutable price series');
}

/// Shares immutable history between ticks; only the trailing live point changes.
class LivePriceSeries extends ListBase<PricePoint> {
  LivePriceSeries(this.base, this.tail);
  final ImmutablePriceSeries base;
  final PricePoint tail;
  @override
  int get length => base.length + 1;
  @override
  PricePoint operator [](int index) {
    RangeError.checkValidIndex(index, this);
    return index == base.length ? tail : base[index];
  }

  @override
  set length(int value) => throw UnsupportedError('Immutable price series');
  @override
  void operator []=(int index, PricePoint value) =>
      throw UnsupportedError('Immutable price series');
}
