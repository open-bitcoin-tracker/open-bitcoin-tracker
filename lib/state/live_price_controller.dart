import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../api/tick_throttler.dart';
import '../api/kraken_ohlc_client.dart';
import '../api/kraken_stream_service.dart';
import '../api/price_data.dart';
import '../data/app_enums.dart';
import '../data/market_history_repository.dart';
import 'chart_series_projector.dart';
import '../data/btc_history_cache.dart';
import '../data/btc_rates_cache.dart';
import '../data/fx_history.dart';
import 'app_state_notifier.dart';

class LivePriceController extends ChangeNotifier with WidgetsBindingObserver {
  LivePriceController({
    required KrakenStreamService stream,
    required KrakenOhlcClient ohlc,
    required BtcRatesCache cache,
    required BtcHistoryCache historyCache,
    LivePriceCadence cadence = LivePriceCadence.s5,
    AppStateNotifier? app,
  }) : _stream = stream,
       _history = MarketHistoryRepository(ohlc: ohlc, cache: historyCache),
       _cache = cache,
       _app = app,
       _cadence = cadence,
       _rates = cache.load() {
    _history.addListener(notifyListeners);
    _throttler = TickThrottler(onFire: notifyListeners)
      ..interval = cadence.minInterval;
    // Mirror the cadence setting into the throttle policy without recreating
    // the controller: it outlives any individual settings change. Subscribed
    // here and released in dispose() so the listener never outlives us.
    _app?.addListener(_syncCadenceFromApp);
  }

  final KrakenStreamService _stream;
  final MarketHistoryRepository _history;
  final BtcRatesCache _cache;
  final AppStateNotifier? _app;

  void _syncCadenceFromApp() {
    cadence = _app!.livePriceCadence;
  }

  BtcRates _rates;
  // Tracked so resume-time invalidation can re-fetch the visible range without
  // the screen having to drive its own lifecycle observer.
  BtcRange? _activeIntradayRange;
  StreamSubscription<KrakenTick>? _streamSub;
  // Periodic auto-refresh for the 1D intraday series. Kraken's 15-min candles
  // mean a re-fetch more often than ~once a minute returns the same data; on
  // 1W/1M (1h candles) the value of polling is too low to be worth the round
  // trip, so we only arm this timer for 1D.
  Timer? _intradayAutoRefreshTimer;
  static const Duration _intradayAutoRefreshInterval = Duration(seconds: 60);
  bool _appBackgrounded = false;
  bool _disposed = false;
  // Debug-only screenshot mode. When on, incoming WS ticks are swallowed
  // before they touch `_rates`, so the displayed price freezes at whatever it
  // was when the mode was enabled. A frozen price never differs frame-to-frame,
  // so CurrentPrice's delta badge never fires — exactly the still, delta-free
  // state we want for marketing screenshots. The WS keeps streaming so leaving
  // the mode snaps straight back to a live price.
  bool _screenshotMode = false;
  LivePriceCadence _cadence;
  // Gates price-card repaints to at most one per `_cadence.minInterval`,
  // queueing one deferred fire so a tick suppressed by the gate isn't dropped.
  late final TickThrottler _throttler;
  // Updated on every accepted WS tick, so under live conditions this is
  // effectively "now". Kept around because the chart hover/badge code still
  // reads it via [lastFetchedAt].
  DateTime? _lastFetchedAt;
  // Skip back-to-back refreshes within this window so a quick foreground/
  // background flicker doesn't double-tap the API.
  static const Duration _resumeQuietWindow = Duration(seconds: 30);
  // Live ticks arrive about once a second, and persisting the rates cache
  // rewrites the whole prefs file each time. The cache only matters for the
  // first frame of the NEXT launch, so cap writes to one per interval; ticks
  // in between just mark the cache dirty and the next tick past the deadline
  // (or a trip to the background) flushes the latest rates. Screenshot mode
  // keeps its write-every-tick path in [_applyTick] — deliberate, see there.
  static const Duration _ratesCacheWriteInterval = Duration(seconds: 30);
  DateTime? _lastRatesCacheSaveAt;
  bool _ratesCacheDirty = false;
  // Relative tolerance below which a tick is treated as a no-op (no repaint).
  // Tightened from 1bp to ~zero so the WS path passes through real ticks —
  // at ~1 tick/sec a 1bp gate would suppress most updates.
  static const double _noOpRelTolerance = 1e-6;

  // The fixed, clean price shown in screenshot mode. A round number in every
  // currency (so "$58,000", "€58,000", etc. — no FX conversion), chosen so
  // marketing screenshots always show the same figure regardless of when or
  // where they're taken.
  static const double _screenshotPrice = 58000;
  static const BtcRates _screenshotRates = BtcRates(
    usd: _screenshotPrice,
    gbp: _screenshotPrice,
    eur: _screenshotPrice,
    jpy: _screenshotPrice,
    cad: _screenshotPrice,
    aud: _screenshotPrice,
    chf: _screenshotPrice,
  );

  // In screenshot mode, hand out the fixed display rates instead of the live
  // (frozen) ones. The real rate stays in `_rates` so leaving the mode snaps
  // back to it.
  BtcRates get rates => _screenshotMode ? _screenshotRates : _rates;
  bool get screenshotMode => _screenshotMode;
  List<HistoryPoint> get allHistory => _history.allHistory;
  FxHistory? get fxHistory => _history.fxHistory;
  DateTime? get lastFetchedAt => _lastFetchedAt;
  LivePriceCadence get cadence => _cadence;

  /// Update the throttle policy. Switching from a slower cadence to a faster
  /// one fires one repaint immediately so the UI catches up rather than
  /// waiting for the next tick.
  set cadence(LivePriceCadence value) {
    if (_cadence == value) return;
    _cadence = value;
    _throttler.interval = value.minInterval;
    _throttler.cancelPending();
  }

  /// Debug-only: freeze the displayed price. While on, WS ticks are dropped
  /// before they reach `_rates` (see [_applyTick]), so the price card holds
  /// still and its delta badge never fires. Turning it off flushes the latest
  /// streamed rate so the card catches up to live. Gated to debug builds at the
  /// call site (the Settings toggle), so release builds can never enable it.
  set screenshotMode(bool value) {
    if (_screenshotMode == value) return;
    _screenshotMode = value;
    if (!value) {
      // Leaving freeze: adopt whatever the stream cached while we were frozen
      // so the live getter (and the next repaint) reflect the current price
      // rather than the rate from when we entered the mode.
      _rates = _cache.load();
      _lastFetchedAt = DateTime.now();
    }
    // Notify on both edges: the `rates` getter flips between the fixed and live
    // values here, and the Settings toggle (context.watch) must rebuild so the
    // switch reflects the new state.
    notifyListeners();
  }

  List<HistoryPoint>? intradayFor(BtcRange range) =>
      _history.intradayFor(range);
  bool isIntradayLoading(BtcRange range) => _history.isIntradayLoading(range);
  bool didIntradayFail(BtcRange range) => _history.didIntradayFail(range);
  bool isIntradayStale(BtcRange range) => _history.isIntradayStale(range);

  final ChartSeriesProjector _projector = ChartSeriesProjector();

  ChartSeriesProjector get _chartProjector => _projector
    ..fxHistory = _history.fxHistory
    ..allHistory = _history.allHistory;

  List<PricePoint> convertedSeries({
    required List<HistoryPoint> series,
    required Currency currency,
    required double usdToCurrencyFallback,
  }) => _chartProjector.convertedSeries(
    series: series,
    currency: currency,
    usdToCurrencyFallback: usdToCurrencyFallback,
  );
  List<PricePoint> convertedAllHistory({
    required Currency currency,
    required double usdToCurrencyFallback,
  }) => _chartProjector.convertedAllHistory(
    currency: currency,
    usdToCurrencyFallback: usdToCurrencyFallback,
  );
  List<PricePoint> convertedSeriesWithLive({
    required List<HistoryPoint> series,
    required Currency currency,
    required double usdToCurrencyFallback,
    required double livePrice,
  }) => _chartProjector.convertedSeriesWithLive(
    series: series,
    currency: currency,
    usdToCurrencyFallback: usdToCurrencyFallback,
    livePrice: livePrice,
  );
  List<PricePoint> convertedAllHistoryWithLive({
    required Currency currency,
    required double usdToCurrencyFallback,
    required double livePrice,
  }) => _chartProjector.convertedAllHistoryWithLive(
    currency: currency,
    usdToCurrencyFallback: usdToCurrencyFallback,
    livePrice: livePrice,
  );

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _streamSub ??= _stream.ticks.listen(_applyTick);
    _stream.start();
    unawaited(refreshHistory());
    unawaited(_history.loadFxHistory());
  }

  Future<void> refreshHistory() => _history.refreshHistory();

  /// Debug-only: synthesize a price tick by nudging every rate by a small
  /// signed percentage. Lets us exercise the rolling-number + delta-badge
  /// animations without waiting on the network.
  void debugSimulateTick({double maxPctDrift = 0.0015}) {
    if (!kDebugMode) return;
    final rng = Random();
    double? jitter(double? v) {
      if (v == null) return null;
      final pct = (rng.nextDouble() * 2 - 1) * maxPctDrift;
      return v * (1 + pct);
    }

    _rates = BtcRates(
      usd: jitter(_rates.usd),
      gbp: jitter(_rates.gbp),
      eur: jitter(_rates.eur),
      jpy: jitter(_rates.jpy),
      cad: jitter(_rates.cad),
      aud: jitter(_rates.aud),
      chf: jitter(_rates.chf),
    );
    _lastFetchedAt = DateTime.now();
    notifyListeners();
  }

  void _applyTick(KrakenTick tick) {
    if (_disposed) return;
    final updated = _mergeKrakenTick(_rates, tick);
    if (updated == null) return; // unrecognised pair
    if (_screenshotMode) {
      // Frozen for screenshots: keep the cache warm off the live merge (so
      // leaving the mode can snap straight to the current price) but don't
      // touch `_rates` or repaint — the visible price holds still and no delta
      // fires. `_lastFetchedAt` is left stale on purpose so a background/resume
      // cycle during a shoot doesn't decide the data is fresh and skip a
      // refetch we'd want post-shoot. This save deliberately bypasses the
      // [_ratesCacheWriteInterval] throttle: leaving the mode snaps to
      // `_cache.load()`, so the cache must always hold the newest tick.
      unawaited(_cache.save(updated));
      return;
    }
    if (_isNoOpUpdate(_rates, updated)) {
      _lastFetchedAt = DateTime.now();
      return;
    }
    _rates = updated;
    _lastFetchedAt = DateTime.now();
    _maybeSaveRatesCache();
    _maybeNotify();
  }

  void _maybeSaveRatesCache() {
    final now = DateTime.now();
    final last = _lastRatesCacheSaveAt;
    if (last != null && now.difference(last) < _ratesCacheWriteInterval) {
      _ratesCacheDirty = true;
      return;
    }
    _lastRatesCacheSaveAt = now;
    _ratesCacheDirty = false;
    unawaited(_cache.save(_rates));
  }

  // Persist rates the throttle was sitting on. Called when the app leaves the
  // foreground (and on dispose) so the next cold start shows a price no
  // staler than the moment the user left.
  void _flushRatesCache() {
    if (!_ratesCacheDirty) return;
    _ratesCacheDirty = false;
    _lastRatesCacheSaveAt = DateTime.now();
    unawaited(_cache.save(_rates));
  }

  // Cadence gate. Throttled cadences delegate to [_throttler], which handles
  // the immediate-vs-deferred decision and coalesces suppressed ticks.
  void _maybeNotify() {
    if (_disposed) return;
    _throttler.request();
  }

  static BtcRates? _mergeKrakenTick(BtcRates current, KrakenTick tick) {
    final price = tick.last;
    return switch (tick.pairCode) {
      'BTC/USD' => current.copyWith(usd: price),
      'BTC/EUR' => current.copyWith(eur: price),
      'BTC/GBP' => current.copyWith(gbp: price),
      'BTC/JPY' => current.copyWith(jpy: price),
      'BTC/CAD' => current.copyWith(cad: price),
      'BTC/AUD' => current.copyWith(aud: price),
      'BTC/CHF' => current.copyWith(chf: price),
      _ => null,
    };
  }

  static bool _isNoOpUpdate(BtcRates a, BtcRates b) {
    bool close(double? x, double? y) {
      if (x == null || y == null) return x == y;
      if (x == y) return true;
      if (x == 0) return y == 0;
      return ((x - y).abs() / x.abs()) < _noOpRelTolerance;
    }

    return close(a.usd, b.usd) &&
        close(a.gbp, b.gbp) &&
        close(a.eur, b.eur) &&
        close(a.jpy, b.jpy) &&
        close(a.cad, b.cad) &&
        close(a.aud, b.aud) &&
        close(a.chf, b.chf);
  }

  /// The screen calls this every time the displayed range changes, passing the
  /// range when it's intraday (1D/1W/1M) or null otherwise. The controller
  /// uses it to decide what to re-fetch after a resume-time invalidation, and
  /// whether to arm the 1D auto-refresh timer.
  void setActiveIntradayRange(BtcRange? range) {
    if (_activeIntradayRange == range) return;
    _activeIntradayRange = range;
    _syncIntradayAutoRefresh();
  }

  void _syncIntradayAutoRefresh() {
    final shouldRun =
        !_disposed && !_appBackgrounded && _activeIntradayRange == BtcRange.d1;
    if (!shouldRun) {
      _intradayAutoRefreshTimer?.cancel();
      _intradayAutoRefreshTimer = null;
      return;
    }
    if (_intradayAutoRefreshTimer != null) return;
    _intradayAutoRefreshTimer = Timer.periodic(_intradayAutoRefreshInterval, (
      _,
    ) {
      if (_disposed) return;
      if (_activeIntradayRange != BtcRange.d1) return;
      unawaited(fetchIntraday(BtcRange.d1, force: true));
    });
  }

  Future<void> fetchIntraday(BtcRange range, {bool force = false}) =>
      _history.fetchIntraday(range, force: force);

  /// Bounce the WS so the live-price feed reconnects without waiting out the
  /// current backoff. Paired with `fetchIntraday(force: true)` from the chart's
  /// retry button, since both Kraken transports tend to fail together.
  void restartStream() => _stream.restart();

  void _invalidateIntraday() {
    _history.invalidateIntraday();
    final active = _activeIntradayRange;
    if (active != null) unawaited(fetchIntraday(active));
  }

  bool _isStale(DateTime? at) =>
      at == null || DateTime.now().difference(at) >= _resumeQuietWindow;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _appBackgrounded = true;
        _stream.stop();
        _flushRatesCache();
        _syncIntradayAutoRefresh();
      case AppLifecycleState.resumed:
        _appBackgrounded = false;
        _stream.start();
        // Only re-fetch the data the active view actually shows. Intraday
        // ranges (1D/1W/1M) read from `_intraday`; long ranges (3M+) read
        // from `_allHistory`. Re-fetching the side the user isn't looking
        // at is wasted bytes — they'll be stale-gated again on their next
        // visit anyway.
        final onIntraday = _activeIntradayRange != null;
        if (onIntraday) {
          if (_isStale(_history.lastIntradayFetchedAt)) _invalidateIntraday();
        } else {
          if (_isStale(_history.lastHistoryFetchedAt)) {
            unawaited(refreshHistory());
          }
        }
        _syncIntradayAutoRefresh();
      case AppLifecycleState.detached:
        _appBackgrounded = true;
        _stream.stop();
        _flushRatesCache();
        _syncIntradayAutoRefresh();
    }
  }

  @override
  void dispose() {
    _flushRatesCache();
    _disposed = true;
    _app?.removeListener(_syncCadenceFromApp);
    _throttler.dispose();
    _intradayAutoRefreshTimer?.cancel();
    _intradayAutoRefreshTimer = null;
    _streamSub?.cancel();
    _streamSub = null;
    unawaited(_stream.dispose());
    _history.removeListener(notifyListeners);
    _history.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
