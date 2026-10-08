import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:open_bitcoin_tracker/api/price_data.dart';
import 'package:open_bitcoin_tracker/api/price_series.dart';
import 'package:open_bitcoin_tracker/data/app_enums.dart';
import 'package:open_bitcoin_tracker/screens/home/header/chart_spot_cache.dart';
import 'package:open_bitcoin_tracker/state/chart_series_projector.dart';

void main() {
  test(
    'live ticks reuse every historical spot and preserve exact coordinates',
    () {
      final base = ImmutablePriceSeries([
        const PricePoint(1, 100),
        const PricePoint(2, 0),
      ]);
      final cache = ChartSpotCache();
      final (firstLinear, firstLog) = cache.compute(
        LivePriceSeries(base, const PricePoint(3, 200)),
      );
      final (nextLinear, nextLog) = cache.compute(
        LivePriceSeries(base, const PricePoint(4, 300)),
      );
      expect(identical(firstLinear[0], nextLinear[0]), isTrue);
      expect(identical(firstLog[0], nextLog[0]), isTrue);
      expect(nextLinear.map((p) => (p.x, p.y)), [
        (1.0, 100.0),
        (2.0, 0.0),
        (4.0, 300.0),
      ]);
      expect(nextLog.first.y, math.log(100) / math.ln10);
      expect(nextLog[1].y, 0);
      expect(nextLog.last.y, math.log(300) / math.ln10);
      expect(() => nextLinear.clear(), throwsUnsupportedError);
    },
  );

  test(
    'projector shares immutable history between live ticks and invalidates on FX fallback changes',
    () {
      final projector = ChartSeriesProjector();
      final series = [const HistoryPoint(1, 100), const HistoryPoint(2, 200)];
      List<PricePoint> project(double price, double fx) =>
          projector.convertedSeriesWithLive(
            series: series,
            currency: Currency.eur,
            usdToCurrencyFallback: fx,
            livePrice: price,
          );
      final first = project(300, 0.9) as LivePriceSeries;
      final next = project(400, 0.9) as LivePriceSeries;
      expect(identical(first.base, next.base), isTrue);
      expect(identical(next, project(400, 0.9)), isTrue);
      expect(next.base.map((p) => p.price), [90, 180]);
      expect(
        identical(next.base, (project(400, 0.8) as LivePriceSeries).base),
        isFalse,
      );
      expect(() => next[0] = const PricePoint(0, 0), throwsUnsupportedError);
    },
  );
}
