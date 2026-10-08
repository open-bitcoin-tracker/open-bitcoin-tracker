import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/kraken_ohlc_client.dart';
import '../api/ohlc_window.dart';
import '../api/price_data.dart';
import 'app_enums.dart';
import 'btc_history.dart';
import 'btc_history_cache.dart';
import 'fx_history.dart';

/// Owns market history, offline fallback, and concurrent request lifetimes.
class MarketHistoryRepository extends ChangeNotifier {
  MarketHistoryRepository({
    required KrakenOhlcClient ohlc,
    required BtcHistoryCache cache,
    Future<List<HistoryPoint>> Function()? loadBundled,
    Future<FxHistory> Function()? loadFx,
    DateTime Function()? now,
  }) : _ohlc = ohlc,
       _cache = cache,
       _loadBundled = loadBundled ?? loadBundledHistory,
       _loadFx = loadFx ?? loadBundledFxHistory,
       _now = now ?? DateTime.now;

  final KrakenOhlcClient _ohlc;
  final BtcHistoryCache _cache;
  final Future<List<HistoryPoint>> Function() _loadBundled;
  final Future<FxHistory> Function() _loadFx;
  final DateTime Function() _now;
  List<HistoryPoint> _allHistory = const [];
  FxHistory? _fxHistory;
  final Map<BtcRange, List<HistoryPoint>> _intraday = {};
  final Set<BtcRange> _failed = {};
  final Map<BtcRange, Future<void>> _pending = {};
  final Map<BtcRange, int> _loading = {};
  Future<void>? _historyPending;
  Future<void>? _fxPending;
  DateTime? lastHistoryFetchedAt;
  DateTime? lastIntradayFetchedAt;
  int _generation = 0;
  int _requestId = 0;
  bool _disposed = false;

  List<HistoryPoint> get allHistory => _allHistory;
  FxHistory? get fxHistory => _fxHistory;
  List<HistoryPoint>? intradayFor(BtcRange range) => _intraday[range];
  bool isIntradayLoading(BtcRange range) => _loading.containsKey(range);
  bool didIntradayFail(BtcRange range) => _failed.contains(range);

  bool isIntradayStale(BtcRange range) {
    final window = OhlcWindow.forRange(range);
    if (window == null) return false;
    final series = _intraday[range];
    if (series == null || series.isEmpty) return true;
    final newest = DateTime.fromMillisecondsSinceEpoch(series.last.timeMs);
    return _now().difference(newest) > window.candleInterval * 1.5;
  }

  Future<void> loadFxHistory() => _fxPending ??= _loadFxHistory();

  Future<void> _loadFxHistory() async {
    try {
      final fx = await _loadFx();
      if (_disposed) return;
      _fxHistory = fx;
      notifyListeners();
    } on Object catch (error) {
      // FX is optional: consumers retain their live-scalar fallback.
      if (kDebugMode) debugPrint('FX history unavailable: $error');
    }
  }

  Future<void> refreshHistory() {
    if (_disposed) return Future.value();
    return _historyPending ??= _fetchAllHistory().whenComplete(() {
      _historyPending = null;
    });
  }

  Future<void> _fetchAllHistory() async {
    var base = const <HistoryPoint>[];
    try {
      base = await _cache.load();
    } on Object catch (error) {
      if (kDebugMode) debugPrint('History cache unavailable: $error');
    }
    if (_disposed) return;
    if (base.isEmpty) {
      try {
        base = await _loadBundled();
      } on Object catch (error) {
        if (kDebugMode) debugPrint('Bundled history unavailable: $error');
      }
      if (_disposed) return;
    }
    if (base.isNotEmpty) {
      _allHistory = List.unmodifiable(base);
      notifyListeners();
    }
    final lastTs = base.isNotEmpty ? base.last.timeMs : 0;
    final daysGap = ((_now().millisecondsSinceEpoch - lastTs) / 86400000)
        .ceil()
        .clamp(0, 2000);
    final fetchDays = base.isEmpty ? 720 : (daysGap + 3).clamp(1, 720);
    final sinceTs = fetchDays >= 720
        ? null
        : (_now().millisecondsSinceEpoch ~/ 1000) - (fetchDays + 1) * 86400;
    final recent = await _ohlc.daily(sinceTs: sinceTs);
    if (_disposed || recent == null || recent.isEmpty) return;
    _allHistory = List.unmodifiable(_mergeByDay(base, recent));
    lastHistoryFetchedAt = _now();
    notifyListeners();
    try {
      await _cache.save(_allHistory);
    } on Object catch (error) {
      // A failed optional cache write must not discard usable in-memory data.
      if (kDebugMode) debugPrint('History cache write failed: $error');
    }
  }

  static List<HistoryPoint> _mergeByDay(
    List<HistoryPoint> base,
    List<HistoryPoint> recent,
  ) {
    const dayMs = 86400000;
    final byDay = <int, double>{};
    for (final p in recent) {
      byDay[(p.timeMs ~/ dayMs) * dayMs] = p.priceUsd;
    }
    for (final p in base) {
      byDay.putIfAbsent((p.timeMs ~/ dayMs) * dayMs, () => p.priceUsd);
    }
    final keys = byDay.keys.toList()..sort();
    return [for (final k in keys) HistoryPoint(k, byDay[k]!)];
  }

  Future<void> fetchIntraday(BtcRange range, {bool force = false}) {
    if (_disposed) return Future.value();
    final pending = _pending[range];
    if (pending != null) return pending;
    if (!force &&
        _intraday.containsKey(range) &&
        !_failed.contains(range) &&
        !isIntradayStale(range)) {
      return Future.value();
    }
    final weeks = range.weeks;
    if (!force && weeks != null) {
      final month = _intraday[BtcRange.m1];
      if (month != null &&
          !_failed.contains(BtcRange.m1) &&
          !isIntradayStale(BtcRange.m1)) {
        final take = OhlcWindow.forRange(range)!.takeLast!;
        _intraday[range] = List.unmodifiable(
          month.skip(month.length > take ? month.length - take : 0),
        );
        _failed.remove(range);
        notifyListeners();
        return Future.value();
      }
    }
    final request = ++_requestId;
    _loading[range] = request;
    // Schedule after registering the future so re-entrant consumers see it.
    late final Future<void> task;
    task =
        Future<void>.microtask(
          () => _fetchIntraday(range, _generation, request),
        ).whenComplete(() {
          if (identical(_pending[range], task)) _pending.remove(range);
        });
    _pending[range] = task;
    notifyListeners();
    return task;
  }

  Future<void> _fetchIntraday(
    BtcRange range,
    int generation,
    int request,
  ) async {
    try {
      if (_disposed ||
          generation != _generation ||
          _loading[range] != request) {
        return;
      }
      final points = await _ohlc.intraday(range);
      if (_disposed || generation != _generation) return;
      if (points == null) {
        _failed.add(range);
      } else {
        _intraday[range] = List.unmodifiable(points);
        lastIntradayFetchedAt = _now();
        _failed.remove(range);
        if (range == BtcRange.m1) {
          for (final r in btcRangeWeeks) {
            _intraday.remove(r);
          }
        }
      }
    } finally {
      if (!_disposed && _loading[range] == request) {
        _loading.remove(range);
        notifyListeners();
      }
    }
  }

  void invalidateIntraday() {
    _generation++;
    _pending.clear();
    _loading.clear();
    _intraday.clear();
    _failed.clear();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ohlc.close();
    super.dispose();
  }
}
