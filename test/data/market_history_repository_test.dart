import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_bitcoin_tracker/api/kraken_ohlc_client.dart';
import 'package:open_bitcoin_tracker/api/price_data.dart';
import 'package:open_bitcoin_tracker/data/app_enums.dart';
import 'package:open_bitcoin_tracker/data/btc_history_cache.dart';
import 'package:open_bitcoin_tracker/data/market_history_repository.dart';

class _Ohlc extends KrakenOhlcClient {
  final requests = <BtcRange, List<Completer<List<HistoryPoint>?>>>{};
  final dailyRequests = <Completer<List<HistoryPoint>?>>[];
  @override
  Future<List<HistoryPoint>?> intraday(BtcRange range) {
    final completer = Completer<List<HistoryPoint>?>();
    requests.putIfAbsent(range, () => []).add(completer);
    return completer.future;
  }

  @override
  Future<List<HistoryPoint>?> daily({int? sinceTs}) {
    final completer = Completer<List<HistoryPoint>?>();
    dailyRequests.add(completer);
    return completer.future;
  }
}

class _BrokenCache extends BtcHistoryCache {
  @override
  Future<List<HistoryPoint>> load() async =>
      throw const FileSystemException('unreadable');
  @override
  Future<void> save(List<HistoryPoint> history) async =>
      throw const FileSystemException('unwritable');
}

Future<void> _requestsStarted() => Future<void>.delayed(Duration.zero);

void main() {
  late _Ohlc ohlc;
  late MarketHistoryRepository repo;
  var now = DateTime.utc(2026, 10, 8, 12);
  setUp(() {
    now = DateTime.utc(2026, 10, 8, 12);
    ohlc = _Ohlc();
    repo = MarketHistoryRepository(
      ohlc: ohlc,
      cache: _BrokenCache(),
      loadBundled: () async => [
        HistoryPoint(
          now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
          100,
        ),
      ],
      now: () => now,
    );
  });
  tearDown(() => repo.dispose());

  test('day freshness follows the actual 15-minute candle interval', () async {
    final task = repo.fetchIntraday(BtcRange.d1);
    await _requestsStarted();
    ohlc.requests[BtcRange.d1]!.single.complete([
      HistoryPoint(
        now.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch,
        100,
      ),
    ]);
    await task;
    expect(repo.isIntradayStale(BtcRange.d1), isFalse);
    now = now.add(const Duration(minutes: 13));
    expect(repo.isIntradayStale(BtcRange.d1), isTrue);
  });

  test(
    'overlapping ranges deduplicate independently and keep loading state',
    () async {
      final day = repo.fetchIntraday(BtcRange.d1);
      final week = repo.fetchIntraday(BtcRange.w1);
      expect(
        identical(day, repo.fetchIntraday(BtcRange.d1, force: true)),
        isTrue,
      );
      await _requestsStarted();
      expect(ohlc.requests[BtcRange.d1], hasLength(1));
      expect(repo.isIntradayLoading(BtcRange.d1), isTrue);
      expect(repo.isIntradayLoading(BtcRange.w1), isTrue);
      ohlc.requests[BtcRange.d1]!.single.complete([
        HistoryPoint(now.millisecondsSinceEpoch, 100),
      ]);
      await day;
      expect(repo.isIntradayLoading(BtcRange.d1), isFalse);
      expect(repo.isIntradayLoading(BtcRange.w1), isTrue);
      ohlc.requests[BtcRange.w1]!.single.complete(null);
      await week;
      expect(repo.didIntradayFail(BtcRange.w1), isTrue);
    },
  );

  test('invalidated requests cannot overwrite the fresh response', () async {
    final old = repo.fetchIntraday(BtcRange.d1);
    await _requestsStarted();
    repo.invalidateIntraday();
    final fresh = repo.fetchIntraday(BtcRange.d1);
    await _requestsStarted();
    final requests = ohlc.requests[BtcRange.d1]!;
    requests.last.complete([HistoryPoint(now.millisecondsSinceEpoch, 200)]);
    await fresh;
    requests.first.complete([HistoryPoint(now.millisecondsSinceEpoch, 100)]);
    await old;
    expect(repo.intradayFor(BtcRange.d1)!.single.priceUsd, 200);
  });

  test('week windows reuse a fresh month without another request', () async {
    final month = repo.fetchIntraday(BtcRange.m1);
    await _requestsStarted();
    ohlc.requests[BtcRange.m1]!.single.complete([
      for (var i = 719; i >= 0; i--)
        HistoryPoint(
          now.subtract(Duration(hours: i)).millisecondsSinceEpoch,
          100,
        ),
    ]);
    await month;
    await repo.fetchIntraday(BtcRange.w2);
    expect(ohlc.requests.containsKey(BtcRange.w2), isFalse);
    expect(repo.intradayFor(BtcRange.w2), hasLength(336));
    expect(
      () => repo.intradayFor(BtcRange.w2)!.clear(),
      throwsUnsupportedError,
    );
  });

  test(
    'cache failures retain bundled data and vendor corrections; refreshes coalesce',
    () async {
      final refresh = repo.refreshHistory();
      expect(identical(refresh, repo.refreshHistory()), isTrue);
      await _requestsStarted();
      expect(repo.allHistory.single.priceUsd, 100);
      ohlc.dailyRequests.single.complete([
        HistoryPoint(
          now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
          120,
        ),
        HistoryPoint(now.millisecondsSinceEpoch, 200),
      ]);
      await refresh;
      expect(repo.allHistory.map((point) => point.priceUsd), [120, 200]);
      expect(() => repo.allHistory.clear(), throwsUnsupportedError);
    },
  );
}
