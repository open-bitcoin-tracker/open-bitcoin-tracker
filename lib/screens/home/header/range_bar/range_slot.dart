import 'package:flutter/widgets.dart';

import '../../../../data/app_enums.dart';
import '../../../../state/app_state_notifier.dart';
import 'range_labels.dart';

/// One configurable slot, shared by tap, swipe, and picker interactions.
enum RangeSlot {
  days,
  weeks,
  months,
  years;

  List<BtcRange> get ranges => switch (this) {
    days => btcRangeDays,
    weeks => btcRangeWeeks,
    months => btcRangeMonths,
    years => btcRangeYears,
  };
  String get keyPrefix => switch (this) {
    days => 'daysOverflowSlot',
    weeks => 'weeksOverflowSlot',
    months => 'monthsOverflowSlot',
    years => 'overflowSlot',
  };
  BtcRange current(AppStateNotifier app) => switch (this) {
    days => app.daysOverflowQuickRange,
    weeks => app.weeksOverflowQuickRange,
    months => app.monthsOverflowQuickRange,
    years => app.overflowQuickRange,
  };
  void update(AppStateNotifier app, BtcRange range) => switch (this) {
    days => app.setDaysOverflowQuickRange(range),
    weeks => app.setWeeksOverflowQuickRange(range),
    months => app.setMonthsOverflowQuickRange(range),
    years => app.setOverflowQuickRange(range),
  };
  String longLabel(BuildContext context, BtcRange range) => switch (this) {
    days => btcRangeDaysLongLabel(context, range),
    weeks => btcRangeWeeksLongLabel(context, range),
    months => btcRangeMonthsLongLabel(context, range),
    years => btcRangeLongLabel(context, range),
  };
  BtcRange cycle(BtcRange current, int step) {
    final options = ranges;
    final index = options.indexOf(current);
    return options[((index < 0 ? 0 : index) + step) % options.length];
  }
}
