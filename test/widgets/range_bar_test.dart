import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_bitcoin_tracker/data/data.dart';
import 'package:open_bitcoin_tracker/screens/home/header/range_bar.dart';
import 'package:open_bitcoin_tracker/state/state.dart';
import 'package:provider/provider.dart';

import '../support/app_test_host.dart';
import '../support/test_viewport.dart';

Future<AppStateNotifier> _pumpBar(
  WidgetTester tester, {
  bool dismissHint = true,
}) async {
  setTestViewport(tester, const Size(400, 850));
  await tester.pumpWidget(
    await appTestHost(
      Builder(
        builder: (context) {
          final range = context.select<AppStateNotifier, BtcRange>(
            (app) => app.btcRange,
          );
          return Scaffold(
            body: Center(
              child: RangeBar(
                range: range,
                chartColor: Colors.orange,
                onRange: context.read<AppStateNotifier>().setBtcRange,
              ),
            ),
          );
        },
      ),
      initialState: '{"btcRange":"1D","swipeChipHintDismissed":$dismissHint}',
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return tester.element(find.byType(RangeBar)).read<AppStateNotifier>();
}

void main() {
  testWidgets(
    'range taps, vertical cycling, and picker selection keep working',
    (tester) async {
      final app = await _pumpBar(tester);
      await tester.drag(find.text('1D'), const Offset(0, -30));
      await tester.pump(const Duration(milliseconds: 300));
      expect(app.btcRange, BtcRange.d2);
      expect(app.daysOverflowQuickRange, BtcRange.d2);
      await tester.tap(find.text('All'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(app.btcRange, BtcRange.all);
      await tester.longPress(find.text('2D'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('daysOverflowSlot-d5')));
      await tester.pumpAndSettle();
      expect(app.btcRange, BtcRange.d5);
      expect(app.daysOverflowQuickRange, BtcRange.d5);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('idle hint motion leaves the range coordinator untouched', (
    tester,
  ) async {
    await _pumpBar(tester, dismissHint: false);
    var barBuilds = 0;
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previous?.call(element, builtOnce);
      if (element.widget is RangeBar) barBuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(barBuilds, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
