import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_bitcoin_tracker/widgets/rolling_number.dart';

const _style = TextStyle(fontSize: 40);

Widget _number(String text, {int direction = 1}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: RollingNumber(text: text, style: _style, direction: direction),
  ),
);

Finder _digit(int place) => find.byKey(ValueKey('digit-$place'));

// Vertical offset of a digit's strip; it changes only while the digit rolls.
double _stripOffset(WidgetTester tester, int place) => tester
    .widget<Transform>(
      find.descendant(of: _digit(place), matching: find.byType(Transform)),
    )
    .transform
    .getTranslation()
    .y;

// Where the strip shows on the 0–9 tape, in digit steps: the first digit the
// strip is built from plus how far it has been moved. Unlike the raw offset,
// this stays continuous when a new roll rebuilds the strip.
double _tapePosition(WidgetTester tester, int place) {
  final metrics = DigitCellMetrics.of(_style, TextScaler.noScaling);
  final capHeight = _style.fontSize! * 0.52;
  final shiftY = metrics.height / 2 - (metrics.baseline - capHeight / 2);
  final first = tester
      .widget<Text>(
        find.descendant(of: _digit(place), matching: find.byType(Text)).first,
      )
      .data!;
  return int.parse(first) +
      (shiftY - _stripOffset(tester, place)) / metrics.height;
}

void main() {
  testWidgets('digits keep their place from the right when the price gains a '
      'digit', (tester) async {
    await tester.pumpWidget(_number(r'$99,991'));
    final units = tester.state(_digit(0));
    final tens = tester.state(_digit(1));
    final restingTens = _stripOffset(tester, 1);

    await tester.pumpWidget(_number(r'$100,001'));
    expect(tester.state(_digit(0)), same(units));
    expect(tester.state(_digit(1)), same(tens));
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      _stripOffset(tester, 1),
      isNot(restingTens),
      reason: 'the tens 9 rolls on to 0',
    );
    expect(_digit(5), findsOneWidget, reason: 'the new leading 1 appears');

    await tester.pumpAndSettle();
    expect(_stripOffset(tester, 1), restingTens);
    for (final digit in ['1', '0']) {
      expect(find.text(digit), findsWidgets);
    }
  });

  testWidgets('a tick landing mid-roll continues from where the strip is', (
    tester,
  ) async {
    await tester.pumpWidget(_number(r'$62,711'));
    await tester.pumpWidget(_number(r'$62,719'));
    await tester.pump(const Duration(milliseconds: 150));
    final midRoll = _tapePosition(tester, 0);
    expect(midRoll, inExclusiveRange(1, 9), reason: 'rolling up from 1 to 9');

    await tester.pumpWidget(_number(r'$62,712'));
    await tester.pump();
    expect(
      _tapePosition(tester, 0),
      closeTo(midRoll, 0.2),
      reason: 'no jump back to the previous target before rolling on',
    );

    await tester.pumpAndSettle();
    expect(
      find.descendant(of: _digit(0), matching: find.text('2')),
      findsOneWidget,
    );
  });

  testWidgets('rolls follow the price direction and settle on one digit', (
    tester,
  ) async {
    await tester.pumpWidget(_number(r'$62,712'));
    await tester.pumpWidget(_number(r'$62,711', direction: -1));
    await tester.pump(const Duration(milliseconds: 100));
    // Down from 2 to 1 crosses only those two digits.
    expect(
      find.descendant(of: _digit(0), matching: find.byType(Text)),
      findsNWidgets(2),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: _digit(0), matching: find.byType(Text)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _digit(0), matching: find.text('1')),
      findsOneWidget,
    );
  });
}
