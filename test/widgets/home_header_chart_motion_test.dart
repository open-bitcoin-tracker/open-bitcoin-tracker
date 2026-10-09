import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_bitcoin_tracker/api/api.dart';
import 'package:open_bitcoin_tracker/data/data.dart' hide Stack;
import 'package:open_bitcoin_tracker/l10n/generated/app_localizations.dart';
import 'package:open_bitcoin_tracker/screens/home/header/area_chart.dart';
import 'package:open_bitcoin_tracker/screens/home/header/home_header.dart';
import 'package:open_bitcoin_tracker/state/state.dart';
import 'package:open_bitcoin_tracker/theme/theme.dart';

import '../support/test_viewport.dart';
import 'chart_range_motion_test.dart' as samples;

void main() {
  for (final landscape in [false, true]) {
    testWidgets(
      'parent retains chart through ranges and loading ($landscape)',
      (tester) async {
        setTestViewport(
          tester,
          landscape ? const Size(900, 600) : const Size(600, 900),
        );
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final app = AppStateNotifier(AppStateRepository(prefs));
        final rasterKey = GlobalKey();
        final hover = ValueNotifier<PricePoint?>(null);
        addTearDown(app.dispose);
        addTearDown(hover.dispose);

        Future<void> show(
          BtcRange range,
          List<PricePoint> data, {
          bool loading = false,
        }) => tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: app,
            child: MaterialApp(
              theme: AppThemes.light(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: RepaintBoundary(
                  key: rasterKey,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: HomeHeader(
                      failed: false,
                      showChart: true,
                      currentPrice: 102,
                      hover: hover,
                      lastFetchedAt: null,
                      range: range,
                      currency: Currency.usd,
                      selectedCurrencies: const [Currency.usd],
                      chartColor: Colors.orange,
                      rangePct: null,
                      rangeAbsDiff: null,
                      rollDirection: 1,
                      showSwipeHint: false,
                      currencyEverSwiped: false,
                      onPriceTap: () {},
                      onGraphSettingsTap: () {},
                      onCurrencySwipe: (_) {},
                      onDismissSwipeHint: () {},
                      chartData: data,
                      chartWindowStartMs: data.isEmpty ? 0 : data.first.t,
                      chartWindowEndMs: data.isEmpty ? 1 : data.last.t,
                      allHistoryEmpty: false,
                      usesAllHistory: range.usesAllHistory,
                      loading: loading,
                      onRange: (_) {},
                      onHover: (point) => hover.value = point,
                      onRetry: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        Future<ByteData> raster() async {
          return (await tester.runAsync(() async {
            final boundary =
                rasterKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            image.dispose();
            return bytes!;
          }))!;
        }

        final width = landscape ? 900 : 600;
        int orangeAbovePlot(ByteData pixels, int plotTop) {
          var count = 0;
          for (var i = 0; i < plotTop * width * 4; i += 4) {
            if (pixels.getUint8(i) > 240 &&
                pixels.getUint8(i + 1) >= 145 &&
                pixels.getUint8(i + 1) <= 160 &&
                pixels.getUint8(i + 2) < 15) {
              count++;
            }
          }
          return count;
        }

        await show(BtcRange.all, samples.daily);
        final baseline = await raster();
        final plotTop = tester.getTopLeft(find.byType(AreaChart)).dy.floor();
        final state = tester.state(find.byType(AreaChart));
        final original = samples.camera(samples.frame(tester));
        await show(BtcRange.d1, const [], loading: true);
        expect(identical(tester.state(find.byType(AreaChart)), state), isTrue);
        expect(samples.camera(samples.frame(tester)), original);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 500));
        expect(samples.camera(samples.frame(tester)), original);

        await show(BtcRange.d1, samples.fine);
        expect(identical(tester.state(find.byType(AreaChart)), state), isTrue);
        expect(samples.camera(samples.frame(tester)), original);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        final chartOpacity = find.descendant(
          of: find.byType(AreaChart),
          matching: find.byType(Opacity),
        );
        expect(tester.widget<Opacity>(chartOpacity).opacity, 1);
        await tester.pump(const Duration(milliseconds: 350));
        final zoomRaster = await raster();
        expect(
          orangeAbovePlot(zoomRaster, plotTop),
          greaterThan(orangeAbovePlot(baseline, plotTop)),
          reason: 'The animated curve must paint upward behind the price',
        );
        // Overflow stays inside the header, below the 80px screen gutter.
        expect(
          zoomRaster.buffer.asUint8List(0, 80 * width * 4),
          baseline.buffer.asUint8List(0, 80 * width * 4),
        );
        // Price/navigation ink stays in front of the overflowing curve.
        for (var i = 80 * width * 4; i < plotTop * width * 4; i += 4) {
          if (baseline.getUint8(i + 3) > 225 &&
              baseline.getUint8(i) < 60 &&
              baseline.getUint8(i + 1) < 60 &&
              baseline.getUint8(i + 2) < 60) {
            expect(zoomRaster.getUint8(i), lessThan(80));
            expect(zoomRaster.getUint8(i + 1), lessThan(80));
            expect(zoomRaster.getUint8(i + 2), lessThan(80));
          }
        }
        await tester.pump(const Duration(milliseconds: 100));
        expect(samples.times(samples.frame(tester)), [
          1500,
          1800,
          2200,
          2600,
          3000,
        ]);

        await show(BtcRange.all, samples.daily);
        expect(identical(tester.state(find.byType(AreaChart)), state), isTrue);
        expect(samples.times(samples.frame(tester)), [
          0,
          1000,
          1500,
          1800,
          2200,
          2600,
          3000,
        ]);
        expect(tester.widget<Opacity>(chartOpacity).opacity, 1);
        await tester.pump(const Duration(milliseconds: 450));
        expect(samples.times(samples.frame(tester)), [0, 1000, 2000, 3000]);
        expect(tester.takeException(), isNull);
        expect(find.byType(LineChart), findsOneWidget);
      },
    );
  }
}
