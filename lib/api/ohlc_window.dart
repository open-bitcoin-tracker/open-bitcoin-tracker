import '../data/app_enums.dart';

/// The shared candle policy for fetching, slicing, and freshness checks.
class OhlcWindow {
  const OhlcWindow(this.intervalMinutes, {this.takeLast});

  final int intervalMinutes;
  final int? takeLast;
  Duration get candleInterval => Duration(minutes: intervalMinutes);

  static OhlcWindow? forRange(BtcRange range) {
    final days = range.days;
    if (days != null) return OhlcWindow(15, takeLast: days * 96);
    final weeks = range.weeks;
    if (weeks != null) return OhlcWindow(60, takeLast: weeks * 168);
    if (range == BtcRange.m1) return const OhlcWindow(60);
    return null;
  }
}
