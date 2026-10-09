import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_bitcoin_tracker/api/api.dart';
import 'package:open_bitcoin_tracker/screens/home/header/area_chart.dart';

const daily = [
  PricePoint(0, 1),
  PricePoint(1000, 120),
  PricePoint(2000, 110),
  PricePoint(3000, 102),
];
const fine = [
  PricePoint(1500, 98),
  PricePoint(1800, 100),
  PricePoint(2200, 105),
  PricePoint(2600, 99),
  PricePoint(3000, 102),
];
const coarse = [
  PricePoint(500, 50),
  PricePoint(1700, 180),
  PricePoint(2500, 70),
  PricePoint(3500, 103),
];

Future<void> showChart(
  WidgetTester tester, {
  List<PricePoint> data = daily,
  String range = 'all',
  Object series = 'daily',
  bool logScale = false,
  bool reducedMotion = false,
  bool selectionEnabled = true,
  ValueChanged<PricePoint?>? onHover,
  int? start,
  int? end,
}) => tester.pumpWidget(
  MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(800, 600),
        disableAnimations: reducedMotion,
      ),
      child: Scaffold(
        body: SizedBox(
          width: 400,
          height: 200,
          child: AreaChart(
            data: data,
            windowStartMs: start ?? (data.isEmpty ? 0 : data.first.t),
            windowEndMs: end ?? (data.isEmpty ? 1 : data.last.t),
            color: Colors.orange,
            logScale: logScale,
            rangeKey: range,
            seriesKey: series,
            selectionEnabled: selectionEnabled,
            onHover: onHover ?? (_) {},
          ),
        ),
      ),
    ),
  ),
);

LineChartData frame(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data;
List<double> camera(LineChartData chart) => [
  chart.minX,
  chart.maxX,
  chart.minY,
  chart.maxY,
];
List<double> times(LineChartData chart) =>
    chart.lineBarsData.single.spots.map((s) => s.x).toList();
double opacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.byType(Opacity)).opacity;

void main() {
  for (final logarithmic in [false, true]) {
    testWidgets('intraday to daily preserves detail ($logarithmic)', (
      tester,
    ) async {
      await showChart(
        tester,
        data: fine,
        range: 'day',
        series: 15,
        logScale: logarithmic,
      );
      final original = frame(tester);
      await showChart(tester, logScale: logarithmic);
      expect(camera(frame(tester)), camera(original));
      expect(times(frame(tester)), [0, 1000, 1500, 1800, 2200, 2600, 3000]);
      final held = frame(tester).lineBarsData.single.spots.skip(2).toList();
      expect(held, original.lineBarsData.single.spots);
      expect(opacity(tester), 1);
      await tester.pump(const Duration(milliseconds: 150));
      final t = Curves.easeInOutCubic.transform(1 / 3);
      expect(frame(tester).minX, closeTo(1500 * (1 - t), 1e-7));
      final low = logarithmic ? 0.0 : 1.0;
      final high = logarithmic ? math.log(120) / math.ln10 : 120.0;
      final bottom = low - (high - low) * .05;
      final top = high + (high - low) * .05;
      expect(
        frame(tester).minY,
        closeTo(original.minY + (bottom - original.minY) * t, 1e-7),
      );
      expect(
        frame(tester).maxY,
        closeTo(original.maxY + (top - original.maxY) * t, 1e-7),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(times(frame(tester)), daily.map((p) => p.t.toDouble()).toList());
      expect(frame(tester).minX, 0);
      expect(opacity(tester), 1);
    });
  }

  testWidgets('candle zoom-out adds history only outside outgoing timestamps', (
    tester,
  ) async {
    await showChart(tester, data: fine, range: 'day', series: 15);
    await showChart(tester, data: coarse, range: 'week', series: 60);
    expect(times(frame(tester)), [500, 1500, 1800, 2200, 2600, 3000, 3500]);
    await tester.pump(const Duration(milliseconds: 450));
    expect(times(frame(tester)), [500, 1700, 2500, 3500]);
    expect(coarse.length, 4); // Transition geometry did not mutate actual data.
  });

  testWidgets('zoom-in holds the wider outgoing curve until 450 ms', (
    tester,
  ) async {
    await showChart(tester);
    await showChart(tester, data: fine, range: 'day', series: 15);
    await tester.pump(const Duration(milliseconds: 449));
    expect(times(frame(tester)), [0, 1000, 2000, 3000]);
    expect(opacity(tester), 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(times(frame(tester)), [1500, 1800, 2200, 2600, 3000]);
  });

  testWidgets('interrupted zoom continues from every displayed camera bound', (
    tester,
  ) async {
    await showChart(tester);
    await showChart(tester, data: fine, range: 'day', series: 15);
    await tester.pump(const Duration(milliseconds: 150));
    final interrupted = camera(frame(tester));
    await showChart(tester, data: coarse, range: 'week', series: 60);
    expect(camera(frame(tester)), interrupted);
    // The held daily curve is the displayed source, even though the last
    // requested target was intraday. Merge against that displayed source.
    expect(times(frame(tester)), [0, 1000, 2000, 3000, 3500]);
    await tester.pump(const Duration(milliseconds: 450));
    expect(times(frame(tester)), [500, 1700, 2500, 3500]);
    expect(frame(tester).minX, 500);
    expect(frame(tester).maxX, 3500);
  });

  testWidgets(
    'interrupted cross-resolution zoom retains the displayed detail',
    (tester) async {
      await showChart(tester, data: fine, range: 'day', series: 15);
      await showChart(tester);
      await tester.pump(const Duration(milliseconds: 150));
      final interrupted = camera(frame(tester));
      final displayedTimes = times(frame(tester));
      await showChart(tester, data: fine, range: 'day', series: 15);
      expect(camera(frame(tester)), interrupted);
      expect(times(frame(tester)), displayedTimes);
      await tester.pump(const Duration(milliseconds: 450));
      expect(times(frame(tester)), [1500, 1800, 2200, 2600, 3000]);
    },
  );

  testWidgets('ticks and rebuilds update targets without resetting the clock', (
    tester,
  ) async {
    await showChart(tester);
    await showChart(tester, data: fine, range: 'day', series: 15);
    await tester.pump(const Duration(milliseconds: 150));
    final updated = [...fine.take(4), const PricePoint(3100, 104)];
    await showChart(tester, data: updated, range: 'day', series: 15);
    await tester.pump(const Duration(milliseconds: 300));
    expect(frame(tester).minX, 1500);
    expect(frame(tester).maxX, 3100);
    expect(times(frame(tester)), [1500, 1800, 2200, 2600, 3100]);
    await showChart(
      tester,
      data: updated,
      range: 'day',
      series: 15,
      start: 1600,
      end: 3200,
    );
    expect(frame(tester).minX, 1600); // No transition on ordinary rebuilds.
    expect(frame(tester).maxX, 3200);
  });

  testWidgets(
    'uncached range retains outgoing camera and animates on arrival',
    (tester) async {
      await showChart(tester);
      final original = frame(tester);
      await showChart(
        tester,
        data: const [],
        range: 'day',
        series: 15,
        selectionEnabled: false,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(camera(frame(tester)), camera(original));
      expect(times(frame(tester)), times(original));
      expect(opacity(tester), 1);
      await showChart(tester, data: fine, range: 'day', series: 15);
      expect(camera(frame(tester)), camera(original));
      await tester.pump(const Duration(milliseconds: 450));
      expect(times(frame(tester)), [1500, 1800, 2200, 2600, 3000]);
    },
  );

  testWidgets('scale geometry changes only between the two 150 ms fades', (
    tester,
  ) async {
    await showChart(tester);
    final original = camera(frame(tester));
    await showChart(tester, logScale: true);
    await tester.pump(const Duration(milliseconds: 75));
    expect(camera(frame(tester)), original);
    expect(opacity(tester), closeTo(.5, 1e-7));
    await tester.pump(const Duration(milliseconds: 75));
    expect(opacity(tester), 0);
    expect(frame(tester).lineBarsData.single.spots.first.y, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));
    expect(opacity(tester), closeTo(.5, 1e-7));
    await tester.pump(const Duration(milliseconds: 75));
    expect(opacity(tester), 1);
  });

  testWidgets(
    'rapid scale toggles and ranges during fade settle on latest data',
    (tester) async {
      await showChart(tester);
      await showChart(tester, logScale: true);
      await tester.pump(const Duration(milliseconds: 75));
      final before = opacity(tester);
      expect(before, closeTo(.5, 1e-7));
      await showChart(tester, data: fine, range: 'day', series: 15);
      expect(opacity(tester), before);
      await tester.pumpAndSettle();
      expect(opacity(tester), 1);
      expect(frame(tester).lineBarsData.single.spots.first.y, 98);
      expect(times(frame(tester)), [1500, 1800, 2200, 2600, 3000]);
    },
  );

  testWidgets('reduced motion settles zooms and scale changes immediately', (
    tester,
  ) async {
    await showChart(tester);
    await showChart(tester, data: fine, range: 'day', series: 15);
    await tester.pump(const Duration(milliseconds: 150));
    await showChart(
      tester,
      data: fine,
      range: 'day',
      series: 15,
      reducedMotion: true,
    );
    expect(frame(tester).minX, 1500);
    expect(times(frame(tester)), [1500, 1800, 2200, 2600, 3000]);
    await showChart(tester, logScale: true, reducedMotion: true);
    expect(opacity(tester), 1);
    expect(
      frame(tester).lineBarsData.single.spots[1].y,
      closeTo(math.log(120) / math.ln10, 1e-7),
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
    'scrubbing selects real target samples and is suppressed in motion',
    (tester) async {
      final selections = <PricePoint?>[];
      await showChart(
        tester,
        data: fine,
        range: 'day',
        series: 15,
        onHover: selections.add,
      );
      final position =
          tester.getTopLeft(find.byType(AreaChart)) + const Offset(120, 100);
      var gesture = await tester.startGesture(position);
      await tester.pump();
      expect(selections.last, fine[1]);
      await gesture.up();
      await showChart(tester, onHover: selections.add);
      gesture = await tester.startGesture(position);
      await tester.pump();
      expect(selections.last, isNull);
      expect(frame(tester).lineBarsData.single.showingIndicators, isEmpty);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 450));
      gesture = await tester.startGesture(position);
      await tester.pump();
      expect(
        selections.last,
        daily[1],
      ); // No held intraday sample can be selected.
      await gesture.moveBy(const Offset(260, 0));
      await tester.pump();
      expect(selections.last, daily.last);
      await gesture.up();
    },
  );
}
