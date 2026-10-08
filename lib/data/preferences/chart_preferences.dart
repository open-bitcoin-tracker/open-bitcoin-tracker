import 'package:flutter/foundation.dart';
import '../app_enums.dart';

@immutable
class ChartPreferences {
  const ChartPreferences({
    this.showChart = true,
    this.chartHeight = ChartHeight.xxxl,
    this.btcRange = BtcRange.all,
    this.daysOverflowQuickRange = BtcRange.d1,
    this.weeksOverflowQuickRange = BtcRange.w1,
    this.overflowQuickRange = BtcRange.y10,
    this.monthsOverflowQuickRange = BtcRange.m6,
    this.logScale = true,
    this.livePriceCadence = LivePriceCadence.live,
    this.swipeChipHintDismissed = false,
    this.priceSwipeHintDismissed = false,
    this.showPriceDelta = false,
  });
  final bool showChart;
  final ChartHeight chartHeight;
  final BtcRange btcRange;
  final BtcRange daysOverflowQuickRange;
  final BtcRange weeksOverflowQuickRange;
  final BtcRange overflowQuickRange;
  final BtcRange monthsOverflowQuickRange;
  final bool logScale;
  final LivePriceCadence livePriceCadence;
  final bool swipeChipHintDismissed;
  final bool priceSwipeHintDismissed;
  final bool showPriceDelta;
  ChartPreferences copyWith({
    bool? showChart,
    ChartHeight? chartHeight,
    BtcRange? btcRange,
    BtcRange? daysOverflowQuickRange,
    BtcRange? weeksOverflowQuickRange,
    BtcRange? overflowQuickRange,
    BtcRange? monthsOverflowQuickRange,
    bool? logScale,
    LivePriceCadence? livePriceCadence,
    bool? swipeChipHintDismissed,
    bool? priceSwipeHintDismissed,
    bool? showPriceDelta,
  }) => ChartPreferences(
    showChart: showChart ?? this.showChart,
    chartHeight: chartHeight ?? this.chartHeight,
    btcRange: btcRange ?? this.btcRange,
    daysOverflowQuickRange:
        daysOverflowQuickRange ?? this.daysOverflowQuickRange,
    weeksOverflowQuickRange:
        weeksOverflowQuickRange ?? this.weeksOverflowQuickRange,
    overflowQuickRange: overflowQuickRange ?? this.overflowQuickRange,
    monthsOverflowQuickRange:
        monthsOverflowQuickRange ?? this.monthsOverflowQuickRange,
    logScale: logScale ?? this.logScale,
    livePriceCadence: livePriceCadence ?? this.livePriceCadence,
    swipeChipHintDismissed:
        swipeChipHintDismissed ?? this.swipeChipHintDismissed,
    priceSwipeHintDismissed:
        priceSwipeHintDismissed ?? this.priceSwipeHintDismissed,
    showPriceDelta: showPriceDelta ?? this.showPriceDelta,
  );
}
