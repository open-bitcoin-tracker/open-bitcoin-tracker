import 'package:flutter/material.dart';
import '../../../../data/app_enums.dart';
import '../../../../l10n/generated/app_localizations.dart';

// Memo for maxRangeLabelWidth: RangeBar rebuilds at price-tick cadence and lays
// out ~38 painters per build, but the widths only change with the label set
// (locale), style, text scale, or direction. LRU-capped so locale/theme
// switches can't grow it unboundedly.
final Map<(String, TextStyle, TextScaler, TextDirection), double>
_labelWidthCache = {};
const int _labelWidthCacheCap = 32;

// Measures the widest label among `labels` rendered with `style` and the
// supplied `TextScaler`. Used to reserve a stable width on the overflow chip
// so cycling through 1Y..15Y doesn't shift neighboring chips.
double maxRangeLabelWidth({
  required BuildContext context,
  required List<String> labels,
  required TextStyle style,
  required TextScaler textScaler,
}) {
  final textDirection = Directionality.of(context);
  final key = (labels.join('\u0000'), style, textScaler, textDirection);
  final cached = _labelWidthCache.remove(key);
  if (cached != null) {
    _labelWidthCache[key] = cached; // refresh LRU position
    return cached;
  }
  double maxWidth = 0;
  for (final label in labels) {
    final tp = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    if (tp.size.width > maxWidth) maxWidth = tp.size.width;
    tp.dispose();
  }
  if (_labelWidthCache.length >= _labelWidthCacheCap) {
    _labelWidthCache.remove(_labelWidthCache.keys.first);
  }
  _labelWidthCache[key] = maxWidth;
  return maxWidth;
}

String btcRangeLabel(BuildContext context, BtcRange r) {
  final l10n = AppLocalizations.of(context);
  return switch (r) {
    BtcRange.d1 => l10n.rangePill1D,
    BtcRange.d2 => l10n.rangePill2D,
    BtcRange.d3 => l10n.rangePill3D,
    BtcRange.d4 => l10n.rangePill4D,
    BtcRange.d5 => l10n.rangePill5D,
    BtcRange.d6 => l10n.rangePill6D,
    BtcRange.d7 => l10n.rangePill7D,
    BtcRange.w1 => l10n.rangePill1W,
    BtcRange.w2 => l10n.rangePill2W,
    BtcRange.w3 => l10n.rangePill3W,
    BtcRange.w4 => l10n.rangePill4W,
    BtcRange.m1 => l10n.rangePill1M,
    BtcRange.m2 => l10n.rangePill2M,
    BtcRange.m3 => l10n.rangePill3M,
    BtcRange.m4 => l10n.rangePill4M,
    BtcRange.m5 => l10n.rangePill5M,
    BtcRange.m6 => l10n.rangePill6M,
    BtcRange.m7 => l10n.rangePill7M,
    BtcRange.m8 => l10n.rangePill8M,
    BtcRange.m9 => l10n.rangePill9M,
    BtcRange.m10 => l10n.rangePill10M,
    BtcRange.m11 => l10n.rangePill11M,
    BtcRange.m12 => l10n.rangePill12M,
    BtcRange.y1 => l10n.rangePill1Y,
    BtcRange.y2 => l10n.rangePill2Y,
    BtcRange.y3 => l10n.rangePill3Y,
    BtcRange.y4 => l10n.rangePill4Y,
    BtcRange.y5 => l10n.rangePill5Y,
    BtcRange.y6 => l10n.rangePill6Y,
    BtcRange.y7 => l10n.rangePill7Y,
    BtcRange.y8 => l10n.rangePill8Y,
    BtcRange.y9 => l10n.rangePill9Y,
    BtcRange.y10 => l10n.rangePill10Y,
    BtcRange.y11 => l10n.rangePill11Y,
    BtcRange.y12 => l10n.rangePill12Y,
    BtcRange.y13 => l10n.rangePill13Y,
    BtcRange.y14 => l10n.rangePill14Y,
    BtcRange.y15 => l10n.rangePill15Y,
    BtcRange.all => l10n.rangePillAll,
  };
}

// Long-form label for the days overflow picker: "1 Day", "3 Days", etc.
String btcRangeDaysLongLabel(BuildContext context, BtcRange r) {
  final d = r.days;
  if (d == null) return btcRangeLabel(context, r);
  return AppLocalizations.of(context).rangePickerDaysFull(d);
}

// Long-form label for the weeks overflow picker: "1 Week", "2 Weeks", etc.
String btcRangeWeeksLongLabel(BuildContext context, BtcRange r) {
  final w = r.weeks;
  if (w == null) return btcRangeLabel(context, r);
  return AppLocalizations.of(context).rangePickerWeeksFull(w);
}

// Long-form label for the months overflow picker: "1 Month", "6 Months", etc.
// Falls back to the short label for non-month ranges (safety belt; the picker
// only ever supplies month-shaped values).
String btcRangeMonthsLongLabel(BuildContext context, BtcRange r) {
  final months = r.months;
  if (months == null) return btcRangeLabel(context, r);
  return AppLocalizations.of(context).rangePickerMonthsFull(months);
}

// Long-form label for the overflow-slot picker: "1 Year", "5 Years", etc.
// Falls back to the short label for non-year ranges.
String btcRangeLongLabel(BuildContext context, BtcRange r) {
  final years = r.years;
  if (years == null) return btcRangeLabel(context, r);
  return AppLocalizations.of(context).rangePickerYearsFull(years);
}
