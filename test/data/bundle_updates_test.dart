import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_bitcoin_tracker/api/kraken_ohlc_client.dart';
import 'package:open_bitcoin_tracker/api/price_data.dart';
import 'package:open_bitcoin_tracker/data/app_enums.dart';
import 'package:open_bitcoin_tracker/data/btc_history.dart';
import 'package:open_bitcoin_tracker/data/btc_history_cache.dart';
import 'package:open_bitcoin_tracker/data/fx_history.dart';
import 'package:open_bitcoin_tracker/data/market_history_repository.dart';
import 'package:open_bitcoin_tracker/screens/home/chart_slice.dart';
import 'package:open_bitcoin_tracker/state/chart_series_projector.dart';

int day(String date) =>
    DateTime.parse('${date}T00:00:00Z').millisecondsSinceEpoch;
HistoryPoint point(String date, double price) => HistoryPoint(day(date), price);

class _MemoryCache extends BtcHistoryCache {
  _MemoryCache(this.points);
  List<HistoryPoint> points;
  @override
  Future<List<HistoryPoint>> load() async => points;
  @override
  Future<void> save(List<HistoryPoint> history) async => points = history;
}

class _Daily extends KrakenOhlcClient {
  List<HistoryPoint>? response;
  int? since;
  @override
  Future<List<HistoryPoint>?> daily({int? sinceTs}) async {
    since = sinceTs;
    return response;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> useAssets(Map<String, String> assets) async {
    for (final asset in assets.keys) {
      rootBundle.evict(asset);
    }
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final name = utf8.decode(message!.buffer.asUint8List());
      final text = assets[name];
      return text == null
          ? null
          : ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
    });
  }

  tearDown(() async {
    messenger.setMockMessageHandler('flutter/assets', null);
    rootBundle.evict('assets/btc_history.csv');
    rootBundle.evict('assets/fx_history.csv');
  });

  test(
    'bundle repairs cached dates and gaps offline and persists the union',
    () async {
      final cache = _MemoryCache([
        point('2026-01-01', 50),
        point('2026-10-14', 80),
        point('2026-10-17', 110),
      ]);
      final daily = _Daily();
      final repo = MarketHistoryRepository(
        ohlc: daily,
        cache: cache,
        loadBundled: () async => [
          point('2026-10-14', 90),
          point('2026-10-15', 95),
          point('2026-10-16', 100),
        ],
        now: () => DateTime.utc(2026, 10, 18),
      );
      addTearDown(repo.dispose);
      await repo.refreshHistory();
      expect(repo.allHistory.map((p) => p.priceUsd), [50, 90, 95, 100, 110]);
      expect(
        repo.allHistory.map((p) => p.timeMs),
        orderedEquals([
          day('2026-01-01'),
          day('2026-10-14'),
          day('2026-10-15'),
          day('2026-10-16'),
          day('2026-10-17'),
        ]),
      );
      expect(cache.points, same(repo.allHistory));
      expect(repo.lastHistoryFetchedAt, isNull);
      expect(
        daily.since,
        DateTime.utc(2026, 10, 13).millisecondsSinceEpoch ~/ 1000,
      );
      expect(() => repo.allHistory.clear(), throwsUnsupportedError);

      daily.response = [point('2026-10-16', 105), point('2026-10-18', 120)];
      await repo.refreshHistory();
      expect(repo.allHistory.map((p) => p.priceUsd), [
        50,
        90,
        95,
        105,
        110,
        120,
      ]);
      expect(cache.points, same(repo.allHistory));
    },
  );

  test(
    'a longer bundle changes range selection and conversions without constants',
    () async {
      var bundle = [point('2026-01-01', 50), point('2026-01-02', 60)];
      final repo = MarketHistoryRepository(
        ohlc: _Daily(),
        cache: _MemoryCache([]),
        loadBundled: () async => bundle,
        now: () => DateTime.utc(2026, 10, 18),
      );
      addTearDown(repo.dispose);
      final slicer = ChartSlicer();
      final projector = ChartSeriesProjector();
      await repo.refreshHistory();
      expect(slicer.slice(repo.allHistory, BtcRange.m3), hasLength(2));
      projector.allHistory = repo.allHistory;
      final before = projector.convertedAllHistory(
        currency: Currency.usd,
        usdToCurrencyFallback: 1,
      );
      bundle = [...bundle, point('2026-10-16', 100), point('2026-10-17', 110)];
      await repo.refreshHistory();
      final range = slicer.slice(repo.allHistory, BtcRange.m3);
      expect(range.map((p) => p.priceUsd), [100, 110]);
      projector.allHistory = repo.allHistory;
      final after = projector.convertedAllHistory(
        currency: Currency.usd,
        usdToCurrencyFallback: 1,
      );
      expect(after, isNot(same(before)));
      expect(after.last.t, day('2026-10-17'));
      expect(after.last.price, 110);
    },
  );

  test('bundle failure preserves usable cached history', () async {
    final repo = MarketHistoryRepository(
      ohlc: _Daily(),
      cache: _MemoryCache([point('2026-10-17', 110)]),
      loadBundled: () async => throw const FormatException('invalid bundle'),
    );
    addTearDown(repo.dispose);
    await repo.refreshHistory();
    expect(repo.allHistory.single.priceUsd, 110);
  });

  test('BTC asset dates are UTC and invalid prices are excluded', () async {
    await useAssets({
      'assets/btc_history.csv':
          '2026-10-16,100\n2026-10-17,110\n2026-10-18,NaN\n2026-10-19,Infinity\n',
    });
    final points = await loadBundledHistory();
    expect(points.map((p) => p.timeMs), [day('2026-10-16'), day('2026-10-17')]);
    expect(points.map((p) => p.priceUsd), [100, 110]);
  });

  test(
    'replacing FX history invalidates conversions and applies each date rate',
    () async {
      const header = 'date,EUR,GBP,AUD,CAD,CHF,JPY\n';
      await useAssets({
        'assets/fx_history.csv':
            '${header}2026-05-14,0.8,0.7,1.4,1.3,0.75,150\n',
      });
      final projector = ChartSeriesProjector()
        ..allHistory = [
          point('2026-05-14', 100),
          point('2026-10-16', 100),
          point('2026-10-17', 100),
        ]
        ..fxHistory = await loadBundledFxHistory();
      final old = projector.convertedAllHistory(
        currency: Currency.eur,
        usdToCurrencyFallback: 999,
      );
      expect(old.map((p) => p.price), [80, 80, 80]);
      await useAssets({
        'assets/fx_history.csv':
            '${header}2026-05-14,0.8,0.7,1.4,1.3,0.75,150\n'
            '2026-10-16,0.9,0.75,1.5,1.4,0.8,158\n'
            '2026-10-18,NaN,Infinity,0,-1,,NaN\n',
      });
      projector.fxHistory = await loadBundledFxHistory();
      final updated = projector.convertedAllHistory(
        currency: Currency.eur,
        usdToCurrencyFallback: 999,
      );
      expect(updated, isNot(same(old)));
      expect(updated.map((p) => p.price), [80, 90, 90]);
      expect(projector.fxHistory!.rateAt(Currency.eur, day('2026-10-16')), 0.9);
      expect(projector.fxHistory!.rateAt(Currency.eur, day('2026-10-19')), 0.9);
      for (final currency in Currency.values) {
        final converted = projector.convertedAllHistory(
          currency: currency,
          usdToCurrencyFallback: 999,
        );
        expect(
          converted.last.price,
          100 * projector.fxHistory!.rateAt(currency, day('2026-10-17')),
        );
      }
    },
  );

  test('shipped bundles cover every BTC day with valid FX rates', () async {
    final btc = await loadBundledHistory();
    final fx = await loadBundledFxHistory();
    final rows = File(
      'assets/fx_history.csv',
    ).readAsLinesSync().skip(1).where((s) => s.trim().isNotEmpty).toList();
    expect(
      day(rows.first.split(',').first),
      lessThanOrEqualTo(btc.first.timeMs),
    );
    expect(
      day(rows.last.split(',').first),
      greaterThanOrEqualTo(btc.last.timeMs),
    );
    int? previous;
    for (final row in rows) {
      final columns = row.split(',');
      expect(columns, hasLength(7));
      final timestamp = day(columns.first);
      if (previous != null) expect(timestamp - previous, 86400000);
      previous = timestamp;
      for (final value in columns.skip(1)) {
        final rate = double.parse(value);
        expect(rate.isFinite && rate > 0, isTrue);
      }
    }
    for (final point in btc) {
      for (final currency in Currency.values) {
        final converted = point.priceUsd * fx.rateAt(currency, point.timeMs);
        expect(converted.isFinite && converted > 0, isTrue);
      }
    }
  });
}
