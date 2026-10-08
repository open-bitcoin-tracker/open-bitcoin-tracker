import '../api/price_data.dart';
import '../api/price_series.dart';
import '../data/app_enums.dart';
import '../data/fx_history.dart';

/// Pure chart derivation with stable memo identities between data changes.
class ChartSeriesProjector {
  FxHistory? fxHistory;
  List<HistoryPoint> allHistory = const [];
  // Separate memo slots for the active window and all-history curve. The home screen renders both an
  // active-range series and the full all-history curve in the same frame, so a
  // single shared cache would thrash; one slot per use site.
  final _FxConvertMemo _convertedSeriesMemo = _FxConvertMemo();
  final _FxConvertMemo _convertedAllHistoryMemo = _FxConvertMemo();

  /// Returns [series] converted into [currency], one point per input point.
  /// Each historical point is converted by its own day's FX rate when
  /// [fxHistory] is available, falling back to the scalar
  /// [usdToCurrencyFallback] (live USD→fiat ratio) while it isn't.
  ///
  /// Result is memoized by series identity, currency, FX object identity, and
  /// (in the fallback path) the scalar rate. Re-fetching from the cache hands
  /// back the same list object, so callers can use `identical(...)` to
  /// short-circuit downstream work.
  List<PricePoint> convertedSeries({
    required List<HistoryPoint> series,
    required Currency currency,
    required double usdToCurrencyFallback,
  }) => _convertedSeriesMemo.compute(
    series: series,
    currency: currency,
    fxHistory: fxHistory,
    usdToCurrencyFallback: usdToCurrencyFallback,
  );

  /// Same as [convertedSeries] but with a separate cache slot. Used for the
  /// full all-history curve that the long-range chart "camera zooms" over.
  List<PricePoint> convertedAllHistory({
    required Currency currency,
    required double usdToCurrencyFallback,
  }) => _convertedAllHistoryMemo.compute(
    series: allHistory,
    currency: currency,
    fxHistory: fxHistory,
    usdToCurrencyFallback: usdToCurrencyFallback,
  );

  // The live "now" point is appended in a second memo layer rather than inside
  // the FX memo so the FX cache doesn't invalidate on every live tick — and so
  // the appended list itself keeps its identity until the base series or the
  // live price actually changes. AreaChart's identical() spot cache depends on
  // that stability.
  final _LiveAppendMemo _seriesWithLiveMemo = _LiveAppendMemo();
  final _LiveAppendMemo _allHistoryWithLiveMemo = _LiveAppendMemo();

  /// [convertedSeries] with the live price appended as a trailing "now" point.
  /// Returns the bare converted series when [livePrice] is not positive.
  List<PricePoint> convertedSeriesWithLive({
    required List<HistoryPoint> series,
    required Currency currency,
    required double usdToCurrencyFallback,
    required double livePrice,
  }) {
    final base = convertedSeries(
      series: series,
      currency: currency,
      usdToCurrencyFallback: usdToCurrencyFallback,
    );
    if (livePrice <= 0) return base;
    return _seriesWithLiveMemo.compute(base, livePrice);
  }

  /// [convertedAllHistory] with the live price appended as a trailing "now"
  /// point. Returns the bare converted series when [livePrice] is not positive.
  List<PricePoint> convertedAllHistoryWithLive({
    required Currency currency,
    required double usdToCurrencyFallback,
    required double livePrice,
  }) {
    final base = convertedAllHistory(
      currency: currency,
      usdToCurrencyFallback: usdToCurrencyFallback,
    );
    if (livePrice <= 0) return base;
    return _allHistoryWithLiveMemo.compute(base, livePrice);
  }
}

/// One-entry memo around appending the live "now" point to a converted
/// series. Keyed on (base identity, live price): as long as neither changes,
/// callers get back the same list object — including its original timestamp,
/// which is fine because a rebuild without a price change has nothing new to
/// plot at the series tail anyway.
class _LiveAppendMemo {
  List<PricePoint>? _base;
  double _livePrice = double.nan;
  ImmutablePriceSeries? _immutableBase;
  List<PricePoint> _result = const [];

  List<PricePoint> compute(List<PricePoint> base, double livePrice) {
    if (identical(_base, base) && _livePrice == livePrice) return _result;
    if (!identical(_base, base)) {
      _immutableBase = base is ImmutablePriceSeries
          ? base
          : ImmutablePriceSeries(base);
    }
    _base = base;
    _livePrice = livePrice;
    _result = LivePriceSeries(
      _immutableBase!,
      PricePoint(DateTime.now().millisecondsSinceEpoch, livePrice),
    );
    return _result;
  }
}

/// One-entry memo around the USD→fiat conversion of a USD-priced history
/// series. Keyed on (series identity, currency, FX-history identity); when FX
/// history is null the scalar fallback rate is also part of the key.
class _FxConvertMemo {
  List<HistoryPoint>? _series;
  Currency? _currency;
  FxHistory? _fxHistory;
  double _usdToCurrency = double.nan;
  List<PricePoint> _converted = const [];

  List<PricePoint> compute({
    required List<HistoryPoint> series,
    required Currency currency,
    required FxHistory? fxHistory,
    required double usdToCurrencyFallback,
  }) {
    final hit =
        identical(_series, series) &&
        _currency == currency &&
        identical(_fxHistory, fxHistory) &&
        (fxHistory != null || _usdToCurrency == usdToCurrencyFallback);
    if (hit) return _converted;

    _series = series;
    _currency = currency;
    _fxHistory = fxHistory;
    _usdToCurrency = usdToCurrencyFallback;
    _converted = ImmutablePriceSeries([
      for (final p in series)
        PricePoint(
          p.timeMs,
          p.priceUsd *
              (fxHistory != null
                  ? fxHistory.rateAt(currency, p.timeMs)
                  : usdToCurrencyFallback),
        ),
    ]);
    return _converted;
  }
}
